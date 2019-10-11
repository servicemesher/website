---
title: "linkerd2 proxy destination 原理分析"
date: 2019-10-10T16:58:27+08:00
draft: false
banner: "/img/blog/banners/00704eQkgy1fqer344dfggj49494elds.jpg"
author: "李岩"
authorlink: ""
summary: "在本文章中，能粗略了解到 linker2 的代理服务 proxy 组件 destination 的原理"
tags: ["linkerd"]
categories: ["linkerd"]
keywords: ["service mesh","服务网格","sofamesh","x-protocol"]
---

作者: 李岩，哗啦啦 mesh团队 架构师，热衷于kubernetes、devops、apollo、istio、linkerd、openstack、calico 等领域技术。

## 概述 
proxy由rust开发完成，其内部的异步运行时采用了[Tokio](https://tokio-zh.github.io/)框架，服务组件用到了[tower](https://github.com/tower-rs/tower)。

## 流程分析

### 初始化

1. app::init初始化配置
2. app::Main::new创建主逻辑main
3. main.run_until内新加一任务 ProxyParts::build_proxy_task

在ProxyParts::build_proxy_task中会进行一系列的初始化工作，此处只关注dst_svc，其创建代码为：

```
            svc::builder()
               .buffer_pending(
                    config.destination_buffer_capacity,
                    config.control_dispatch_timeout,
               )
               .layer(control::add_origin::layer())
               .layer(proxy::grpc::req_body_as_payload::layer().per_make())
               .layer(http_metrics::layer::<_, classify::Response>(
                    ctl_http_metrics.clone(),
               ))
               .layer(reconnect::layer().with_backoff(config.control_backoff.clone()))
               .layer(control::resolve::layer(dns_resolver.clone()))
               .layer(control::client::layer())
               .timeout(config.control_connect_timeout)
               .layer(keepalive::connect::layer(keepalive))
               .layer(tls::client::layer(local_identity.clone()))
               .service(connect::svc())
               .make(config.destination_addr.clone())
```

dst_svc一共有2处引用，一是crate::resolve::Resolver的创建会涉及，先不管它；另一个就是ProfilesClient的创建。

在ProfilesClient::new中：
1. 调用api::client::Destination::new(dst_svc)创建grpc的client端并存于成员变量service
2. 接着profiles_client对象会被用于inbound和outbound的创建（省略无关代码）：

```
    let dst_stack = svc::builder()
       .layer(profiles::router::layer(
            profile_suffixes,
            profiles_client,
            dst_route_stack,
       ))
       .service(...)
```

其中profiles::router::layer会创建一个Layer对象，并将profiles_client赋予get_routes成员。然后在service方法中，会调到Layer::layer方法，里面会创建一个MakeSvc对象，其get_routes成员的值即为profiles_client。

### 运行
新的连接过来时，会调用linkerd2_proxy::proxy::server::Server的serve_connection方法，并最终调用MakeSvc::call方法。

在call中：

```
        // Initiate a stream to get route and dst_override updates for this
        // destination.
        let route_stream = match target.get_destination() {
            Some(ref dst) => {
                if self.suffixes.iter().any(|s| s.contains(dst.name())) {
                    debug!("fetching routes for {:?}", dst);
                    self.get_routes.get_routes(&dst)
               } else {
                    debug!("skipping route discovery for dst={:?}", dst);
                    None
               }
           }
            None => {
                debug!("no destination for routes");
                None
           }
       };
```

经过若干判断后，会调用ProfilesClient::get_routes并将结果存于route_stream。

进入get_routes：

```
    fn get_routes(&self, dst: &NameAddr) -> Option<Self::Stream> {
        // 创建通道
        let (tx, rx) = mpsc::channel(1);
        // This oneshot allows the daemon to be notified when the Self::Stream
        // is dropped.
        let (hangup_tx, hangup_rx) = oneshot::channel();
        // 创建Daemon对象（Future任务）
        let daemon = Daemon {
            tx,
            hangup: hangup_rx,
            dst: format!("{}", dst),
            state: State::Disconnected,
            service: self.service.clone(),
            backoff: self.backoff,
            context_token: self.context_token.clone(),
       };
        // 调用Daemon::poll
        let spawn = DefaultExecutor::current().spawn(Box::new(daemon.map_err(|_| ())));
        // 将通道接收端传出
        spawn.ok().map(|_| Rx {
            rx,
            _hangup: hangup_tx,
       })
   }
```

接着看poll：

```
    fn poll(&mut self) -> Poll<Self::Item, Self::Error> {
        loop {
            // 遍历state成员状态
            self.state = match self.state {
                // 未连接时
                State::Disconnected => {
                    match self.service.poll_ready() {
                        Ok(Async::NotReady) => return Ok(Async::NotReady),
                        Ok(Async::Ready(())) => {}
                        Err(err) => {
                            error!(
                                "profile service unexpected error (dst = {}): {:?}",
                                self.dst, err,
                           );
                            return Ok(Async::Ready(()));
                       }
                   };
                    // 构造grpc请求
                    let req = api::GetDestination {
                        scheme: "k8s".to_owned(),
                        path: self.dst.clone(),
                        context_token: self.context_token.clone(),
                   };
                    debug!("getting profile: {:?}", req);
                    // 获取请求任务
                    let rspf = self.service.get_profile(grpc::Request::new(req));
                    State::Waiting(rspf)
               }
                // 正在请求时，从请求中获取回复
                State::Waiting(ref mut f) => match f.poll() {
                    Ok(Async::NotReady) => return Ok(Async::NotReady),
                    // 正常回复
                    Ok(Async::Ready(rsp)) => {
                        trace!("response received");
                        // 流式回复
                        State::Streaming(rsp.into_inner())
                   }
                    Err(e) => {
                        warn!("error fetching profile for {}: {:?}", self.dst, e);
                        State::Backoff(Delay::new(clock::now() + self.backoff))
                   }
               },
                // 接收回复
                State::Streaming(ref mut s) => {
                    // 处理回复流
                    // 注意此处，参数1是get_profile请求的回复流，
                    //   参数2是之前创建的通道发送端
                    match Self::proxy_stream(s, &mut self.tx, &mut self.hangup) {
                        Async::NotReady => return Ok(Async::NotReady),
                        Async::Ready(StreamState::SendLost) => return Ok(().into()),
                        Async::Ready(StreamState::RecvDone) => {
                            State::Backoff(Delay::new(clock::now() + self.backoff))
                       }
                   }
               }
                // 异常，结束请求
                State::Backoff(ref mut f) => match f.poll() {
                    Ok(Async::NotReady) => return Ok(Async::NotReady),
                    Err(_) | Ok(Async::Ready(())) => State::Disconnected,
               },
           };
       }
   }               
                                   
```

接着 proxy_stream：

```
    fn proxy_stream(
        rx: &mut grpc::Streaming<api::DestinationProfile, T::ResponseBody>,
        tx: &mut mpsc::Sender<profiles::Routes>,
        hangup: &mut oneshot::Receiver<Never>,
   ) -> Async<StreamState> {
        loop {
            // 发送端是否就绪
            match tx.poll_ready() {
                Ok(Async::NotReady) => return Async::NotReady,
                Ok(Async::Ready(())) => {}
                Err(_) => return StreamState::SendLost.into(),
           }
 
            // 从grpc stream中取得一条数据
            match rx.poll() {
                Ok(Async::NotReady) => match hangup.poll() {
                    Ok(Async::Ready(never)) => match never {}, // unreachable!
                    Ok(Async::NotReady) => {
                        // We are now scheduled to be notified if the hangup tx
                        // is dropped.
                        return Async::NotReady;
                   }
                    Err(_) => {
                        // Hangup tx has been dropped.
                        debug!("profile stream cancelled");
                        return StreamState::SendLost.into();
                   }
               },
                 Ok(Async::Ready(None)) => return StreamState::RecvDone.into(),
                // 正确取得profile结构
                Ok(Async::Ready(Some(profile))) => {
                    debug!("profile received: {:?}", profile);
                    // 解析数据
                    let retry_budget = profile.retry_budget.and_then(convert_retry_budget);
                    let routes = profile
                       .routes
                       .into_iter()
                       .filter_map(move |orig| convert_route(orig, retry_budget.as_ref()))
                       .collect();
                    let dst_overrides = profile
                       .dst_overrides
                       .into_iter()
                       .filter_map(convert_dst_override)
                       .collect();
                    // 构造profiles::Routes结构并推到发送端
                    match tx.start_send(profiles::Routes {
                        routes,
                        dst_overrides,
                   }) {
                        Ok(AsyncSink::Ready) => {} // continue
                        Ok(AsyncSink::NotReady(_)) => {
                            info!("dropping profile update due to a full buffer");
                            // This must have been because another task stole
                            // our tx slot? It seems pretty unlikely, but possible?
                            return Async::NotReady;
                       }
                        Err(_) => {
                            return StreamState::SendLost.into();
                       }
                   }
               }
                Err(e) => {
                    warn!("profile stream failed: {:?}", e);
                    return StreamState::RecvDone.into();
               }
           }
       }
   }
```

回到MakeSvc::call方法，前面创建的route_stream会被用于创建一个linkerd2_proxy::proxy::http::profiles::router::Service任务对象，并在其poll_ready方法中通过poll_route_stream从route_steam获取profiles::Routes并调用update_routes创建具体可用的路由规则linkerd2_router::Router，然后在call中调用`linkerd2_router::call进行对请求的路由判断。
