---
originallink: "https://banzaicloud.com/blog/kafka-on-istio-performance"
author: "Balint Molnar"
date: 2019-08-04T10:42:00+08:00
draft: false
banner: "/img/blog/banners//todo"
translator: "马若飞"
translatorlink: https://github.com/malphi
reviewer:  ["罗广明"]
reviewerlink:  ["https://github.com/GuangmingLuo"]
title: "运行在Istio之上的Apache Kafka —— 基准测试"
description: "todo"
categories: ["Service Mesh"]
tags: ["Service Mesh"]
---

## 编者按

> 本文介绍了基准测试

我们的容器管理平台[Pipeline](https://github.com/banzaicloud/pipeline)以及CNCF认证的Kubernetes发行版[PKE](https://github.com/banzaicloud/pke)的一个关键特性是，它们能够在多云和混合云环境中无缝地构建并运行。虽然[Pipeline](https://github.com/banzaicloud/pipeline)用户的需求因他们采用的是单一云方法还是多云方法而有所不同，但通常基于这些关键特性中的一个或多个：

- [多云应用管理](https://banzaicloud.com/blog/multi-cloud-apps/)
- [一个基于Istio的自动化服务网格，用于多云和混合云部署](https://banzaicloud.com/blog/istio-multicluster-the-easy-way/)
- [基于Kubernetes federation v2（集群联邦）的联合资源和应用部署](https://banzaicloud.com/blog/multi-cloud-fedv2/)

随着采用基于[Istio operator](https://github.com/banzaicloud/istio-operator)的多集群和多混合云的增加，对运行接入到服务网格中的分布式或分散的应用的能力的需求也增加了。我们的客户在Kubernetes上大规模运行的托管应用之一是**Apache Kafka**。我们认为，**在Kubernetes上运行Apache Kafka最简单的方法**是使用Banzai Cloud的[Kafka spotguide](https://banzaicloud.com/tags/kafka)来构建我们的[Kafka operator](https://banzaicloud.com/blog/kafka-operator/)。然而，到目前为止，我们的重点一直是自动化和操作单个集群Kafka部署。

## 太长别看（TLDR）

- 我们已经添加了在Istio上运行Kafka所需的支持 (使用[Kafka](https://github.com/banzaicloud/kafka-operator) 和 [Istio](https://github.com/banzaicloud/istio-operator)操作器，并通过 [Pipeline](https://github.com/banzaicloud/pipeline)编排).
- 在Istio上运行Kafka不会增加性能开销 (不同于典型的mTLS，在SSL/TLS上运行Kafka是一样的)。
- 使用 [Pipeline](https://github.com/banzaicloud/pipeline)，你可以创建跨多云和混合云环境的Kafka集群。

**带有生产者ACK设置为all的3个broker、3个partition和3个replication因子场景的指标预览：**

### 单集群结果

| Kafka cluster               | Google GKE  平均磁盘 IO / broker | Amazon EKS  平均磁盘 IO / broker |
| :-------------------------- | :------------------------------- | :------------------------------- |
| Kafka                       | 417MB/s                          | 439MB/s                          |
| Kafka 启用 SSL/TLS          | 274MB/s                          | 306MB/s                          |
| Kafka 基于 Istio            | 417MB/s                          | 439MB/s                          |
| Kafka 基于 Istio 并开启mTLS | 323MB/s                          | 340MB/s                          |

### 多集群结果

| Kafka 集群基于 Istio 并开启 mTLS | 平均磁盘 IO / broker | 集群间平均延迟 |
| :------------------------------- | :------------------- | :------------- |
| GKE eu-west1 <-> GKE eu-west4    | 211MB/s              | 7 ms           |
| EKS eu-north1 <-> EKS eu-west1   | 85MB/s               | 24 ms          |
| EKS eu-central1 <-> GKE eu-west3 | 115MB/s              | 2 ms           |

如果您想深入研究相关的统计数据，可以在 [这里](https://github.com/banzaicloud/kafka-operator/tree/master/docs/benchmarks)找到所有数据。

## 在Istio服务网格上运行Kafka

Kafka社区对如何利用更多的Istio功能非常感兴趣，例如开箱即用的Tracing，穿过协议过滤器的mTLS等。尽管这些功能有不同的需求，如Envoy、Istio和其他各种GitHub repos和讨论板上所反映的那样。大部分的这些特性已经在我们的[Pipeline platform](https://beta.banzaicloud.io/)的[Kafka spotguide](https://banzaicloud.com/tags/kafka/)中，包括监控、仪表板、安全通信、集中式的日志收集、自动伸缩,Prometheus警报，自动故障恢复等等。我们和客户错过了一个重要的功能：网络故障和多网络拓扑结构的支持。我们之前已经利用[Backyards](https://banzaicloud.com/blog/istio-the- simple -way/)和[Istio operator](https://github.com/banzaicloud/istio-operator)解决过此问题。现在，探索在Istio上运行Kafka的时机已经到来，并在单云多区、多云，特别是混合云环境中自动创建Kafka集群。

![setup](https://banzaicloud.com/img/blog/kafka-perf/kafka-multi-perf.png)

> 让Kafka在Istio上运行并不容易，需要时间以及在Kafka和Istio方面的大量专业知识。经过一番努力和决心，我们完成了要做的事情。然后我们以迭代的方式自动化了整个过程，使其在[Pipeline platform](https://beta.banzaicloud.io/)上运行的尽可能顺利。对于那些想要通读这篇文章并了解问题所在的人——具体的来龙去脉——我们很快将在另一篇文章中进行深入的技术探讨。同时，请随时查看相关的GitHub代码库。

### 认知偏差

*认知偏差是一个概括性术语，指的是信息的上下文和结构影响个人判断和决策的系统方式。影响个体的认知偏差有很多种，但它们的共同特征是，与人类的个性相一致，它们会导致判断和决策偏离理性的客观。*

自从[Istio operator](https://github.com/banzaicloud/istio-operator)发布以来，我们发现自己陷入了一场关于Istio的激烈辩论中。我们已经在Helm(和Helm 3)中目睹了类似的过程，并且很快意识到关于这个主题的许多最激进的观点并不是基于第一手的经验。当我们与对Istio的复杂性有一些疑问的人产生共鸣的时候——这正是我们开源了[Istio operator](https://github.com/banzaicloud/istio-operator)和发布[Backyards](https://banzaicloud.com/blog/istio-multicluster-the-easy-way/)产品背后的根本原因——我们真的不同意大多数性能相关的争论。是的，Istio有很多“方便”的特性你可能需要也可能不需要，其中一些特性可能会带来额外的延迟，但是问题是和往常一样，这样做是否值得?

> 注意：是的，在运行一个包含大量微服务、策略实施和原始遥测数据过程的大型Istio集群时，我们已经看到了Mixer性能下降和其他的问题，对此表示关注；Istio社区正在开发一个`mixerless`版本——其大部分功能会叠加到Envoy上。

### 做到客观，测量先行

在我们就是否向客户发布这些特性达成一致之前，我们决定进行一个性能测试。我们使用了几个在基于Istio服务网格上运行Kafka的测试场景来实现这点。你可能注意到，Kafka是一个数据密集型的应用，因此我们希望通过在依赖和不依赖Istio的两种情况下进行测试，以测量其增加的开销。此外，我们对Istio如何处理数据密集型应用很感兴趣，在这些应用程序中保持I/O吞吐量恒定，让所有组件负荷都达到了最大值。

> 我们使用了新版本的 [Kafka operator](https://github.com/banzaicloud/kafka-operator)，它提供了Istio服务网格的原生支持 (版本 >=0.5.0)。

## 基准测试安装设置

为了验证我们的多云设置，我们决定先用各种Kubernetes集群场景测试Kafka：

- 单机群，3个broker，3个topic分3个partition，复制因子设置为3，**关闭TLS**
- 单机群，3个broker，3个topic分3个partition，复制因子设置为3，**启用TLS**

这些设置对于检查Kafka在选定环境中的实际性能是非常必要的，且没有潜在的Istio开销。

为了对Kafka进行基准测试，我们决定使用两个最流行的云提供商下的Kubernetes解决方案，Amazon EKS和Google GKE。我们希望最小化配置和避免任何潜在的CNI配置不匹配问题，因此决定使用云提供商管理的K8s发行版。

> 在另一篇文章中，我们将发布混合云Kafka集群的基准测试，其中会使用自己的Kubernetes发行版[PKE](https://github.com/banzaicloud/pke)。

我们想要模拟经常在[Pipeline](https://github.com/banzaicloud/pipeline)平台上的一个用例，因此部署了跨可用区的节点，Zookeeper和客户端也位于不同的节点中。

下面是使用到的实例类型：

### AMAZON EKS

| Broker        | Zookeeper    | Client        |
| :------------ | :----------- | :------------ |
| 3x r5.4xlarge | 3x c5.xlarge | 3x c5.2xlarge |

> 仅供参考，Amazon在一天剩下的时间里会在30分钟后对小型实例类型磁盘IO进行节流。你可以从 [这里](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSOptimized.html#ebs-optimization-support)读到更多信息。

对于存储，我们请求了Amazon提供的`IOPS SSD(io1)`，在上面列出的实例中，它可以持续的达到437MB/s吞吐量。

### GOOGLE GKE

| Broker            | Zookeeper        | Client           |
| :---------------- | :--------------- | :--------------- |
| 3x n1-standard-16 | 3x n1-standard-2 | 4x n1-standard-8 |

存储方面，我们设置了Google的`pd-ssd`，根据文档，它可以达到`400MB/s`。

### KAFKA和加载工具

Kafka方面，我们使用了3个topic，partition 数量和 replication 因子都设置为 3。 基于测试的目的我们使用了默认的配置值，除了 `broker.rack,min.insync.replicas`。

在基准测试中，我们使用自定义构建的Kafka Docker映像`banzaicloud/ Kafka:2.12-2.1.1`。它使用Java 11、Debian并包含2.1.1版本的Kafka。Kafka容器配置为使用4个CPU内核和12GB内存, Java的堆大小为10GB。

> banzaicloud/kafka:2.12-2.1.1 镜像是基于 wurstmeister/kafka:2.12-2.1.1 镜像的， 但为了SSL库的性能提升，我们想用 Java 11 代替 Java 8。

加载工具使用 [sangrenel](https://github.com/jamiealquiza/sangrenel)生成，它是一个基于Go语言实现的Kafka性能工具，配置如下：

- 512 字节的消息尺寸
- 不压缩
- required-acks 设置为 all
- worker设置为20个

为了得到准确的结果，我们使用Grafana 仪表板[1860](https://grafana.com/dashboards/1860)的可视化NodeExporter指标监控整个架构。我们不断增加生产者的数量，直到达到架构或Kafka的极限。

> 为基准测试创建的架构已经超出了这篇文章的范围，但是如果你对重现它感兴趣，我们建议使用[Pipeline管道](https://github.com/banzaicloud/pipeline)和访问[Kafka-operator](https://github.com/banzaicloud/kafka-operator/) 的GitHub获取更多细节。

## 基准测试环境

Before getting into Kafka’s benchmark results, we also benchmarked our environments. As Kafka is an extremely data intensive application, we gave special focus to measuring disk speed and network performance; based on our experience, these are the metrics that most affect Kafka. For network performance, we used a tool called `iperf`. Two identical Ubuntu based Pods were created: one, a server, the other, a client.

在讨论Kafka的基准测试结果之前，我们还对环境进行了基准测试。由于Kafka是一个非常数据密集型的应用程序，我们特别关注测量磁盘速度和网络性能;根据我们的经验，这些是对Kafka影响最大的度量标准。为了提高网络性能，我们使用了一个名为“iperf”的工具。创建了两个相同的基于Ubuntu的pod:一个是服务器，另一个是客户机。

- 在 Amazon EKS 上我们测量的结果 `3.01 Gbits/sec` 的吞吐量。
- 在 Google GKE 上我们测量的结果 `7.60 Gbits/sec` 的吞吐量。

为了确定磁盘速度，我们使用了一个叫 `dd`的工具在基于容器的Ubuntu系统下。

- 在Amazon EKS上我们测量的结果是 `437MB/s`  (这与Amazon为该实例和ssd类型提供的内容完全一致)。
- 在Google GKE上我们测量的结果是 `400MB/s` (这也与谷歌为其实例和ssd类型提供的内容一致)。

现在我们对环境有了更好的理解，让我们继续讨论部署到Kubernetes的Kafka集群。

## 单集群

#### Google GKE

#### Kafka 部署在 Kubernetes - 没有Istio

After the results we got on EKS, we were not surprised that Kafka maxed disk throughput and hit `417MB/s` on GKE. That performce was limited by the instance’s disk IO.

在我们得到关于EKS的结果之后，我们对Kafka使磁盘吞吐量达到最大并在GKE上达到“417MB/s”并不感到惊讶。该性能受到实例的磁盘IO的限制。

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-notls-gke.png)

#### Kafka 基于 Kubernetes 开启 TLS - 没有 Istio

Once we switch on SSL/TLS for Kafka, as expected and as has been [benchmarked](https://blog.mimacom.com/apache-kafka-with-ssltls-performance/) many times, a performance loss occured. Java’s well known for the poor performance of its SSL/TLS (otherwise pluggable) implementatation, and for the [performace issues](https://issues.apache.org/jira/browse/KAFKA-2561) it causes in Kafka. However, there have been improvements in recent implementations (9+), accordingly, we upgraded to Java 11. Still, the results were as follows:

一旦我们为Kafka打开SSL/TLS，就像预期的那样，并且已经多次基准测试过(https://blog.mimacom.com/apache-kafka-with-ssltls-performance/)，就会出现性能损失。众所周知，Java的SSL/TLS(否则是可插入的)实现性能很差，而且它在Kafka中导致了[performace issues](https://issues.apache.org/jira/browse/KAFKA-2561)。然而，在最近的实现(9+)中有一些改进，因此，我们升级到了Java 11。尽管如此，结果如下:

- `274MB/s` 吞吐量 大约30% 吞吐量损失
- 和没有TLS比较，包率有大约两倍的提升

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-tls-gke.png)

#### Kafka 基于 Kubernetes - 有 Istio

We were eager to see whether there was any added overhead and performance loss when we deployed and used Kafka in Istio. The results were promising:

我们急切地想知道在Istio中部署和使用Kafka时是否会增加开销和性能损失。结果很有希望:

- 没有性能损失
- CPU方面略有增加

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-notls-gke-istio.png)

#### Kafka 基于 Kubernetes - 有 Istio 并开启 mTLS 

Next we enabled mTLS on Istio and reused the same Kafka deployment. The results are better than they were for the Kafka on Kubernetes with SSL/TLS scenario.

接下来，我们在Istio上启用了mTLS，并重用了相同的Kafka部署。结果比使用SSL/TLS场景的Kubernetes上的Kafka要好。

- `323MB/s` 吞吐量，大约20% 吞吐量损失
- 和没有TLS比较大约2倍的包率提升

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-tls-gke-istio.png)

#### Amazon EKS

#### Kafka 基于 Kubernetes - 没有 Istio

With this setup we achieved a considerble write rate of `439MB/s`, which, if messages are 512 bytes, is `892928 Messages/second`. In point of fact, we maxed out the disk throughput provided by AWS for the `r5.4xlarge` instance type.

通过这个设置，我们实现了一个相当可观的写入速度' 439MB/s '，如果消息是512字节，那么它就是' 892928 messages /second '。事实上，我们最大化了AWS为“r5.4xlarge”实例类型提供的磁盘吞吐量。

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-notls-eks.png)

#### Kafka 基于 Kubernetes 有 TLS - 没有 Istio

Once we switched on SSL/TLS for Kafka, again, as was expected and has been [benchmarked](https://blog.mimacom.com/apache-kafka-with-ssltls-performance/) many times, a performance loss occured. Java’s SSL/TLS implementatation performance issues are just as relevant on EKS as on GKE. However, like we said, there have been improvements in recent implementations. Accordingly, we upgraded to Java 11 but the results were as follows:

一旦我们再次为Kafka打开SSL/TLS，就像预期的那样，并多次进行了[基准测试](https://blog.mimacom.com/apache-kafka-with-ssltls-performance/)，就会出现性能损失。Java的SSL/TLS实现性能问题与ek和GKE一样相关。然而，正如我们所说，最近的实现已经有了改进。因此，我们将其升级到Java 11，但是结果如下：

- `306MB/s` 吞吐量，大约30% 吞吐量损失
- 和没有TLS比较，大约2倍包率提升

![img](https://banzaicloud.com/img/blog/kafka-perf/kakfa-tls-eks.png)

#### Kafka 基于 Kubernetes - 没有 Istio

和以前一样，结果也很好：

- 没有性能损失
- CPU方面有轻微增加

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-notls-eks-istio.png)

#### Kafka on Kubernetes - with Istio and mTLS enabled

Next we enabled mTLS on Istio and reused the same Kafka deployment. The results, again, are better than for Kafka on Kubernetes with SSL/TLS.

接下来，我们在Istio上启用了mTLS，并重用了相同的Kafka部署。同样，结果比Kafka在Kubernetes上使用SSL/TLS要好。

- `340MB/s` 吞吐量，大约20%吞吐量损耗
- 包率增加了，但低于两倍

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-tls-eks-istio.png)

#### Bonus track - Kafka on Linkerd (without mTLS)

We always test all our available options, so we wanted to give this a try with Linkerd. Why? Because we could. While we know that Linkerd can’t meet our customers’ expectations in terms of available features, we still wanted to give it a try. Our expectations were high, but the numbers produced gave us a hard lesson and a helpful reminder in what, exactly, `cognitive bias` is.

我们总是测试所有可用的选项，所以我们想用Linkerd尝试一下。为什么？因为我们可以。虽然我们知道Linkerd在可用特性方面不能满足客户的期望，但我们仍然想尝试一下。我们的期望值很高，但得出的数字给了我们一个沉重的教训，也提醒了我们“认知偏见”到底是什么。

- `246MB/s` 吞吐量

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-linkerd.png)

### SINGLE CLUSTER CONCLUSION

Before we move on to our multi-cluster benchmark, let’s evaluate the numbers we have already. We can tell that, in these environments and scenarios, using service mesh without mTLS does not affect Kafka’s performance. The throughput of the underlying disk limits the performance before Kafka hits network, memory or cpu limits.

在继续我们的多集群基准测试之前，让我们评估一下已有的数据。我们可以看出，在这些环境和场景中，使用没有mTLS的服务网格不会影响Kafka的性能。底层磁盘的吞吐量限制了Kafka到达网络、内存或cpu限制之前的性能。

Using TLS creates a ~20% throughput degradation in Kafka’s performance, whether using Istio or Kafka’s own SSL/TLS lib. It slightly increases the CPU load and roughly doubles the number of packets transmitted over the network.

无论是使用Istio还是Kafka自己的SSL/TLS库，使用TLS都会使Kafka的性能降低约20%。

> Note that just enabling the mTLS on the network caused a ~20% degredation during the infrastructure test with `iperf` as well
>
> 注意，在使用“iperf”进行基础设施测试期间，仅在网络上启用mTLS就会导致大约20%的递减

## Multi-cluster scenario with topics replicated across “racks” (cloud regions)

In this setup we are emulating something closer to production, wherein, for the sake of reusing environmental benchmarks, we stick with the same AWS or Google instances types, but set up multiple clusters on different regions (with topics replicated across cloud regions). Note that the process should be the same, whether we use these multiple clusters across a single cloud provider or across multiple or hybrid clouds. From the perspective of [Backyards](https://banzaicloud.com/blog/istio-multicluster-the-easy-way/) and the [Istio operator](https://github.com/banzaicloud/istio-operator) there is no difference; we support 3 different network topologies.

在这个设置中，我们模拟的内容更接近于生产环境，为了重用环境基准，我们坚持使用相同的AWS或谷歌实例类型，但是在不同的区域上设置多个集群(跨云区域复制主题)。请注意，无论我们跨单个云提供者使用这些多个集群，还是跨多个云或混合云使用这些集群，流程都应该是相同的。从[backyard](https://banzaicloud.com/blog/istio- multicluster-theeasy -way/)和[Istio operator](https://github.com/banzaicloud/istio-operator)的角度来看，没有区别;我们支持3种不同的网络拓扑。

One of the clusters is larger than the other, as it consists of 2 brokers and 2 Zookeeper nodes, whereas the other will have one of each. Note, in a **single mesh multi-cluster**environment enabling mTLS is an absolute must. Also, we set `min.insync.replicas` to 3 again and the producer ACK requirement to all for durability.

其中一个集群比另一个集群更大，因为它包含两个代理和两个Zookeeper节点，而另一个集群将包含其中一个节点。注意，在支持mTLS的**单网格多集群环境中是绝对必须的。此外，我们还设置了' min.insync '。复制到3和生产者ACK要求所有的持久性。

The mesh is automated and provided by the [Istio operator](https://github.com/banzaicloud/istio-operator).

#### Google GKE <-> GKE

In this scenario we created a single mesh/single Kakfa cluster that spanned two Google Cloud regions: eu-west1 and eu-west4

在这个场景中，我们创建了一个网格/单个Kakfa集群，它跨越两个谷歌云区域:eu-west1和eu-west4

- `211MB/s` throughput

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-multi-gke.png)

#### Amazon EKS <-> EKS

In this scenario we created a single mesh/single Kakfa cluster that spanned two AWS regions: eu-north1 and eu-west1

在这个场景中，我们创建了一个网格/单个Kakfa集群，它横跨两个AWS区域:eu-north1和eu-west1

- `85MB/s` throughput

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-multi-eks.png)

#### Google GKE <-> EKS

In this scenario we created a single Istio mesh, across multiple clusters that spanned multiple clouds, forming one single Kafka cluster (Google Cloud region is europe-west-3 and AWS region is eu-central-1). As expected, the results were considerably poorer.

在这个场景中，我们创建了一个单一的Istio网格，它跨越多个跨越多个云的集群，形成了一个单一的Kafka集群(谷歌云区域是europe-west-3, AWS区域是eu-central-1)。正如预期的那样，结果要差得多。

- `115MB/s` throughput

![img](https://banzaicloud.com/img/blog/kafka-perf/kafka-multi-eks-gke.png)

### 多集群结论

From our benchmarks, we can safely say that it’s worth it to give using Kafka in a multi-cloud single-mesh environment a shot. People have different reasons for choosing an environment like Kafka over Istio, but the ease of setup with [Pipeline](https://github.com/banzaicloud/pipeline), the additional security benefits, scalability and durability, [locality based load balancing](https://banzaicloud.com/blog/istio-operator-1.2/) and lots more makes it a perfect choice.

从我们的基准测试中，我们可以放心地说，在多云单网格环境中使用Kafka是值得的。的人有不同的原因选择一个环境就像卡夫卡Istio,但易于设置(管道)(https://github.com/banzaicloud/pipeline),额外的安全利益,可伸缩性和耐用性,(基于本地负载均衡)(https://banzaicloud.com/blog/istio -运营商- 1.2 /)和更多的是一个完美的选择。

As already mentioned, one of the next posts in this series will be be about benchmarking/operating an autoscaling hybrid-cloud Kafka cluster, wherein alerts and scaling events are based on Prometheus metrics (we do something similar for autoscaling based on Istio metrics for multiple applications, which we deploy and observe through the mesh - read this older post for details: [Horizontal Pod Autoscaling based on custom Istio metrics](https://banzaicloud.com/blog/k8s-hpa-prom-istio/).)

正如前面提到的,本系列的下一文章之一将是基准测试/操作自动定量混合云卡夫卡集群,在警报和缩放事件是基于普罗米修斯指标(我们做类似的基于Istio的自动定量指标用于多个应用程序,我们通过网格部署和观察——读这老帖子详情:(水平基于定制Istio吊舱自动定量指标)(https://banzaicloud.com/blog/k8s-hpa-prom-istio/)。)

## 关于 [Backyards](https://banzaicloud.com/blog/istio-the-easy-way/)

Banzai Cloud’s Backyards is a multi and hybrid-cloud enabled service mesh platform for constructing modern applications. Built on Kubernetes, our [Istio operator](https://github.com/banzaicloud/istio-operator) and [Pipeline](https://github.com/banzaicloud/pipeline)platform enable flexibility, portability and consistency across on-premise datacenters and on **five** cloud environments. Use our simple, yet extremely powerful, UI and CLI, and experience automated canary releases, traffic shifting, routing, secure service communication, in-depth observability and more, for yourself.

板载云的后院是一个多和混合云支持的服务网格平台，用于构建现代应用程序。基于Kubernetes，我们的[Istio操作符](https://github.com/banzaicloud/istio-operator)和[Pipeline](https://github.com/banzaicloud/pipeline)平台支持跨内部数据中心和** 5 **云环境的灵活性、可移植性和一致性。使用我们简单但功能极其强大的UI和CLI，体验自动canary发布、流量转移、路由、安全服务通信、深度可观察性等等。

## 关于 [Pipeline](https://github.com/banzaicloud/pipeline)

Banzai Cloud’s [Pipeline](https://github.com/banzaicloud/pipeline) provides a platform which allows enterprises to develop, deploy and scale container-based applications. It leverages best-of-breed cloud components, such as Kubernetes, to create a highly productive, yet flexible environment for developers and operations teams alike. Strong security measures—multiple authentication backends, fine-grained authorization, dynamic secret management, automated secure communications between components using TLS, vulnerability scans, static code analysis, CI/CD, etc.—are a *tier zero* feature of the [Pipeline](https://github.com/banzaicloud/pipeline) platform, which we strive to automate and enable for all enterprises.

提供一个平台，允许企业开发、部署和扩展基于容器的应用程序。它利用了最好的云组件，比如Kubernetes，为开发人员和运营团队创建了一个高效、灵活的环境。强大的安全measures-multiple认证后端,细粒度的授权、动态秘密管理、自动化组件之间的安全通信使用TLS,漏洞扫描、静态代码分析,CI / CD,如一个零* *层特性(管道)(https://github.com/banzaicloud/pipeline)的平台,我们努力实现自动化,使所有企业。

## 关于 [Banzai Cloud](https://banzaicloud.com/)

[Banzai Cloud](https://banzaicloud.com/) is changing how private clouds are built: simplifying the development, deployment, and scaling of complex applications, and putting the power of Kubernetes and Cloud Native technologies in the hands of developers and enterprises, everywhere.

正在改变私有云的构建方式:简化复杂应用程序的开发、部署和扩展，并将Kubernetes和云原生技术的强大功能交到各地的开发人员和企业手中。