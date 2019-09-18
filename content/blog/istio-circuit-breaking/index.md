---
originallink: "https://banzaicloud.com/blog/istio-circuit-breaking/"
author: "Laszlo Bence Nagy"
date: "2019-09-20T18:00:00+08:00"
draft: false
banner: "/img/blog/banners/006tKfTcgy1ftnl1osmwjj30rs0kub1t.jpg"
translator: "马若飞"
translatorlink: "https://github.com/malphi"
reviewer:  [""]
reviewerlink:  [""]
title: "Istio熔断器"
description: "本文演示了如何在AWS控制台创建一个App Mesh"
categories: ["istio"]
tags: ["istio"]
---

## 编者按



## 前言

Istio has been rightfully praised for ushering in `free` *observability* and *secure service to service communication*. Other, more significant features, however, are what truly make Istio the Swiss army knife of service mesh operators; when it comes to meeting SLOs like uptime, latency and error rates, the ability to **manage traffic** between services is absolutely critical.

Istio因引入了免费的可观察性和安全的服务到服务通信而受到了应有的赞扬。然而，其他更重要的功能是真正使Istio成为瑞士军刀服务网格运营商;当遇到正常运行时间、延迟和错误率等SLOs时，管理服务之间通信的能力是绝对关键的。

When we released the [Istio operator](https://github.com/banzaicloud/istio-operator) earlier this year, our goal (besides managing Istio installation and upgrades) was to provide support for these excellent traffic routing features, while making everything more usable and UX friendly. We ended up creating a simple and automated service mesh, [Backyards](https://banzaicloud.com/blog/istio-the-easy-way/), which features a management UI, [CLI](https://github.com/banzaicloud/backyards-cli) and GraphQL API on top of our [Istio operator](https://github.com/banzaicloud/istio-operator). [Backyards](https://banzaicloud.com/blog/istio-the-easy-way/) is integrated into Banzai Cloud’s container management platform, [Pipeline](https://github.com/banzaicloud/pipeline), however, it also works, and is available, as a standalone product. Naturally, using Backyards with [Pipeline](https://github.com/banzaicloud/pipeline) provides users with a variety of specific benefits (like managing applications in a [multi-cloud and hybrid cloud world](https://banzaicloud.com/blog/istio-multicluster-the-easy-way/)) but Backyards works on any Kubernetes installation.

当我们在今年早些时候发布Istio操作符时，我们的目标(除了管理Istio的安装和升级)是为这些出色的流量路由特性提供支持，同时使所有东西都更加可用和用户体验友好。最后，我们创建了一个简单而自动化的服务网格backyard，它在Istio操作符之上提供了一个管理UI、CLI和GraphQL API。后院集成到板载云的容器管理平台Pipeline中，但是，它也可以工作，并且可以作为一个独立的产品使用。当然，将backyard与Pipeline一起使用为用户提供了各种特定的好处(比如在多云和混合云环境中管理应用程序)，但是backyard可以用于任何Kubernetes安装。

> Some of the related Backyards features we have already blogged about:
>
> - [Automatic canary deployments with Backyards](https://banzaicloud.com/blog/istio-canary/)
> - [Traffic shifting](https://banzaicloud.com/blog/istio-traffic-shifting/)



## Circuit breaking: failure is an option

In microservices architecture, services are written in different languages, deployed across multiple nodes or clusters and have different response times or failure rates. Usually, if a service responds to requests successfully (and in a timely manner), it has performed satisfactorily. However, this is often not the case, and downstream clients need to be protected from excessive slowness of upstream services. Upstream services, in turn, must be protected from being overloaded by a backlog of requests. This becomes more complicated with multiple clients, and can lead to a cascading series of failures throughout the whole infrastructure. The solution to this problem is the time-tested circuit breaker pattern.

在微服务体系结构中，服务用不同的语言编写，部署在多个节点或集群上，并且具有不同的响应时间或故障率。通常，如果服务成功地(并且及时地)响应了请求，那么它的性能就令人满意。然而，通常情况并非如此，下游客户端需要受到保护，以避免上游服务过于缓慢。反过来，上游服务必须受到保护，以免被积压的请求过载。对于多个客户机，这将变得更加复杂，并可能导致整个基础设施出现一系列级联故障。解决这一问题的方法是采用经过时间检验的断路器型式。

A circuit breaker can have three states: `closed`, `open` and `half open`, and by default exists in a `closed` state. In the `closed` state, requests succeed or fail until the number of failures reach a predetermined threshold, with no interference from the breaker. When the threshold is reached, the circuit breaker *opens*. When calling a service in an `open`state, the circuit breaker *trips* the requests, which means that it returns an error without attempting to execute the call. In this way, by tripping the request downstream at the client, cascading failures can be prevented in a production system. After a configurable timeout, the circuit breaker enters a `half open` state, in which the failing service is given time to recover from its broken behavior. If requests continue to fail in this state, then the circuit breaker is opened again and keeps tripping requests. Otherwise, if the requests succeed in the `half open` state, then the circuit breaker will *close* and the service will be allowed to handle requests again.

断路器可以有三种状态:关闭、打开和半打开，默认情况下处于关闭状态。在关闭状态下，请求成功或失败，直到故障数量达到预先确定的阈值，而不会受到断路器的干扰。当达到阈值时，断路器就会打开。当调用处于打开状态的服务时，断路器断开请求，这意味着它返回一个错误，而不尝试执行调用。通过这种方式，通过在客户机上断开下游的请求，可以在生产系统中防止级联故障。经过可配置的超时后，断路器进入半打开状态，在这种状态下，故障服务有时间从其中断行为中恢复。如果请求在这种状态下继续失败，则断路器将再次打开并继续跳闸请求。否则，如果请求在半打开状态下成功，则断路器将关闭，服务将被允许再次处理请求。

![Circuit Breaking](https://banzaicloud.com/img/blog/istio/circuit-breaking.png)

## Circuit breaking in [Istio](https://istio.io/)

Istio’s [circuit breaking](https://istio.io/docs/tasks/traffic-management/circuit-breaking/) can be configured in the [TrafficPolicy](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#TrafficPolicy) field within the `Destination Rule` Istio [Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). There are two fields under `TrafficPolicy` which are relevant to circuit breaking: [ConnectionPoolSettings](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#ConnectionPoolSettings) and [OutlierDetection](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#OutlierDetection).

In `ConnectionPoolSettings`, the volume of connections can be configured for a service. `OutlierDetection` is for controlling the eviction of unhealthy services from the load balancing pool.

I.e. `ConnectionPoolSettings` controls the maximum number of requests, pending requests, retries or timeouts, while `OutlierDetection` controls the number of errors before a service is ejected from the connection pool, and is where minimum ejection duration and maximum ejection percentage can be set. For a full list of fields, check the [documentation](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#TrafficPolicy).

> Istio utilizes the [circuit breaking feature of Envoy](https://www.envoyproxy.io/learn/circuit-breaking) in the background.

Let’s take a look at a `Destination Rule` with circuit breaking configured:

```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: notifications
spec:
  host: notifications
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutiveErrors: 1
      interval: 1s
      baseEjectionTime: 3m
      maxEjectionPercent: 100
```

With these settings in the `ConnectionPoolSettings` field, only one connection can be made to the `notifications` service within a given time frame: one pending request with a maximum of one request per connection. If a threshold is reached, the circuit breaker will start tripping requests.

The `OutlierDetection` section is set so that it checks whether there is an error calling the service every second. If there is, the service is ejected from the load balancing pool for at least three minutes (the 100% maximum ejection percent indicates that all services can be ejected from the pool at the same time, if necessary).

使用ConnectionPoolSettings字段中的这些设置，在给定的时间范围内只能向通知服务进行一个连接:一个挂起的请求，每个连接最多只能有一个请求。如果达到阈值，断路器将开始跳闸请求。

设置了OutlierDetection部分，以便检查是否存在每秒钟调用服务的错误。如果有，则将服务从负载平衡池中弹出至少三分钟(100%最大弹出百分比表示，如果需要，所有服务都可以同时从池中弹出)。

> There’s one thing which you need to pay special attention to when manually creating the `Destination Rule` resource, which is whether or not you have mutual TLS enabled for this service. If you do, you’ll also need to set the field below inside your `Destination Rule`, otherwise your caller services will probably receive 503 responses when calling the `movies` service:
>
> 在手动创建目标规则资源时，有一件事需要特别注意，那就是是否为该服务启用了互TLS。如果这样做，还需要在目标规则中设置下面的字段，否则调用方服务时可能会收到503个响应
>
> ```
> trafficPolicy:
>   tls:
>     mode: ISTIO_MUTUAL
> ```
>
> Mutual TLS can be enabled [globally](https://istio.io/docs/tasks/security/authn-policy/#globally-enabling-istio-mutual-tls) for a specific [namespace](https://istio.io/docs/tasks/security/authn-policy/#namespace-wide-policy) or for a specific [service](https://istio.io/docs/tasks/security/authn-policy/#service-specific-policy), as well. You should be aware of these settings in order to determine whether you should set `trafficPolicy.tls.mode` to `ISTIO_MUTUAL` or not. More importantly, it is very easy to forget to set this field when you are trying to configure a completely different feature (e.g. circuit breaking).
>
> 还可以为特定名称空间或特定服务全局启用互TLS。您应该了解这些设置，以便确定是否应该设置trafficPolicy.tls。模式到ISTIO_MUTUAL或not。更重要的是，当您试图配置一个完全不同的特性(例如断路)时，很容易忘记设置此字段。
>
> Tip: Always think about mutual TLS before creating a `Destination Rule`!

To trigger circuit breaker tripping, let’s call the `notifications` service from two connections simultaneously. Remember, the `maxConnections` field is set to one. When we do, we should see 503 responses arriving alongside 200s.

When a service receives a greater load from a client than it is believed to be able to handle (as configured in the circuit breaker), it starts returning 503 errors before attempting to make a call. This is a way of preventing an error cascade.

为了触发断路器跳闸，让我们同时从两个连接调用通知服务。记住，maxConnections字段被设置为1。当我们这样做时，应该会看到503个响应与200个响应同时到达。

当一个服务从客户端接收到的负载大于它所能处理的负载(如断路器中配置的那样)时，它在尝试调用之前开始返回503个错误。这是防止错误级联的一种方法。

### MONITORING CIRCUIT BREAKERS

It is an absolute must that you monitor your services in a production environment, and that you are notified and be able to investigate when errors occur in the system. It stands to reason, then, that if you’ve configured a circuit breaker for your service, you’ll want to know when that breaker is tripped; what percentage of your requests were tripped by the circuit breaker; how many requests were tripped and when, and from which downstream client? If you can answer these questions, you can determine how well your circuit breaker is working, fine tune the circuit breaker configurations as needed, or optimize your service to handle additional concurrent requests.

您必须在生产环境中监视您的服务，并且得到通知，并且能够在系统中发生错误时进行调查。因此，如果您已经为您的服务配置了一个断路器，您就会想知道断路器什么时候跳闸;您的请求中有多少百分比被断路器触发;有多少请求被触发，何时触发，来自哪个下游客户端?如果您能够回答这些问题，您就可以确定您的断路器工作得有多好，根据需要微调断路器配置，或者优化您的服务来处理额外的并发请求。

> Pro tip: you can see and configure all these (and more) on the Backyards UI if you keep reading.

Let’s see how to determine the trips caused by the circuit breaker in Istio:

The response code in the event of a circuit breaker trip is **503**, so you won’t be able to differentiate it from other 503 errors based merely on that response. In Envoy, there is a counter called `upstream_rq_pending_overflow`, which is the *total number of requests that overflowed the connection pool circuit breaker and were failed*. If you dig into Envoy’s statistics for your service, you can acquire this information, but it’s not particularly easy to reach.

断路器跳闸时的响应代码是503，因此您无法仅根据该响应将其与其他503错误区分开来。在Envoy中，有一个计数器upstream_rq_pending_overflow，它是溢出连接池断路器并失败的请求总数。如果您为您的服务深入研究Envoy的统计数据，您可以获得这些信息，但是要获得这些信息并不容易。

Envoy also returns [response flags](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log#config-access-log-format-response-flags) in addition to response codes, and there exists a dedicated response flag to indicate circuit breaker trips: **UO**. This wouldn’t be particularly helpful if this flag could only be obtained through Envoy logs, but, fortunately, it was [implemented in Istio](https://github.com/istio/istio/pull/9945), so that response flags that are available in Istio metrics and can be fetched by Prometheus.

Envoy除了响应代码外，还返回响应标志，并且存在一个专用响应标志来指示断路器跳闸:UO。如果这个标志只能通过特使日志获得，那么这将不会特别有用，但是，幸运的是，它在Istio中实现了，因此响应标志可以在Istio度量中使用，并且普罗米修斯可以获取这些响应标志。

Circuit breaker trips can be queried like this:

```
sum(istio_requests_total{response_code="503", response_flags="UO"}) by (source_workload, destination_workload, response_code)
```

## Circuit breaking with [Backyards](https://banzaicloud.com/blog/istio-the-easy-way/), the easy way!

When using Backyards, you don’t need to manually edit the `Destination Rules` to set circuit breaking configurations. Instead, you can achieve the same result via a convenient UI, or, if you prefer, through the [Backyards CLI](https://github.com/banzaicloud/backyards-cli) command line tool.

You don’t need to worry about misconfiguring your `Destination Rules` by forgetting to set `trafficPolicy.tls.mode` to `ISTIO_MUTUAL`. Backyards takes care of this for you; it finds out whether your service has mutual TLS enabled or not and sets the aforementioned field accordingly.

当使用后院时，您不需要手动编辑目标规则来设置断路配置。相反，您可以通过一个方便的UI，或者(如果您愿意的话)通过backyard CLI命令行工具来实现相同的结果。

您不必担心由于忘记设置trafficPolicy.tls而错误配置了目的地规则。ISTIO_MUTUAL模式。后院会为你解决这个问题;它查明您的服务是否启用了互TLS，并相应地设置上述字段。

> *The above is just one example of Backyards’ validation features, which can help protect you from potential misconfigurations. There are lots more!*

On top of this, you can see visualizations of and live dashboards for your services and requests, so you can easily determine how many of your requests were tripped by the circuit breaker, and from which caller and when.

在此之上，您可以看到您的服务和请求的可视化和活动仪表板，因此您可以轻松地确定有多少请求被断路器触发，以及来自哪个调用者和何时触发。

## Circuit breaking in action!

### CREATE A CLUSTER

First of all, we’ll need a Kubernetes cluster.

> I created a Kubernetes cluster on GKE via the free developer version of the [Pipeline platform](https://beta.banzaicloud.io/). If you’d like to do likewise, go ahead and create your cluster on any of the five cloud providers we support or on-premise using [Pipeline](https://beta.banzaicloud.io/). Otherwise bring your own Kubernetes cluster.
>
> 我通过管道平台的免费开发人员版本在GKE上创建了一个Kubernetes集群。如果您也想这样做，请继续在我们支持的五个云提供商或使用管道在本地创建集群。否则，请带上您自己的Kubernetes集群。

### INSTALL BACKYARDS

The easiest way by far of installing Istio, Backyards, and a demo application on a brand new cluster is to use the [Backyards CLI](https://github.com/banzaicloud/backyards-cli).

You just need to issue one command (`KUBECONFIG` must be set for your cluster):

```
$ backyards install -a --run-demo
```

This command first installs Istio with our open-source [Istio operator](https://github.com/banzaicloud/istio-operator), then installs Backyards itself as well as a demo application for demonstration purposes. After the installation of each component has finished, the Backyards UI will automatically open and send some traffic to the demo application. **By issuing this one simple command you can watch as Backyards starts a brand new Istio cluster in just a few minutes!** Give it a try!

该命令首先使用我们的开源Istio操作符安装Istio，然后安装后院本身以及演示应用程序。每个组件安装完成后，backyard UI将自动打开并向演示应用程序发送一些流量。通过发出这个简单的命令，您可以看到后院在几分钟内启动了一个全新的Istio集群!试试吧!

> You can do all these steps in sequential order as well. Backyards requires an Istio cluster - if you don’t have one, you can install Istio with `$ backyards istio install`. Once you have Istio installed, you can install Backyards with `$ backyards install`. Finally, you can deploy the demo application with `backyards demoapp install`.
>
> 您也可以按顺序执行所有这些步骤。后院需要一个Istio集群——如果没有，可以使用$ Backyards Istio install安装Istio。一旦安装了Istio，就可以使用$ backyard install安装backyard。最后，您可以使用backyard demoapp install部署演示应用程序。
>
> Tip: Backyards is a core component of the [Pipeline](https://github.com/banzaicloud/pipeline) platform - you can try the hosted developer version here: https://beta.banzaicloud.io/ (Service Mesh tab).



### CIRCUIT BREAKING USING THE BACKYARDS UI

#### Set circuit breaking configurations

You don’t need to create or edit a `Destination Rule` resource manually, you can easily change the circuit breaker configurations from the UI. Let’s first create a demo circuit breaker.

> As you will see, Backyards (in constrast to, say, Kiali) is not just a web-based UI built for observability, but is a feature rich management tool for your service mesh, is single- and multi-cluster compatible, and is possessed of a powerful CLI and GraphQL API.
>
> 正如您将看到的，backyard(与Kiali相比)不仅是为可观察性构建的基于web的UI，而且是针对服务网格的功能丰富的管理工具，支持单集群和多集群，并且具有强大的CLI和GraphQL API。

![Circuit Breaking set](https://banzaicloud.com/img/blog/istio/circuit-breaking-set.png)

#### View circuit breaking configurations

You don’t have to fetch the `Destination Rule` (e.g. with `kubectl`) to see the circuit breaker’s configurations, you can see them on the right side of the Backyards UI when you click on the `notifications` service icon and then toggle the `SHOW CONFIGS` slider.

您不需要获取目标规则(例如kubectl)来查看断路器的配置，当您单击notification service图标并切换SHOW CONFIGS滑块时，您可以在Backyards UI的右侧看到它们。

![Circuit Breaking view](https://banzaicloud.com/img/blog/istio/circuit-breaking-view.png)

#### Monitor circuit breaking

With this configuration I’ve just set, when traffic begins to flow from two connections simultaneously, the circuit breaker will start to trip requests. In the Backyards UI, you will see this being vizualized via the graph’s **red edges**. If you click on the service, you’ll learn more about the errors involved, and will see two live Grafana dashboards which specifically show the circuit breaker trips.

根据我刚刚设置的配置，当两个连接同时开始产生流量时，断路器将开始发出跳闸请求。在backyard UI中，您将看到这是通过图形的红色边缘实现的。如果您单击该服务，您将了解有关错误的更多信息，并将看到两个专门显示断路器跳闸的实时Grafana仪表板。

The first dashboard details the percentage of total requests that were tripped by the circuit breaker. When there are no circuit breaker errors, and your service works as expected, this graph will show `0%`. Otherwise, you’ll be able to see what percentage of the requests were tripped by the circuit breaker right away.

第一个仪表板详细说明了断路器触发的总请求的百分比。当没有断路器错误，而您的服务工作如预期，这张图将显示' 0% '。否则，您将能够立即看到有多少请求被断路器触发。

The second dashboard provides a breakdown of the trips caused by the circuit breaker by source. If no circuit breaker trips occurred, there will be no spikes in this graph. Otherwise, you’ll see which service caused the circuit breaker to trip, when, and how many times. Malicious clients can be tracked by checking this graph.

第二个仪表板提供了由源断路器引起的跳闸故障。如果没有发生断路器跳闸，则此图中不会出现尖峰。否则，您将看到哪个服务导致断路器跳闸，何时跳闸，跳闸次数。可以通过检查此图跟踪恶意客户机。

![Circuit Breaking trip](https://banzaicloud.com/img/blog/istio/circuit-breaking-trip.png)

> These are live Grafana dashboards customized in order to display circuit breaker-related information. Grafana and Prometheus are installed with Backyards by default - and lots more dashboards exist to help you dig deep into your service’s metrics.
>
> 这些是现场定制的Grafana仪表盘，用于显示电路断点相关信息。Grafana和Prometheus在默认情况下安装了后院——还有更多的仪表板可以帮助您深入挖掘服务的度量标准。

#### Remove circuit breaking configurations

You can easily remove circuit breaking configurations with the `Remove` button.

#### Circuit breaking on Backyards UI in action

To summarize all these UI actions let’s take a look at the following video:

<iframe width="704" height="315" src="https://www.youtube.com/embed/JH2xRv4a37M" frameborder="10" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen="" style="box-sizing: border-box; color: rgb(83, 83, 83); font-family: Lato; font-size: medium; font-style: normal; font-variant-ligatures: normal; font-variant-caps: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: 2; word-spacing: 0px; -webkit-text-stroke-width: 0px; background-color: rgb(255, 255, 255); text-decoration-style: initial; text-decoration-color: initial;"></iframe>



### CIRCUIT BREAKING USING THE [BACKYARDS-CLI](https://github.com/banzaicloud/backyards-cli)

As a rule of thumb, everything that can be done through the UI can also be done with the [Backyards CLI](https://github.com/banzaicloud/backyards-cli) tool.

#### Set circuit breaking configurations

Let’s put this to the test by creating the Circuit Breaker again, but this time through the CLI.

You can do this in interactive mode:

```
$ backyards r cb set backyards-demo/notifications
? Maximum number of HTTP1/TCP connections 1
? TCP connection timeout 3s
? Maximum number of pending HTTP requests 1
? Maximum number of requests 1024
? Maximum number of requests per connection 1
? Maximum number of retries 1024
? Number of errors before a host is ejected 1
? Time interval between ejection sweep analysis 1s
? Minimum ejection duration 3m
? Maximum ejection percentage 100
INFO[0043] circuit breaker rules successfully applied to 'backyards-demo/notifications'
Connections  Timeout  Pending Requests  Requests  RPC  Retries  Errors  Interval  Ejection time  percentage
1            3s       1                 1024      1    1024     1       1s        3m             100
```

Or, alternatively, in a non-interactive mode, by explicitly setting the values:

```
$ backyards r cb set backyards-demo/notifications --non-interactive --max-connections=1 --max-pending-requests=1 --max-requests-per-connection=1 --consecutiveErrors=1 --interval=1s --baseEjectionTime=3m --maxEjectionPercent=100
Connections  Timeout  Pending Requests  Requests  RPC  Retries  Errors  Interval  Ejection time  percentage
1            3s       1                 1024      1    1024     5       1s        3m             100
```

After the command is issued, the circuit breaking settings are fetched and displayed right away.

#### View circuit breaking configurations

You can list the circuit breaking configurations of a service in a given namespace with the following command:

```
$ backyards r cb get backyards-demo/notifications
  Connections  Timeout  Pending Requests  Requests  RPC  Retries  Errors  Interval  Ejection time  percentage
  1            3s       1                 1024      1    1024     5       1s        3m             100
```

By default, the results are displayed in a table view, but it’s also possible to list the configurations in `JSON` or `YAML` format:

```
$ backyards r cb get backyards-demo/notifications -o json
  {
    "maxConnections": 1,
    "connectTimeout": "3s",
    "http1MaxPendingRequests": 1,
    "http2MaxRequests": 1024,
    "maxRequestsPerConnection": 1,
    "maxRetries": 1024,
    "consecutiveErrors": 5,
    "interval": "1s",
    "baseEjectionTime": "3m",
    "maxEjectionPercent": 100
  }

$ backyards r cb get backyards-demo/notifications -o yaml
  maxConnections: 1
  connectTimeout: 3s
  http1MaxPendingRequests: 1
  http2MaxRequests: 1024
  maxRequestsPerConnection: 1
  maxRetries: 1024
  consecutiveErrors: 5
  interval: 1s
  baseEjectionTime: 3m
  maxEjectionPercent: 100
```

#### Monitor circuit breaking

To see similar dashboards from the CLI that you’ve seen earlier on the Grafana dashboards on the UI, trigger circuit breaker trips by calling the service from multiple connections and then issue the following command:

要从CLI中查看类似的仪表板(您在前面的界面上的Grafana仪表板上已经看到过)，可以通过从多个连接调用服务来触发断路器跳闸，然后发出以下命令

```
$ backyards r cb graph backyards-demo/notifications
```

You should see something like this:

![Circuit Breaking trip cli](https://banzaicloud.com/img/blog/istio/circuit-breaking-trip-cli.png)

#### Remove circuit breaking configurations

To remove circuit breaking configurations:

```
$ backyards r cb delete backyards-demo/notifications
INFO[0000] current settings
Connections  Timeout  Pending Requests  Requests  RPC  Retries  Errors  Interval  Ejection time  percentage
1            3s       1                 1024      1    1024     5       1s        3m             100
? Do you want to DELETE the circuit breaker rules? Yes
INFO[0008] circuit breaker rules set to backyards-demo/notifications successfully deleted
```

To verify that the command was successful:

```
$ backyards r cb get backyards-demo/notifications
  INFO[0001] no circuit breaker rules set for backyards-demo/notifications
```

### CIRCUIT BREAKING USING THE BACKYARDS GRAPHQL API

Backyards is composed of several components, like Istio, Banzai Cloud’s [Istio operator](https://github.com/banzaicloud/istio-operator), our multi-cluster [Canary release operator](https://banzaicloud.com/blog/istio-canary/), as well as several backends. However, all of these are behind **Backyards’ GraphQL API.**

The Backyards UI and CLI both use Backyards’ GraphQL API, which will be released with the GA version at the end of September! Users will soon be able to use our tools to manage Istio and build their own clients!

后院由多个组件组成，比如Istio、Banzai Cloud的Istio操作符、我们的多集群Canary release操作符，以及多个后端。然而，所有这些都在backyard的GraphQL API后面。

backyard UI和CLI都使用backyard的GraphQL API，它将在9月底与GA版本一起发布!用户将很快能够使用我们的工具来管理Istio和构建他们自己的客户端!

### CLEANUP

To remove the demo application, Backyards, and Istio from your cluster, you need only to apply one command, which takes care of removing these components in the correct order:

```
$ backyards uninstall -a
```



## Takeaway

With Backyards, you can easily configure circuit breaker settings from a convenient UI or with the [Backyards CLI](https://github.com/banzaicloud/backyards-cli) command line tool. Then you can monitor the circuit breaker from the Backyards UI with live embedded Grafana dashboards customized to show circuit breaker trip rates and the number of trips by source.

使用backyard，您可以通过方便的UI或backyard CLI命令行工具轻松配置断路器设置。然后，您可以使用定制的实时嵌入式Grafana仪表板从后院UI监视断路器，显示断路器跳闸率和按源计算的跳闸次数。

Next up, we’ll be covering **fault injection**, so stay tuned!