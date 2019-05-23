## Exploring Istio telemetry and observability

## Istio遥测和可观察性探索

One of the core features of the Istio service mesh is the observability of network traffic. Because all service-to-service communication is going through Envoy proxies, and Istio’s control plane is able to gather logs and metrics from these proxies, the service mesh can give you deep insights about your network. While a basic Istio installation is able to set up all the components needed to collect telemetry from the mesh, it’s not easy to understand how these components fit together and how to configure them in a production environment. It becomes even more difficult when the mesh expands to multiple clusters across different cloud providers, or in a hybrid or edge-compute environment. This blog post tries to explain how Istio telemetry works and walks through some practical monitoring examples, like configuring Prometheus targets and exploring available metrics. At the end of the post, you’ll get a sneak peak into Banzai Cloud’s new [Pipeline](https://github.com/banzaicloud/pipeline) component - a multicloud and hybridcloud management platform built on top of our [Istio operator](https://github.com/banzaicloud/istio-operator).

Istio的一个核心功能就是网络流量的可观察性。因为所有服务间的通信都通过Envoy代理，而且Istio的控制平面可以从这些代理收集日志和指标，服务网格能够让你深入了解你的网络状况。虽然Istio的基本安装就装好了收集遥测数据所需的全部组件，但是理解这些组件如何配合，并且使他们能够工作在生产环境中却不是一个容易的事情。如果服务网格扩展到跨越多个云服务提供商的多个群集时，或者在一个混合情况下，甚至在边缘计算环境下，这个工作就更加困难。我们在这篇文章中，尽可能解释清楚Istio的遥测是怎么工作的，并且会完整浏览的一些监控例子，包括如何配置Prometheus的目标和尝试不同可用的指标。看完这篇文章，你将会对Banzai云中新的[Pipeline](https://github.com/banzaicloud/pipeline)组件有一个提前了解-它是一个跨云和混合云管理平台，基于顶尖的[Istio运营者](https://github.com/banzaicloud/istio-operator)开发。

### MIXER AND ENVOYS

### Mixer与智能代理（Envoy）

The Istio control-plane is split into a few different components, one of them is called Mixer. But Mixer itself is two different deployments in Kubernetes. One is called `istio-policy`, the other is called `istio-telemetry`. As their names already tell, these components are responsible for providing policy controls and telemetry collection respectively.

Istio的控制平面由几个不同部分组成，其中一个是Mixer。Mixer自身在Kubernetes里面又有两个不同的独立部署。一个叫做`istio-policy`，另一个叫`istio-telemetry`。就像它们的名字，这些组件负责提供控制策略和遥测数据收集功能。

The Envoy sidecars from the application pods call `istio-policy` before each request to perform precondition policy checks, and after each request to report telemetry. The sidecar has local caching such that a large percentage of precondition checks can be performed from cache. Additionally, the sidecar buffers outgoing telemetry such that it only calls Mixer infrequently.

应用pod的sidecar在发起每一个请求前调用`istio-policy`来进行前置条件检查，并在请求结束后发送遥测数据。sidecar本地缓存了一大批前置检查，使得大量的检查只需要通过缓存就能获得结果。额外的，sidecar还对输出的遥测数据进行了缓冲，以减少调用mixer的频率。

Running Mixer on the Istio control-plane is optional, if you don’t want central policy checks and telemetry you can disable these components completely. When enabled, these components are highly extensible, and can be driven entirely from custom resource configuration. If you don’t want to dive deep into Istio configuration, or don’t want to use your own infrastructure backends to collect logs or metrics but rely on the defaults (stdio logs, Prometheus metrics), you won’t need to care about these things at all.

在Istio的控制平面上运行mixer是可选的，如果你不需要集中式的策略检查和遥测，那么你可以把这些组件彻底关掉。这些组件具有非常高的扩展性，并且能够在自定义资源配置中进行完整配置。如果不想涉及Istio配置过深，或者不想使用自己的后端基础设施去收集日志和遥测数据，而想完全采用默认值（stdio logs，Prometheus指标），你完全可以一点不操心这些。

But if you’d like to use a different *adapter* - like *Stackdriver* - you’ll need to update the custom resource configuration of Mixer. Istio has the concept of `handlers`, `instances`and `rules`. `Handlers` determine the set of infrastructure backend adapters that are being used and how they operate, `instances` describe how to map request attributes into adapter inputs, and `rules` bind `handlers` and `instances` together. If you want to learn more about these concepts, you can read the official docs [here](https://istio.io/docs/concepts/policies-and-telemetry/#configuration-model), but this blog post will provide some examples of the defaults later.

如果你想用一个不同的`适配器` - 如`Stackdriver`- 你需要更新mixer的自定义资源配置。Istio中有几个概念叫做`处理器`，`实例`以及`规则`。`处理器`决定一系列后端基础设置适配器是怎么工作以及如何操作的，`实例`描述了如何把请求的属性映射到适配器的输入上，最后`规则`把`处理器`和`实例`拼接在一起。这些概念如果你想了解更多，你可以查看[官方文档](https://istio.io/docs/concepts/policies-and-telemetry/#configuration-model)，这篇文章最后也会演示一下一些默认的例子。

![img](./istio-telemetry.png)

### CONFIGURING PROMETHEUS TO SCRAPE SERVICE MESH METRICS

### 配置Prometheus收集网格数据

Istio’s documentation has some examples about [collecting custom metrics](https://istio.io/docs/tasks/telemetry/metrics/collecting-metrics/), or [querying metrics from Prometheus](https://istio.io/docs/tasks/telemetry/metrics/querying-metrics/), but it lacks a very important topic: understanding and configuring Prometheus scrape targets.

Istio的文档列举了[收集自定义指标](https://istio.io/docs/tasks/telemetry/metrics/collecting-metrics/)，以及[从Prometheus中查询指标](https://istio.io/docs/tasks/telemetry/metrics/querying-metrics/)的例子，但缺少一个重要的内容：理解和配置Prometheus的手机目标。

If you just want to try out Istio, you’ll probably deploy it using the official Helm chart (though we recommend our [Istio operator](https://github.com/banzaicloud/istio-operator) for a better experience). The Helm chart includes a Prometheus deployment by default where targets are properly configured. But in a production environment, you usually have your own way of setting up Prometheus and configuring your own targets to scrape. If that’s the case, you’ll need to include the Istio scrape targets manually in your configuration.

如果你只是想试一试Istio，多半你会部署了它的官方图表工具Helm（我们更推荐[Istio operator](https://github.com/banzaicloud/istio-operator)以获取更好的体验）。Helm图表默认包含了Prometheus部署并且也已经配置好。但是在生产环境下，你通常需要自定义设置Prometheus以及配置它的收集目标。这样情况下，你需要手工将Istio抓取目标也配置进去。

First, let’s take a look at these targets. If you check out the configuration [here](https://github.com/istio/istio/blob/1.1.6/install/kubernetes/helm/istio/charts/prometheus/templates/configmap.yaml#L12), you’ll see that Istio adds more than ten jobs to Prometheus. Most of them are collecting custom metrics from the Istio control plane components. An example of that is how Pilot reports telemetry about `xDS` pushes, timeouts or internal errors through metrics like `pilot_xds_pushes`, `pilot_xds_push_timeout` and `pilot_total_xds_internal_errors`. These jobs are named after the components and scrape the `http-monitoring` port of the corresponding Kubernetes service. For example, the job that scrapes pilot looks like this:

首先，我们来看看这些目标。如果你打开这里的配置，你会发现Istio给Prometheus添加了十多个jobs。大部分是从Istio控制平面收集自定义指标的。你可以看到Pilot通过类似`pilot_xds_pushes`, `pilot_xds_push_timeout` and `pilot_total_xds_internal_errors`这些指标上报遥测数据，如`xDS`推送，超时或内部错误。这些jobs紧跟在组件名称后，并通过Kubernetes服务中`http-monitoring`对应的端口上报。下面列举了一个pilot的例子：

```
- job_name: 'pilot'
  kubernetes_sd_configs:
  - role: endpoints
    namespaces:
      names:
      - {{ .Release.Namespace }}
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
    action: keep
    regex: istio-pilot;http-monitoring
```

But the two most important targets are `istio-mesh` and `envoy-stats`. Including the first one in `prometheus.yml` will allow Prometheus to scrape `Mixer`, where service-centric telemetry data is provided about all network traffic between the Envoy proxies. `envoy-stats` on the other hand will query the Envoy proxies directly and will collect endpoint-centric telemetry data about the same network traffic (see metrics like `envoy_cluster_upstream_rq`).

最重要的两个目标是`istio-mesh`和`envoy-stats`。Including the first one in `prometheus.yml` will allow Prometheus to scrape `Mixer`, where service-centric telemetry data is provided about all network traffic between the Envoy proxies.另一方面来说，`envoy-stats`直接查询Envoy的代理，并收集网络内中央节点的遥测数据（可以查看类似`envoy_cluster_upstream_rq`这样的指标）。

Mixer uses Pilot to enhance the telemetry data reported by Envoys with Kubernetes service details, so data coming from Mixer will contain richer information that includes service and workload names among other Kubernetes specific stuff. But according to some [blog posts](https://medium.com/@michael_87395/benchmarking-istio-linkerd-cpu-at-scale-5f2cfc97c7fa), sending telemetry data from every sidecar proxy in the cluster to a central deployment has some severe performance effects, and it may be worth turning Mixer completely off on a large cluster, and relying only on `envoy-stats`, even if that means losing feature parity.

Mixer通过Pilot来加强Kubernetes中Envoys上报的采样数据，所以从Mixer来的数据包含更丰富的信息，包括服务、负载名称以及其它Kubernetes特定的内容。但也有一些[博文]((https://medium.com/@michael_87395/benchmarking-istio-linkerd-cpu-at-scale-5f2cfc97c7fa)，从群集中的每一个sidecar代理收集遥测数据，有时候会引起性能问题，所以在一个大的群集里面，有时候完全关闭Mixer，只通过`envoy-stats`中转也是值得的，即使这意味着会丢失部分功能。



The `yaml` config for `istio-mesh` adds a job that queries the `istio-telemetry` service’s `prometheus` port:

下面是一个`istio-mesh`添加一个job，查询`istio-telemetry`服务的`prometheus`端口的`yaml`配置，

```
- job_name: 'istio-mesh'
  kubernetes_sd_configs:
  - role: endpoints
    namespaces:
      names:
      - {{ .Release.Namespace }}
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
    action: keep
    regex: istio-telemetry;prometheus
```

The `yaml` config of `envoy-stats` is more complicated, but the important part is here. It selects pods with a port name `*-envoy-prom` and queries `/stats/prometheus`:

```
- job_name: 'envoy-stats'
  metrics_path: /stats/prometheus
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_container_port_name]
    action: keep
    regex: '.*-envoy-prom'
```

When using the [Helm chart](https://github.com/helm/charts/tree/master/stable/prometheus) to deploy Prometheus to a cluster, these targets can be added to `values.yaml`, or directly edited in the `configmap` that holds `prometheus.yaml` and is mounted to the Prometheus server pod.

#### Using Prometheus operator

A better way to deploy Prometheus to a cluster is to use the [Prometheus operator](https://github.com/coreos/prometheus-operator/). In that case configuring targets is a bit different - instead of editing `prometheus.yml` directly, you can define `ServiceMonitor` custom resources that declaratively describe a set of services to monitor, and the operator will translate them to proper Prometheus `yaml`configuration in the background. For example, a `ServiceMonitor` entry that defines the scraping configuration of `mixer` telemetry looks like this:

```
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-monitor
  labels:
    monitoring: services
spec:
  selector:
    matchExpressions:
      - {key: istio, operator: In, values: [mixer]}
  namespaceSelector:
    matchNames:
      - istio-system
  jobLabel: istio-mesh
  endpoints:
  - port: prometheus
    interval: 5s
  - port: http-monitoring
    interval: 5s
```

It matches the label selector `istio=mixer` and queries the endpoint ports `prometheus` and `http-monitoring` every 5 seconds. As above, Mixer provides custom metrics about its own operation on the `http-monitoring` port, but provides the aggregated service-centric metrics about the network traffic on port `prometheus`.

### DEFAULT METRICS

In the Istio documentation, the first task about metrics has the title [Collecting new metrics](https://istio.io/docs/tasks/telemetry/metrics/collecting-metrics/). It does a good job describing how Istio utilises custom resources to configure `instances`, `handlers` and `rules`, and how to create a new metric that Istio will generate and collect automatically, but it can be considered as an advanced scenario. In most use cases, the default set of metrics covers everything that’s needed, and an Istio user doesn’t need to understand these underlying concepts.

Our [Istio operator](https://github.com/banzaicloud/istio-operator) (and also the Istio Helm charts) comes with these default metrics initialised. If you have Istio up and running in a cluster, and Prometheus is configured to scrape telemetry from Mixer, you won’t need to do anything else to have telemetry data about network traffic between services in the mesh. Once you have some traffic between Envoy sidecars, you can open the Prometheus UI (or use the query API) to check out metrics collected by Prometheus.

The default metrics are standard information about `HTTP`, `gRPC` and `TCP` requests and responses. Every request is reported by the `source` proxy and the `destination` proxy as well and these can provide a different view on the traffic. Some requests may not be reported by the `destination` (if the request didn’t reach the destination at all), but some labels (like `connection_security_policy`) are only available on the `destination` side. Here are some of the most important *HTTP* metrics:

- `istio_requests_total` is a `COUNTER` that aggregates request totals between Kubernetes workloads, and groups them by response codes, response flags and security policy. This can be useful to compute the request rate (`RPS`) between different workloads. An example query can be something like this (using the [Bookinfo example](https://istio.io/docs/examples/bookinfo/)). It computes the *requests per second* in the last hour between the `productpage` and the `reviews` services, and groups the results by response code and workload subsets:

```
sum(rate(istio_requests_total{reporter="source",source_workload="productpage-v1",destination_service_name="reviews"}[1m])) by (source_workload,source_version,destination_service_name,destination_workload,destination_version,request_protocol,response_code)
{destination_service_name="reviews",destination_version="v2",destination_workload="reviews-v2",request_protocol="http",response_code="200",source_version="v1",source_workload="productpage-v1"}	12.71
{destination_service_name="reviews",destination_version="v3",destination_workload="reviews-v3",request_protocol="http",response_code="200",source_version="v1",source_workload="productpage-v1"}	12.72
{destination_service_name="reviews",destination_version="v1",destination_workload="reviews-v1",request_protocol="http",response_code="200",source_version="v1",source_workload="productpage-v1"}	6.35
{destination_service_name="reviews",destination_version="v1",destination_workload="reviews-v1",request_protocol="http",response_code="503",source_version="v1",source_workload="productpage-v1"}	6.37
```

- `istio_request_duration_seconds` is a histogram that collects latency between workloads. The following example computes the 95th percentile latency of successful requests between the `productpage` and the `reviews` services, and groups the results by workload subsets.

```
histogram_quantile(0.95, sum(rate(istio_request_duration_seconds_bucket{reporter="source",source_workload="productpage-v1",destination_service_name="reviews",response_code="200"}[60m])) by (le,source_workload,source_version,destination_service_name,destination_workload,destination_version,request_protocol))
{destination_service_name="reviews",destination_version="v2",destination_workload="reviews-v2",request_protocol="http",source_version="v1",source_workload="productpage-v1"}	0.1201
{destination_service_name="reviews",destination_version="v3",destination_workload="reviews-v3",request_protocol="http",source_version="v1",source_workload="productpage-v1"}	0.1345
{destination_service_name="reviews",destination_version="v1",destination_workload="reviews-v1",request_protocol="http",source_version="v1",source_workload="productpage-v1"}	0.1234
```

- The remaining two HTTP metrics are `istio_request_bytes` and `istio_response_bytes`. These are also a histograms and can be queried in a similar way to `istio_request_duration_seconds`

#### Default metric internals

If you’re still interested in the internals of how these metrics are configured in Mixer, you can check out the corresponding Istio custom resources in the cluster. If you get the `metric` CRs from the cluster, it lists eight different resources that will be translated to Prometheus metrics:

```
kubectl get metric -n istio-system
NAME                   AGE
requestcount           17h
requestduration        17h
requestsize            17h
responsesize           17h
tcpbytereceived        17h
tcpbytesent            17h
tcpconnectionsclosed   17h
tcpconnectionsopened   17h
```

The `handler` configuration describes the Prometheus metrics and references the previous `metric` custom resources in the `instance_name` fields. It also defines the name that can be used in Prometheus queries later (with the `istio` prefix), like `requests_total`:

```
kubectl get handler -n istio-system prometheus -o yaml
apiVersion: config.istio.io/v1alpha2
kind: handler
metadata:
  ...
spec:
  compiledAdapter: prometheus
  params:
    metrics:
    - instance_name: requestcount.metric.istio-system
      kind: COUNTER
      label_names:
      - reporter
      - source_app
      ...
      name: requests_total
```

The last building block is the `rule` custom resource that binds the metrics to the handlers:

```
kubectl get rule -n istio-system  promhttp -o yaml
apiVersion: config.istio.io/v1alpha2
kind: rule
metadata:
  ...
spec:
  actions:
  - handler: prometheus
    instances:
    - requestcount.metric
    - requestduration.metric
    - requestsize.metric
    - responsesize.metric
  match: (context.protocol == "http" || context.protocol == "grpc") && (match((request.useragent
    | "-"), "kube-probe*") == false)
```

If you still need some custom metrics about network traffic, you’ll need to add custom resources of these types. To do that, you can follow the Istio [documentation](https://istio.io/docs/tasks/telemetry/metrics/collecting-metrics/).

### A MULTI/HYBRID CLOUD MONITORING AND CONTROL PLANE TOOL FOR ISTIO

Istio and its telemetry component can be intimidating at first, especially if there are multiple clusters involved. We deeply care about simplifying service mesh use in multi-cluster environments as we are focused on building a multi- and hybrid-cloud platform at Banzai Cloud. The fruits of our labor are about to be released at KubeCon: a visual tool for monitoring and configuring service mesh activity. We considered using other tools, for example Kiali, but it fell short on multi-cluster support and the ability to specify configuration options through the UI. So we ended up writing our own UI and back-end infrastructure for communicating with the service mesh. This new tool will be released soon at KubeCon and will be available as part of the [Pipeline](https://github.com/banzaicloud/pipeline) platform, so stay tuned!

![img](https://banzaicloud.com/img/blog/istio/uistio.png)

### ABOUT [PIPELINE](https://github.com/banzaicloud/pipeline)

Banzai Cloud’s [Pipeline](https://github.com/banzaicloud/pipeline) provides a platform which allows enterprises to develop, deploy and scale container-based applications. It leverages best-of-breed cloud components, such as Kubernetes, to create a highly productive, yet flexible environment for developers and operations teams alike. Strong security measures—multiple authentication backends, fine-grained authorization, dynamic secret management, automated secure communications between components using TLS, vulnerability scans, static code analysis, CI/CD, etc.—are a *tier zero* feature of the [Pipeline](https://github.com/banzaicloud/pipeline) platform, which we strive to automate and enable for all enterprises.

### ABOUT [BANZAI CLOUD](https://banzaicloud.com/)

[Banzai Cloud](https://banzaicloud.com/) changing how private clouds get built to simplify the development, deployment, and scaling of complex applications, bringing the full power of Kubernetes and Cloud Native technologies to developers and enterprises everywhere.

\#multicloud #hybridcloud #BanzaiCloud

If you are interested in our technology and open source projects, follow us on GitHub, LinkedIn or Twitter: