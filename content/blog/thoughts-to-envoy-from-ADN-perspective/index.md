---
title: "应用交付老兵眼中的Envoy, 云原生时代下的思考"
date: 2020-06-30T00:00:00+08:00
draft: false
banner: "/img/blog/banners/thoughts-to-envoy-from-ADN-perspective.jpg"
author: "林静"
authorlink: "https://cnadn.net"
originallink: "https://www.cnadn.net/post/2947.htm"
summary: "Envoy是云原生时代的明星，其本质是反向代理负载均衡类软件，领域上归于应用交付，那么作为应用交付领域的老兵如何看待Envoy，Envoy又引发了哪些关于传统应用交付领域的思考？"
tags: ["envoy","反向代理","NGINX","F5"]
categories: ["envoy"]
keywords: ["envoy","f5","nginx","ADN"]
---

Envoy，使者，使节，代表！就像其单词含义本身一样，带着一种权威感，一种全代理的神圣感。结合其本身用途与角色，真是“人如其名”，不禁为Lyft点赞，不知是得到了哪位大师的指点来起这个名字。在当前火热的微服务时代下，Envoy是个绝对的明星，用众人皆知来形容可以说一点也不为过。曾有人问我如何看Envoy以及在云原生时代下是否Enovy将取代F5取代NGINX，作为一个经历了两次应用交付技术领域更迭浪潮的老兵，在本文中我将来浅谈一下Envoy，以及试图从个人角度来理解与回答一下这个问题。为什么说浅谈一下，这真的不是谦虚，而是客观上真的没有那么深入的大规模长时间使用和研究Envoy的所有技术细节，因此我将结合我的从业经历与经验来对Envoy做一个浅谈。

## 星光熠熠的Envoy

首先我们看一下Envoy官方是如何介绍Envoy的：
> ENVOY IS AN OPEN SOURCE EDGE AND SERVICE PROXY, DESIGNED FOR CLOUD-NATIVE APPLICATIONS
> *Envoy是一个开源的边缘以及服务代理，为云原生应用而生。*

