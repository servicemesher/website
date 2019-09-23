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

Istio因免费的可观察性和安全的服务间通信而受到了赞许。然而，其他更重要的功能使Istio真正成为了服务网格里的瑞士军刀，当遇到运行时长、延迟和错误率等SLO问题时，服务间的流量管理能力是至关重要的。

在今年早些时候发布 [Istio operator](https://github.com/banzaicloud/istio-operator) 时，我们的目标（除了管理Istio的安装和升级）是为这些出色的流量路由特性提供支持，同时使所有的功能都更加易用。最后，我们创建了一个简单且自动化的服务网格[Backyards](https://banzaicloud.com/blog/istio-the-easy-way/)，它在Istio operator之上提供了管理UI、[CLI](https://github.com/banzaicloud/backyards-cli) 和GraphQL API的能力。Backyards集成到了Banzai云的容器管理平台 [Pipeline](https://github.com/banzaicloud/pipeline)中。它也可以作为一个单一的产品独立工作。当然，将Backyard与Pipeline一起使用为用户提供了各种特别的好处（比如在[多云和混合云](https://banzaicloud.com/blog/istio-multicluster-the-easy-way/)环境中管理应用程序），Backyard也可以被用于任何Kubernetes的安装环境。

> 我们已经发布了一些和Backyards相关特性的文章：
>
> - [使用Backyards自动金丝雀部署](https://banzaicloud.com/blog/istio-canary/)
> - [流量切换](https://banzaicloud.com/blog/istio-traffic-shifting/)



## 熔断：失败是一个选项

在微服务架构中，服务可能会用不同的语言实现并部署在多个节点或集群上，具有不同的响应时间或故障率。如果服务成功（并且及时地）响应了请求，那么它的性能就算是令人满意的。但经常发生的情况并非如此，下游客户端应该在上游服务过于缓慢时受到保护。反之，上游服务也必须被保护，以免被积压的请求拖垮。在多客户端的情况下会更加复杂，并可能导致整个基础设施出现一系列的连锁故障。这一问题的解决方案是采用经过时间检验的断路器模式。

一个断路器可以有三种状态：关闭、打开和半开，默认情况下处于关闭状态。在关闭状态下，无论请求成功或失败，到达预先设定的故障数量阈值前，都不会触发断路器。而当达到阈值时，断路器就会打开。当调用处于打开状态的服务时，断路器将断开请求，这意味着它会直接返回一个错误，而不去执行调用行为。通过在客户端断开下游请求的方式，可以在生产环境中防止级联故障的发生。在一个配置的超时发生后，断路器进入半开状态，在这种状态下，故障服务有时间从其中断的行为中恢复。如果请求在这种状态下继续失败，则断路器将再次打开并继续阻断请求。否则断路器将关闭，服务将被允许再次处理请求。

![Circuit Breaking](https://banzaicloud.com/img/blog/istio/circuit-breaking.png)

## [Istio](https://istio.io/)中的熔断

Istio的 [熔断](https://istio.io/docs/tasks/traffic-management/circuit-breaking/) 可以在 [流量策略](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#TrafficPolicy) 中配置。在 Istio的 [自定义资源](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)`Destination Rule`中，`TrafficPolicy`字段下有两个和熔断相关的配置： [ConnectionPoolSettings](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#ConnectionPoolSettings) 和 [OutlierDetection](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#OutlierDetection)。

`ConnectionPoolSettings`中可以为服务配置连接的数量。`OutlierDetection`用来控制从负载均衡池中剔除不健康的服务。

例如，`ConnectionPoolSettings`控制请求的最大数量，挂起请求，重试或者超时；`OutlierDetection` 设置服务被从连接池剔除时发生错误的数量，可以设置最小逐出时间和最大逐出百分比。有关完整的字段列表，请参考[文档](https://istio.io/docs/reference/config/networking/v1alpha3/destination-rule/#TrafficPolicy).

> Istio在底层使用了[Envoy的熔断特性](https://www.envoyproxy.io/learn/circuit-breaking)。

让我们来看看`Destination Rule`中有关熔断的配置：

```yaml
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

使用`ConnectionPoolSettings`字段中的这些设置，在给定的时间内只能和`notifications` 服务建立一个连接：每个连接最多只能有一个挂起的请求。如果达到阈值，断路器将开始阻断请求。

`OutlierDetection`部分的设置用来检查每秒调用服务是否有错误发生。如果有，则将服务从负载均衡池中逐出至少三分钟（100%最大弹出百分比表示，如果需要，所有的服务都可以同时被逐出）。

> 在手动创建`Destination Rule`资源时有一件事需要特别注意，那就是是否为该服务启用了mTLS。如果是的话，还需要在`Destination Rule`中设置如下字段，否则当调用`movies`服务时，调用方可能会收到503错误：
>
> ```yaml
>trafficPolicy:
> tls:
>  mode: ISTIO_MUTUAL
>   ```
>    
> 还可以为特定[名称空间](https://istio.io/docs/tasks/security/authn-policy/#namespace-wide-policy) 或特定[服务](https://istio.io/docs/tasks/security/authn-policy/#service-specific-policy)启用[全局](https://istio.io/docs/tasks/security/authn-policy/#globally-enabling-istio-mutual-tls)的mTLS。您应该了解这些设置以便确定是否把`trafficPolicy.tls.mode`设置为 `ISTIO_MUTUAL`。更重要的是，当你试图配置一个完全不同的特性（例如断路）时，很容易忘记设置此字段。
>
> 提示：在创建`Destination Rule`前总是考虑mTLS！

为了触发断路，让我们同时从两个连接来调用 `notifications`服务。`maxConnections`字段被设置为1。这时应该会看到503与200的响应同时到达。

当一个服务从客户端接收到的负载大于它所能处理的负载（如断路器中配置的那样），它会在调用之前返回503错误。这是防止错误级联的一种方法。

### 监控断路器

在生产环境中必须要监控你的服务，以便得到通知并能够在系统发生错误时进行调查。因此，如果你已经为你的服务配置了一个断路器，您就会想知道它什么时候跳闸；断路器触发了百分之多少的请求；何时触发，来自哪个下游客户端？如果你能够回答这些问题，你就可以确定断路器是否工作正常，根据需要微调配置，或者优化服务来处理额外的并发请求。

> 提示：如果你继续阅读，你可以在Backyards UI中看到和配置所有的这些设置。

让我们看看怎样在Istio里确定熔断器跳闸：

断路器跳闸时的响应码是503，因此你无法仅根据该响应与其他的503错误区分开来。在Envoy中，有一个计数器叫`upstream_rq_pending_overflow`，它记录了熔断并失败的请求总数。如果为你的服务深入研究Envoy的统计数据就可以获得这些信息，但这并不容易。

除了响应代码，Envoy还返回[响应标志](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log#config-access-log-format-response-flags) ，并且存在一个专用响应标志来表示断路器跳闸：**UO**。如果这个标志只能通过Envoy的日志获得，这将不会特别有用。幸运的是，它在Istio中[实现](https://github.com/istio/istio/pull/9945)了，因此响应标志在Istio指标中是可用的并且能被Prometheus获取到。

熔断器的跳闸可以像这样查询到：

```basic
sum(istio_requests_total{response_code="503", response_flags="UO"}) by (source_workload, destination_workload, response_code)
```

## [Backyards](https://banzaicloud.com/blog/istio-the-easy-way/)的熔断更简单!

使用Backyards时，你不需要手动编辑`Destination Rules`来设置断路。可以通过一个方便的UI界面或者（如果您愿意的话）是[Backyards CLI](https://github.com/banzaicloud/backyards-cli) 命令行工具来实现相同的结果。

不必担心由于忘记把`trafficPolicy.tls.mode` 设置为 `ISTIO_MUTUAL`而配错了`Destination Rules`。Backyards会为你解决这个问题；它会找到启用了mTLS的服务并相应地设置上述字段。

> 上面只是Backyards验证特性的一个例子，这能避免你设置错误。还有更多的特性。

在此之上，你可以看到服务和请求的可视化界面和活动仪表板，因此你可以轻松地确定有多少请求被断路器触发，以及它来自哪个调用者和何时触发。

## 熔断实战

### 创建一个集群

首先，我们需要一个Kubernetes集群。

> 我通过[Pipeline platform](https://beta.banzaicloud.io/)的免费开发版本在GKE上创建了一个Kubernetes集群。如果你也想这样做，可以在我们支持的五个云提供商或使用[Pipeline](https://beta.banzaicloud.io/)在本地创建集群。否则，你需要提供自己的Kubernetes集群。

### 安装BACKYARDS

在一个新集群安装Istio，Backyards和demo应用的最简单的办法是使用[Backyards CLI](https://github.com/banzaicloud/backyards-cli)。

你只需要执行下面的命令（集群必须设置了`KUBECONFIG`）：

```bash
$ backyards install -a --run-demo
```

该命令首先使用我们开源的[Istio operator](https://github.com/banzaicloud/istio-operator)安装Istio，然后安装Backyards和demo应用程序。安装完成后，Backyards UI将自动打开并向demo应用发送一些流量。通过这个简单的命令，您可以看到Backyards在几分钟内启动了一个全新的Istio集群！试试吧！

> 您也可以按顺序执行所有这些步骤。Backyards需要一个Istio集群——如果没有，可以通过`$ backyards istio install`安装Istio。一旦安装了Istio，就可以使用`$ backyards install`安装BackyarBs。最后，使用`$ backyards demoapp install`部署demo应用程序。
>
> 提示：Backyards是[Pipeline](https://github.com/banzaicloud/pipeline)平台的核心组件——可以尝试开发者版本：https://beta.banzaicloud.io/ （Service Mesh 标签页）。



### 使用BACKYARDS UI

#### 配置熔断

你不需要手动创建或编辑`Destination Rule`，可以很容易的在UI界面中改变熔断的配置。让我们先创建一个demo。

> 正如您将看到的，Backyards（与Kiali相比）不仅是为可观察性构建的web UI，而且是具有丰富功能的服务网格管理工具，支持单集群和多集群，并且具有强大的CLI和GraphQL API。

![Circuit Breaking set](https://banzaicloud.com/img/blog/istio/circuit-breaking-set.png)

#### 查看熔断设置

您不需要获取`Destination Rule`（例如通过kubectl）来查看断路器的配置，当您点击`notification` 服务图标并切换`SHOW CONFIGS`滑块时，可以在Backyards UI的右侧看到它们。

![Circuit Breaking view](https://banzaicloud.com/img/blog/istio/circuit-breaking-view.png)

#### 监控熔断

根据刚才的设置，当两个连接同时产生流量时，断路器将发出跳闸请求。在Backyards UI中，您将看到图形的边缘出现了红色。如果单击该服务，您将了解有关错误的更多信息，并将看到两个专门用来显示断路器跳闸的实时Grafana仪表板。

第一个仪表板展示了断路器触发的总请求的百分比。当没有断路器错误，而您的服务工作正常，这张图将显示`0% `。否则，您将能够立即看到有多少请求被断路器触发。

第二个仪表板提供了由源断路器引起的跳闸故障。如果没有发生跳闸，则此图中不会出现尖峰。否则，您将看到哪个服务导致了跳闸，何时跳闸，以及跳闸次数。可以通过此图来追踪恶意的客户端。

![Circuit Breaking trip](https://banzaicloud.com/img/blog/istio/circuit-breaking-trip.png)

> 这些是实时的Grafana仪表盘，用于显示熔断相关的信息。在默认情况下Backyards集成了Grafana和Prometheus——还有更多的仪表板可以帮助您深入查看服务的指标。

#### 移除熔断配置

可以通过 `Remove` 按钮很容易的移除熔断配置。

#### Backyards UI 的熔断实战

下面的视频总结了所有这些UI操作：

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