---
title: "迈向极简主义 - Istio 1.6 发布"
author: "马若飞"
authorlink: "https://github.com/malphi"
date: 2020-05-27T10:30:10+08:00
draft: false
banner: "/img/blog/banners/00704eQkly1fugaipib9ij31ji15okjn.jpg"
summary:  "Istio 1.6 如期发布。让我们从不同的视角来解读一下这一版本的特性。"
tags: ["istio"]
categories: ["istio"]
keywords: ["istio"]
---

内容摘要：从 1.2 版本开始，Istio 进入季度发布的状态。5 月 21 日发布的 1.6 版本可以说是最准时的一次。我们是否可以理解 Istio 架构简化后的开发工作已经步入了正轨？这次的更新是否会带给我们惊喜？亦或是还有遗憾？让我们一一道来。

## 加法和减法

Istio 1.6 的 Release note 开篇的标题用三个巨大的 `Simplify`  来表明态度：我们要把极简主义进行到底！其中最大的简化就是将原有组件的功能完全整合入 **Istiod** ，完成了悟天克斯们的合体过程，让 Istiod 更加完整，也彻底移除了Citadel、Sidecar Injector 和 Galley。当然，你也可以理解为，这其实是对 1.5 版本未完成工作的收尾。

![istiod](https://tva1.sinaimg.cn/large/007S8ZIlly1gf7yvospzgj30bk0dwgmj.jpg)

（图片引自鸟山明漫画《龙珠Z》）

第二项简化工作是用添加 `istioctl install` 的方式替代 `manifest apply` 的安装过程，用更直观、更精简的命令改善安装过程的体验。当然，`manifest` 子命令依然保留，你还是可以通过清单方式进行部署。在 Change Notes 的三十多项更新中，有七个是`removed`，基本上都和安装有关，比如移除已经废弃的 Helm charts、`istio-pilot`的配置等。可以看出，Istio 团队在极力的通过优化安装流程和部署形态来提升用户的体验。了解游戏行业的人都知道，有一个很重要的指标是留存率，安装过程导致的用户流失是非常不值得的，需要花大力气进行流程的优化和调整。毕竟，第一印象的重要性毋庸置疑，以一个干练清爽的年轻人形象去相亲，还是扮演一个拖泥带水的油腻大叔，成功率高下立判。看来 Istio 团队终于醍醐灌顶，要努力做一个干练的奶油小生了。

我们再来说说加法。Change Note 中的新增项主要来自与三方面：虚拟机的支持，遥测（Telemetry）的改进，升级，`istioctl` 命令行。

Istio 通过添加了一个叫 `WorkloadEntry`  的自定义资源完成了对虚拟机的支持。它可以将非 Kubernetes 的工作负载添加到网格中，这使得你有能力为 VM 定义和 Pod 同级的 Service。而在以前，你不得不通过 ServiceEntry 里的 address 等字段，以曲线救国的方式去实现对非 Pod 工作负载的支持，丑陋又低效。`WorkloadEntry` 的引入让混合云接入网格成为现实。

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: WorkloadEntry
metadata:
  name: details-svc
spec:
  serviceAccount: details-legacy
  address: vm1.vpc01.corp.net
  labels:
    app: details-legacy
    instance-id: vm1
```

遥测方面，增加了两个实验性的功能，一个是请求类别过滤器，主要用来对不同 API 方法的请求进行标记和分类；另一个是追踪配置API，可以控制采用率等。除此之前，添加了 Prometheus 标准的抓取标注（annotation），提升了集成的体验。Grafana 的 Dashboard 也有[更新](https://grafana.com/orgs/istio)，对终端用户来说这倒是可以期待一下。然并卵，我们最关心的 WASM 只字未提！笔者猜测它在可用性方面还有很多问题。我们社区成员对 Istio 各个版本的遥测做了 benchmark，横向对比的结果是 WASM 方式下性能垫底！甚至还不如 1.3 版本。这让人不禁感慨，WASM 之于 Envoy，会不会只是一次看上去很美好的邂逅呢？

![envoy-wasm](https://tva1.sinaimg.cn/large/007S8ZIlly1gf7yi1l3vij30rs0caab0.jpg)

（图片引自吉米漫画《向左走向右走》）

为了能平滑的升级，Istio 提供了一种叫金丝雀升级（Canary upgrades）的策略，可以安装一个金丝雀版本的控制平面与老版本同时存在。金丝雀升级可以让你逐渐的切换流量以验证新版本的可用性，同时也保留了回滚的可能性。当然，如果你足够自信，依然可以原地升级（In place upgrade)。

```bash
$ istioctl install --set revision=canary
$ kubectl get pods -n istio-system
NAME                                    READY   STATUS    RESTARTS   AGE
istiod-786779888b-p9s5n                 1/1     Running   0          114m
istiod-canary-6956db645c-vwhsk          1/1     Running   0          1m
```

令笔者惊奇的是，Istio 居然提供了降级（Downgrade）功能！这是因为开发团队对新版本不自信吗？如果说金丝雀升级已经提供了回滚的能力，那又何必为原地升级提供降级能力呢？而且降级也是有限制条件的：必须是 1.5 以上的版本；必须是使用 `istioctl`安装的；必须使用老版本的 `istioctl` 执行降级操作。笔者很难想象出它的适用场景，如果你知道，请一定告知。

## 向市场妥协

在虚拟机支持方面，Release Note 中有这样一句话：

> Expanding our support for workloads not running in Kubernetes was one of the our major areas of investment for 2020

Istio 为什么要花大力气支持 VM 这种即将过气的部署载体？而且要作为 2020 年开发的重中之重？在理解这一举措之前，让我们先来看看 Google 的老对手 Amazon，在自家产品 AWS App Mesh 上的布局。

从下图可以看出，AWS App Mesh 支持了自家的各种工作负载，当然也包括虚拟机和实体机。Amazon CTO Werner Vogers 在[使用 AWS App Mesh 重新定义服务通信](https://www.allthingsdistributed.com/2019/03/redefining-application-communications-with-aws-app-mesh.html) 一文中写到：

> Our goal is to remove the undifferentiated heavy lifting of operating complex applications. We provide the tools, services, and observability to ensure that you can maintain high standards for your own architectures.

这种全方位部署形态的支持，其主要目的就是消除不同，给用户统一的接入体验。而这种不得已为之的策略，其实本质上是云原生应用落地的现状造成的。如果你多了解下身边不同公司在这方面的实践，你就会发现现实远比我们想象的要骨感的多。大量的中小企业都刚刚把上云提上日程，还有很多是实体机 / VM 和部分迁移到云的业务组成的混合体，其部署形态的复杂性可想而知。而 App Mesh 这种远瞻性的策略就是通过覆盖用户现有的各种部署形态，提前将未来全面上云的市场揽入怀中。当你的 Mesh 接入层无需变更时，只需要将VM之类的负载一一替换即可，最终完成云上的纯粹形态。

![appmesh](https://tva1.sinaimg.cn/large/007S8ZIlly1gf804aiie4j30oz0dntaj.jpg)

我们再来看看 Istio 的同门师弟，gcloud Traffic Director 的情况。



上云现状的考量；

蚕食竞争对手的市场；

回归平台中立的理念；

Vm

k8s

preview

## 生态圈的重要性

portal

hub

## 期待和无奈

WASM只字未提