从网站首页的这一段描述可以清晰的看出官方对Envoy的定义，简单来说就是云原生时代下东西南北流量的代理。Lfyt公司是微服务应用架构的先导者，在大量的微服务类布道文章中我们都可以看到Lfyt的身影，在从单体应用大规模转向微服务架构后，一个严重的问题摆在了开发与架构人员面前，一方面Lyft的服务采用了多种语言开发，而采用类库来解决分布式架构下的各种问题需要进行大量的语言适配以及对代码的侵入，另一方面Lyft的业务都是部署在AWS上的，大量依赖AWS的ELB以及EC2，但是ELB以及AWS在当时所提供的服务间流量管控、洞察与问题排除都不能满足Lyft的需求，正是基于这样的背景，Lfyt于2015年5月开始了Envoy的开发，最早是作为一个边缘代理进行部署并开始替代ELB，随后开始作为sidecar方式进行大规模部署。2016年9月14日，Lyft在其博客上正式对外宣布了这一项目： [Envoy C++ L7代理与通信总线](https://eng.lyft.com/announcing-envoy-c-l7-proxy-and-communication-bus-92520b6c8191)。 一时间Envoy得到了大量的关注，Google等公司开始贡献到这个项目里，并在一年后的2017年9月将项目捐献给CNCF。有了Lyft这样一个好妈，又过继给了CNCF这样一个富爸，再加上同父异母的Istio明星兄弟的加持，可以说Envoy一时风光无两，赚足了眼球与开发者的支持，仅一年多点时间便从CNCF毕业了。

容器技术助推了企业实践Devops与进行微服务改造，k8s容器编排平台则让企业能够更加自信的将更多业务从传统架构迁移到基于容器的现代基础架构之上，k8s解决了容器编排、应用发布等问题，但是当服务之间的通信从以前的内存之间调用变成了基于TCP的网络通信后，网络对应用服务的影响变得更加巨大与不确定，基于传统的应用架构的运维手段无法适应与解决巨大且复杂的服务间通信洞察、排错，为了解决这样的问题sevice mesh应用而生，并迅速成为关注的热点，Istio项目则是此生态中最重要的玩家，Istio的架构是一个典型的管理平面与数据分离的架构，在数据平面的选择上是开放的，但是Istio默认选择了Envoy作为数据平面。两大人气明星强强联手，让几乎同一时期的linkerd变得黯然失色。而在这个时间点，NGINX同样也曾短暂的进行了Nginmesh项目，试图让NGINX作为Istio的数据平面，但最终在2018年底放弃了，为什么会放弃，这个本文后面会提到。

当前除了Istio选择Envoy作为数据平面外，以Envoy为基础的项目还有很多，例如k8s的多个Ingress Controller项目：Gloo, Contur, Ambassador。 Istio自身的Ingress gateway与Egress gateway同样选择的是Envoy。来看下其官方首页列出的Envoy用户，说星光熠熠一点也不为过。注意列表里的F5，是不是很有意思。

![envoy-end-user](envoy-endusers.jpg)
*（Envoy最终用户列表）*

## 后浪：为时代而生

下面我将从技术方面来看看为何Envoy能够得到社区的如此重视。将从以下几个方面来总结：
* 技术特征
* 部署架构
* 软件架构

### 技术特征

* 接口化与API
* 动态性
* 扩展性
* 可观测性
* 现代性

#### 接口化与API

当我第一次打开Envoy的配置时候，我的第一感觉是，天啊，这样一个产品用户该怎么配置和使用。先来直观的感受下，在一个并不复杂的实验环境下，一个Envoy的实际配置文件行数竟然达到了20000行。
```shell
#  kubectl exec -it productpage-v1-7f4cc988c6-qxqjs -n istio-bookinfo -c istio-proxy -- sh
$ curl http://127.0.0.1:15000/config_dump | wc -l
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  634k    0  634k    0     0  10.1M      0 --:--:-- --:--:-- --:--:-- 10.1M
20550
```
尽管这是Istio环境下的动态配置，虽然还有方式去优化使得实际配置量减少，或者说当完全使用静态配置方式进行配置的时候我们不会做如此大量的配置，但是当我们看到以下实际的配置结构输出就会感觉到对于这样一个软件，如果以普通方式进行配置与维护显然是不切实际的，其配置完全json结构化，并拥有大量的描述性配置，相对于NGINX等这些反向代理软件来说，其配置结构实在是过于复杂。
![复杂的配置结构](envoy-json.jpg)
*(复杂的配置结构)*

显然，Envoy的设计天生就不是为手工而设，因此Envoy设计了大量的xDS协议接口，需要用户自行设计一个xDS的服务端实现对所有配置处理，Envoy支持gRPC或者REST与服务端进行通信从而更新自身的配置。 xDS是Envoy DS（discover service）协议的统称，具体可分为Listener DS（LDS), Route DS(RDS), Cluster DS(CDS), Endpoint DS(EDS), 此外还有Secret DS，为了保证配置一致性的聚合DS-ADS等，更多的xDS可[查看这里](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/dynamic_configuration)。这些接口用于自动化产生各种具体不同的配置对象。可以看出，这是一个高度动态性的运行时配置，要想用好它则必须开发一个具有足够能力的server端，显然这不是传统反向代理软件的设计思维。
![envoyxDS](envoy-xds.png)
*(图片来自 https://gist.github.com/nikhilsuvarna/bd0aa0ef01880270c13d145c61a4af22)*

#### 动态性

正如前面所述，Envoy的配置高度依赖接口自动化产生各种配置，这些配置是可以进行Runtime修改而无需reload文件，在现代应用架构中，一个服务端点的生命周期都变得更短，其不运行的不确定性或弹性都变得更大，所以能够对配置进行runtime修改而无需重新reload配置文件这个能力在现代应用架构中显得尤其珍贵，这正是Istio选择Envoy作为数据平面的一个重要考虑。Envoy同时还具备热重启能力，这使得在升级或必须进行重启的时候变得更加优雅，已有连接能够得到更多的保护。

在Istio场景下，Envoy的容器里运行两个进程，一个叫pilot-agent，一个是envoy-proxy本身，pilot-agent负责管理与启动Envoy，并产生一个位于/etc/istio/proxy/下的envoy-rev0.json初始配置文件，这个文件里定义了Envoy应该如何与pilot server进行通信以获取配置，利用该配置文件最终启动Enovy进程。但是Envoy最终运行的配置并不仅仅是envoy-rev0.json里的内容，它包含上文所说的通过xDS协议发现的所有动态配置。

```shell
#  kubectl exec -it productpage-v1-7f4cc988c6-qxqjs -n istio-bookinfo -c istio-proxy -- sh
$ ps -ef
UID         PID   PPID  C STIME TTY          TIME CMD
istio-p+      1      0  0 Jun25 ?        00:00:33 /usr/local/bin/pilot-agent proxy sidecar --domain istio-bookinfo.svc.cluster.local --serviceCluster productpage.istio-bookinfo --proxyLogLevel=warning --proxyComp
istio-p+     14      1  0 Jun25 ?        00:05:31 /usr/local/bin/envoy -c etc/istio/proxy/envoy-rev0.json --restart-epoch 0 --drain-time-s 45 --parent-shutdown-time-s 60 --service-cluster productpage.istio-bookin
istio-p+    142      0  0 15:38 pts/0    00:00:00 sh
istio-p+    148    142  0 15:38 pts/0    00:00:00 ps -ef
```
在下图的envoy整体配置dump中可以看到包含了bootstrap的内容以及其它静态以及动态配置:
![envoy-config-dump](envoy-dump-config-json-struc.jpg.jpg)
*(Envoy配置结构)*

结合下图可以看出基本的Envoy配置结构及其逻辑, 无论是入口listener（类似F5的VS以及部分profile配置，NGINX的listener以及部分Server段落配置）还是路由控制逻辑（类似F5 LTM policy，NGINX的各种Locations匹配等），还是Clusters（类似F5 pool， NGINX的upstream）、Endpoints（类似F5 pool member，NGINX的upstream里的server），乃至SSL证书完全可以通过接口从服务侧自动化的发现过来
![envoy-objects](envoy-basic-objects-logic.png)
*(图片来自https://gist.github.com/nikhilsuvarna/bd0aa0ef01880270c13d145c61a4af22)*

#### 扩展性

Envoy的配置中可以看到大量的filter，这些都是其扩展性的表现，Envoy学习了F5以及NGINX的架构，大量使用插件式，使得开发者可以更加容易的开发。 从listener开始就支持使用filter，支持开发者开发L3,L4,L7的插件从而实现对协议扩展与更多控制。

在实际中，企业在C++的开发储备方面可能远不如JavaScript等这样的语言多，因此Envoy还支持Lua以及Webassembly扩展， 这一方面使得无需经常重新编译二进制并重启，另一方面降低了企业插件开发难度，让企业可以使用更多兼容Webassembly的语言进行插件编写，然后编译为Webassenmbly机器码实现高效的运行。目前来说Envoy以及Istio利用Webassembly做扩展还在早期阶段，走向成熟还需一段时间。
![envoy-traffic-logic](concept-envoy-filter.png)
*(图片来自https://www.servicemesher.com/istio-handbook/concepts/envoy.html)*

从上面的图可以看出，这样的请求处理结构非常的接近于F5 TMOS系统的设计思想，也在一定程度上与NGINX类似。连接、请求在不同的协议层面与阶段对应不同的处理组件，而这些组件本身是可扩展的、可编程的，进而实现对数据流的灵活编程控制。

#### 可观测性

说Envoy生来具备云原生的特质，其中一大特点就是对可观测性的重视，可以看到可观测的三大组件：[logs，metrics，tracing](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/observability/observability)默认都被Envoy所支持。

Envoy容许用户以灵活的方式在灵活的位置定义灵活的日志格式，这些变化可以通过动态配置下发从而实现立即生效，并容许定义对日志的采样等。在Metrics则提供了能够与Prometheus进行集成的诸多指标，值得一提的是Envoy容许filter本身来扩充这些指标，例如在限流或者验证等filter中容许插件本身定义属于自己的指标从而帮助用户更好的使用和量化插件的运行状态。在Tracing方面Envoy支持向zipkin，jaeger，datadog，lightStep等第三方集成，Envoy能够生产统一的请求ID并在整个网络结构中保持传播，同时也支持外部的x-client-trace-id，从而实现对微服务之间关系拓扑的描述。
![envoy-kiali](envoy-kiali.jpg)

Envoy生成的每个span包含以下数据：
 *  通过设置的原始服务集群--service-cluster。
 * 请求的开始时间和持续时间。
 * 通过设置的原始主机--service-node。
 * 通过x-envoy-downstream-service-cluster 标头设置的下游群集。
 * HTTP请求URL，方法，协议和用户代理。
 * 通过custom_tags设置的其他自定义标签。
 * 上游群集名称和地址。
 * HTTP响应状态代码。
 * GRPC响应状态和消息（如果可用）。
 * HTTP状态为5xx或GRPC状态不是“ OK”时的错误标记。
 * 跟踪特定于系统的元数据。

#### 现代性

其实，说Envoy具有现代性显然是正确的废话，Envoy天生为现代应用架构而生，这里主要是想从几个我们最容易能够感受到的方面来说明一下。首先是其特殊的结构设计，在Envoy里它支持利用iptables截取流量并做透明处理，其本身能够利用getsockopt()实现对NAT条目中原始目的信息的提取，并在listener监听上容许在从被跳转的端口listener中跳跃到实际能匹配原始目的信息的非绑定型listener，尽管从反向代理角度看这就有点像F5的VS内部跳转，NGINX的subrequest，但是其最大的特点和能力在于对连接的透明性，这在Pod sidecar模式的部署中显得尤其重要， 具体原理可参考[这里](https://www.cnadn.net/post/2945.htm)。

对于现代应用最爱的灰度发布，流量镜像，断路器，全局限流等等功能，其在配置上也非常的简洁，这一点尽管F5/NGINX等软件也能完成类似的工作，但在原生性上以及配置的难易程度上Envoy具有更大优势。

现代性的另一个表现就是对协议的支持，看看以下支持的协议，熟悉应用交付、反向代理软件的同学可能会情不自禁的表示赞叹，而这些协议的支持更从另一方面表现了Envoy作为更加面向开发者和SRE的一个特质。
 * gRPC
 * HTTP2
 * MongoDB
 * DynamoDB
 * Redis
 * Postgres
 * Kafka
 * Dubbo
 * Thrift
 * ZooKeeper
 * RockeMQ

### 部署架构

在了解完Envoy的技术特征后，再来从部署架构角度看Enovy。

完整Sidecar模型部署，这是Envoy最大的部署特征，services之间的通信完全转化为Envoy代理之间的通信，从而实现将诸多非业务功能从服务代码中移出到外部代理组件，Envoy负责网络通信控制与流量的可观测。也可以部署为简化的sidecar，其仅充当service入站方向的代理，无需额外的流量操纵，这个结构在我对外阐述的基于NGINX实现业务可观测性中所使用
![envoy-topo-1](t1.jpg)
*(图片来自https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request#request-flow)*

Hub型，这与NGINX的MRA中的Router-mesh型理念相同，所有服务使用一个集中的Envoy进行通信，这种部署结构一般适用于中小型服务，可通过与服务注册的适配将服务流量导向到Envoy
![envoy-topo-hub](t2.jpg)
*(图片来自https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request#request-flow)*

Envoy也可以作为Ingress edge网关或Egress 网关，在这种场景下一般Envoy多用于Ingress controller或API 网关，可以看到很多的此类实现喜欢使用Envoy作为底层，例如Gloo, Ambassador等
![envoy-topo-in-out](t3.jpg)
*(图片来自https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request#request-flow)*

下面这个部署结构应该是大家比较熟悉的，Envoy作为一个Edge 网关，并同时部署额外一层微服务网关（或代理平台层）
![envoy-topo-in-out](t5.jpg)
*(图片来自https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request#request-flow)*

最后，这是将所有形态的Envoy部署集中到了一起，这种架构可能会在服务从传统架构向微服务架构迁移过程的中间形态
![envoy-topo-all](t4.jpg)
*(图片来自https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request#request-flow)*

最后，来看以下Istio里是如何使用Envoy的
![envoy-istio](t6.jpg)
*(图片来自网络)*

总结来看，由于Envoy的跨平台性，使其具有和NGINX一样的灵活部署结构，但是实际上部署结构往往与最终的配置实现机制有着强关系，软件的能力能否适应在此结构下的灵活与简单的配置实现是最终考验。客观的讲，在这方面Envoy更具有优势。

### 软件架构

Envoy采用了单进程多线程的设计结构，主线程负责配置更新，进程信号处理等。请求则是由多个worker线程来处理，为了简化与避免处理复杂，一个连接始终由一个线程处理，这样可尽量减少线程间的数据共享而引发的一些锁操作。Envoy尽可能的避免线程之间的状态共享，为此设计了Thread Local Store机制。在日志的写入上，实际上是worker线程写入到内存缓存，最后再由文件刷新线程来负责写入到磁盘，这样可以在一定程度上提高效率。整体上来说，Envoy在设计时候还是比较偏重于简化复杂性，并强调灵活性，因此与NGINX不同它并没有把对性能的追求放在第一位，这一点在Envoy的相关官方博客里可以得到验证。
![envoy-threads](envoy-thread.png)
*图片来自 https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310*

与NGINX类似，Envoy整体是异步非阻塞的设计，采用的是事件驱动方式。每个线程都负责每一个listener，可以采用SO_REUSEPORT也可以共享socket，NGINX也有类似的机制。
![envoy-listener](t7.jpg)
*图片来自 https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request#request-flow*

当请求由listener监听并开始处理后，根据配置连接将会被后续的L3、4、7等多个filter进行处理。
![envoy proxy arch](envoy-arch.jpg)
*图片取自jimmysong.io*

## 前浪：宝刀未老

在了解完Envoy的技术特性及其架构后，我们再回到此文的原点。Envoy从起出生开始都带着对现代应用架构的基因，是不是说对于NGINX/F5等这些前浪就已经落伍了呢。

记得NGINX的作者Igor在F5中国520大会上曾这样对大家介绍NGINX为何如此成功。他说，他没有想到会如此成功，究其原因是他在正确的时间点开发了一个正确的软件。 我们知道，在2003年左右那个时期，还谈不上什么分布式架构、微服务，那时候主要要解决的是单机性能问题，正是基于这样的背景，NGINX无论从架构设计还是代码质量都严格苛求于性能。在功能上，NGINX本来是一款Web Server软件，L7反向代理则是其能力的延伸，而L4代理能力的增加则更晚，鉴于这样的背景，从现代应该应用架构角度来看，确实有一些能力是较难覆盖的。同样，Envoy诞生和发展于现代应用架构时代，正如Envoy自我阐述，其参考了大量已有的软硬件反向代理、负载均衡产品，从上面的技术分析中也可以看出Envoy有很多NGINX以及F5架构理念，可以说Envoy从成熟的反向代理产品中吸取了诸多精华，并在设计时候充分考虑现代应用架构的需求，它也是一个在正确的时间的一个正确软件。

微服务架构下，很多问题都变成了如何控制服务之间的通信与流量洞察，这是典型的应用交付领域，作为这个领域的前浪一方面需积极拥抱和适应新时代的应用架构，一方面需要创新并继续引领新的方向。历史上这个领域发生了两次技术革新，第一次是在2006年左右，当时一度关于“负载均衡已死”话题被炒爆，实质是当时市场开始发生变换，大家不再满足于简单的负载均衡，需求衍生到应用安全、网络优化、应用优化、接入控制、流量控制等更多复杂的场景，应用交付概念开始被提出，可以说在2006年前，市场的主要概念和技术方向是以四层交换机为核心理念的负载均衡技术，大部分玩家是传统网络厂商，思维与概念都是以网络交换为基础，而F5就像一个奇怪的家伙，产品设计思想完全在另一个维度之上，自2004年就开始发布的TMOS V9操作系统自此开始引领市场，此后10年，无人超越。第二次技术革新发生在2016年左右，受云、微服务的影响，软件化、轻量化变为市场主流，同时Devops思想意味着使用者角色发生了变化，传统的面向网络运维人员的设计开始变得难以满足市场需求。以F5为主导的这个领域在市场上也发生了新的变化，Gartner不再对应用交付领域发布魔力象限分析，转而形成以Guide方式的指导。
![F5stock](F5-stock.jpeg)
*F5股价走势图*

看当下，历史总是惊人的相似。 

现代应用架构飞速发展，大量应用开始微服务化，但从业务访问的整体链条来看，Enovy还不能解决所有问题，例如应用安全防护，复杂的企业协议，以及不同的组织关系导致的不同需求。可以看到以F5/NGINX为代表的应用交付产品在Devops大潮下也开始积极的实现产品融入，F5发布了完整的自动化工具链，从产品的bootstrap到网络配置、到应用服务配置，到最后的监控遥测都已经形成了完整的接口，并采用声明式接口来将产品管理提升到更高角色人群与管理系统中。NGINX同样构建了自身的API以及Controller平面，对外提供声明式API接口，开发者可以更好的利用接口融入自身的控制平面。这些变化都是为了让开发者或者SRE能够更好的使用F5/NGINX, 详细可以参考我的《从传统ADC迈向Cloud Native ADC》[系列文章](https://mp.weixin.qq.com/s?src=11&timestamp=1593224168&ver=2425&signature=znUdlLDdpbGGxWX7pZhH2uSVq1SAdQuloO09HIXssdQ15nRtWVOIgzlYTFmjOIUsDrqghPbSZM6vQI45TIqmINQKjposI7AfJ6jKQaEXm9KD4tEV5Bk9AF0RGuKvVuHI&new=1)。
![slides3](slides-3.jpg)

F5在收购NGINX与Shape之后，提出了新的view，将充分利用可广泛触达的数据平面能力，借助AI进一步挖掘数据潜能帮助用户更好的掌握和了解应用行为、性能，为业务运营提出参考，并反馈到组件配置与运行管理，从而形成闭环。

现代应用交付依然不能缺少一个重要场景，那就是应用安全，尽管Istio等产品在安全通信，身份，策略方面做了不好的尝试，但是应用安全本身则比较缺乏，F5作为WAF安全领域的领导厂商，通过将安全能力转移到NGINX上形成了新的NGINX APP Protect，利用其跨平台的能力帮助用户更好的管理微服务场景下的应用安全能力，帮助企业更好的落地DevSecOps。

如果将Envoy的那些技术特征与F5进行对比的话，我们可以看到F5一定程度上欠缺在扩展性与现代性上，F5具有较好的编程控制能力，但是相对于更大的插件开发来说是不足的，这和现代性往往可以联系到一起看，比如想针对某个很新的协议做一个类似Envoy的复杂7层filter是无法实现的，尽管iRule或者iRuleLX可以一定程度上做一些事情。然而无论怎样，最终F5的产品形态本身决定了F5的BIGIP是无法完全跨平台的，因为它无法以容器来运行。值得期待的是，这样的形态限制将会被F5 下一代TMOS系统打破。

Service Mesh是当前热门的技术方向，F5 基于Istio打造了企业级的Aspen Mesh服务网格产品，帮助企业更好、更容易的部署和使用Istio。 Aspen mesh团队成员进入仅有7个位置的的Istio Technical Oversight Committee，负责Istio的RFCs/Designs/APIs等方面的重要职责。尽管Istio在service mesh领域拥有绝对的生态与热度，但这并不表示Istio是唯一的选择，在很多时候客户可能希望采用一种更加简洁的Service Mesh去实现大部分所需功能而不是去部署一整套复杂的Istio方案，基于NGINX组件打造的NGINX Service Mesh(NSM)将为用户带来新的选择，一个更加简单易用的Service Mesh产品，这是我们在文章最开始提到NGINX终止Nginmesh的原因。

## 总结

技术发展是一个必然的过程，2006年从传统的负载均衡技术演变为应用交付，除了负载均衡之外，引入安全、访问控制、接入控制、流量控制等诸多方面。2016年左右，这个领域再次发生新的技术变革，大量新生代反向代理开源软件的出现对传统应用交付类产品产生了一次新的冲击，积极适应与改变并创新是制胜的关键。Envoy作为新代表有着优秀的能力，但它也不是解决所有问题的银弹，Envoy拥有更陡峭的学习曲线以及更高开发成本与维护成本，对于企业来说应根据实际情况选择合适的解决方案与产品来解决架构中的不同问题，避免追赶潮流而让自己陷入陷阱。

F5则更加需要让开发人员了解TMOS系统所拥有的巨大潜能（特别是下一代产品在架构以及形态上的颠覆），了解其优秀全代理架构以及可以在任意层面进行的编程控制， 让开发者、SRE以F5 TMOS作为一种能力平台和中间件进行开发，更好的利用F5自身已经拥有的应用交付能力来快速实现自身需求。

最后，再次引用Envoy官方网站首页的一句话：
> 正如微服务从业者很快意识到的那样，当转移到分布式体系结构时出现的大多数操作问题最终都基于两个方面：网络和可观察性。

而保证更可靠的网络交付与更好的可观察性正是前浪们的强项。创新吧，前浪。

写在最后：
无论技术如何更迭，人的因素依旧是核心，不论企业自身还是厂商，在这样一轮技术浪潮中都应具备足够的技术储备，就像传统金融行业通过建立科技公司寻求转变一样，厂商同样需要转型，F5中国的SE几乎100%的通过了CKA认证，无论相对比例还是绝对数量在业界应该是惟一了，转型不只在产品，更在于思想。


