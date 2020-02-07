---
originallink: "https://blog.christianposta.com/microservices/do-i-need-an-api-gateway-if-i-have-a-service-mesh/"
author: "Christian Posta"
date: "2020-02-06T10:42:00+08:00"
draft: false
banner: "/img/blog/banners/006tKfTcly1g1g1acjx5aj30rr0kukjl.jpg"
translator: "马若飞"
translatorlink: "https://github.com/malphi"
reviewer:  ["罗广明"]
reviewerlink:  ["https://github.com/GuangmingLuo"]
title: "使用了Service Mesh后我还需要API网关吗"
summary: "网关"
categories: ["service mesh"]
tags: ["service mesh"]
---

## 编者按

## 前言

This post may not be able to break through the noise around API Gateways and Service Mesh. However, it’s 2020 and there is still abundant confusion around these topics. I have chosen to write this to help bring real concrete explanation to help clarify differences, overlap, and when to use which. Feel free to [@ me on twitter (@christianposta)](http://twitter.com/christianposta?lang=en) if you feel I’m adding to the confusion, disagree, or wish to buy me a beer (and these are not mutually exclusive reasons).

这篇文章可能无法打破缠绕在API网关和服务网格周围的喧嚣。即便是是2020年了，相关的话题仍然存在大量疑虑。我撰写此文是为了给出真实而具体的解释，以帮助理清它们之间的差异、重叠以及适用场景。如果你不同意觉得我在添乱，或者想请我喝杯啤酒，欢迎随时在Twitter上@我(@christianposta)。

> **First disclosure:** [I work](https://www.solo.io/company/about-us/]) for a company, [Solo.io](https://solo.io/), that is invested in this topic. I mention this ahead of the “your view is biased” reaction. Everyone’s view is biased. But to be sure, I came to work at Solo.io **because** I want to see these thoughts implemented and brought to market, not the other way around.
>
> **第一个曝光：** 我在[Solo.io](https://solo.io/)这家公司工作，公司业务聚焦于今天我们要讨论的主题。我在出现“你的观点是有偏见的”之前提及这一点。每个人的观点都有偏见。但可以肯定的是，我在Solo.io工作是因为我想看到这些想法被付诸实施并推向市场，而不是与之相反。

> **Second disclosure**: I’m writing [a book called “Istio in Action”](https://www.manning.com/books/istio-in-action) which is the service mesh with which I’ve spent the most time. The point of view in this article when I discuss “service mesh” is admittedly from an Istio perspective, but I’ll try point out when I refer to service mesh more generically.
>
> **第二个曝光：**我正在写一本有关服务网格的名为《Istio in Action》的书，这花了我很多时间。在本文中，不可否认我是站在Istio的角度来讨论“服务网格”的，但如果我指的是更普遍的服务网格的概念时，我会指出这点。

## 为什么会有另一个关于此话题的博客？

There’s a trove of information on this topic. We’ve seen [“API Gateway is for north/south traffic while service mesh is for east/west”](https://aspenmesh.io/api-gateway-vs-service-mesh/). Some have written about [“API Gateways as managing business functionality, while service mesh for service-to-service communication”](https://medium.com/microservices-in-practice/service-mesh-vs-api-gateway-a6d814b9bf56). Others have pointed out [specific functionality that an API Gateway does that service mesh doesn’t](https://blog.getambassador.io/api-gateway-vs-service-mesh-104c01fa4784) some of which may no longer be the case. On the other hand, some [get closer to the way I think about them](https://developer.ibm.com/apiconnect/2018/11/13/service-mesh-vs-api-management/).

有大量关于当前主题的文章。我们看过[“API网关用于南北流量，而服务网格用于东西流量”](https://aspenmesh.io/api-gateway-vs-service-mesh/)。还有人写了[“API网关用于管理业务功能，而服务网格用于服务到服务通信”](https://medium.com/microservices-in-practice/service-mesh-vs-api-gateway-a6d814b9bf56)。[API网关具有服务网格不具备的特定功能](https://blog.getambassador.io/api-gateway-vs-service-mesh-104c01fa4784)，其中一些可能不再适用。另一方面，有些人[更接近我的思考方式](https://developer.ibm.com/apiconnect/2018/11/13/service-mesh-vs-api-management/)。

然而，市场中仍存在明显的困惑。

> I also would like to see serious discussion about how people see the trade offs between different approaches. For example, there is overlap in responsibility/advocacy between a service meshes and api gateways. People are confused and overwhelmed with choices.
> 我也希望看到关于人们如何看待不同方法之间权衡的严肃讨论。例如，服务网格和api网关之间的职责/主张存在重叠。人们对选择感到困惑和不知所措。
>
> — Andrew Clay Shafer 雷启理 (@littleidea)
>
>  
>
> June 12, 2019

## 困惑是什么

About a year ago I wrote [about the Identity Crisis of the API Gateway](https://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/) which evaluated the differences in API Management, Kubernetes Ingresses, and API Gateways (with associated definitions). At the end of that article, I tried to explain how service mesh fits into the equation, but without enough detail on how they’re different or when to use one or the other. I highly recommend [reading that post](https://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/) as in some ways, that’s the “part one” to this post being a “part two”.

大约一年前，我写了一篇[关于API网关身份危机](https://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/)的文章，评估了API管理、Kubernetes Ingress和API网关(带有相关定义)的差异。在那篇文章的最后，我试图解释服务网格是如何应对这些功能的，但是没有详细说明它们如何不同，以及什么时候使用它们。我强烈推荐[阅读这篇文章](https://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/) ，因为在某些方面，它是“第一部分”，本文作为“第二部分”。

我认为产生混淆的原因如下：

- 技术使用上存在重叠（代理）
- 功能上存在重叠（流量控制，路由，指标收集，安全/策略增强等）
- “服务网格”可替代API管理的理念
- 服务网格能力的误解
- 一些服务网格有自己的网关

最后一点尤其使人困惑。

If service mesh is just for east-west traffic (within a boundary), then why do some service meshes, say Istio, [have an Ingress Gateway](https://istio.io/docs/reference/config/networking/gateway/) for north/south (and is part of the mesh)? For example, from the Istio Ingress Gateway docs:

如果服务网格仅仅是针对东西流量（边界内），那么为什么有一些服务网格，如Istio所说，[有一个Ingress网关](https://istio.io/docs/reference/config/networking/gateway/)针对南北流量（并且是网格的一部分）？例如下面来自Istio Ingress网关的文档： 

> Gateway describes a load balancer operating at the edge of the mesh receiving incoming or outgoing HTTP/TCP connections.
> 网关描述了一个运行在网格边缘的负载均衡器，它接收传入或传出的HTTP/TCP连接。

Aren’t our API’s HTTP? If we can get HTTP requests into the cluster/mesh with Istio’s Gateway (which, btw is built on the amazing [Envoy Proxy](https://www.envoyproxy.io/) project), isn’t that sufficient?
我们的API不是HTTP吗?如果我们通过Istio的网关将HTTP请求引入集群/网格中（(顺便说一句，这基于强大的[Envoy 代理](https://www.envoyproxy.io/) 项目），这还不够吗?

## 假设

The rest of this article will assume Istio and Istio’s Gateway when we say “service mesh”. I’m picking this scenario because it’s the one that best illustrates the overlap and confusion. Other service meshes [also have a Gateway](https://www.consul.io/docs/connect/mesh_gateway.html), while some [don’t have an explicit gateway](https://linkerd.io/2/tasks/using-ingress/) yet. YMMV.

当我们说“服务网格”时，本文的其余部分将假定是指Istio和Istio的网关。选择这个场景是因为它最能说明重叠和混淆。其他服务网格[也有网关](https://www.consul.io/docs/connect/mesh_gateway.html)，而有些还[没有显式网关](https://linkerd.io/2/tasks/using-ingress/) 。

## 它们的重合点在哪里

The first order of business is to recognize the areas where the capabilities of an API Gateway and a service mesh seem to overlap. Both handle application traffic, so overlap should not be surprising. The following listing enumerates some of the overlapping capabilities:

业务的第一个步骤是识别API网关和服务网格功能似乎重叠的区域。两者都处理应用程序流量，所以重叠应该不足为奇。下面的清单列举了一些重叠的功能:

- 遥测数据收集
- 分布式追踪
- 服务发现
- 负载均衡
- TLS 终止/开始
- JWT 校验
- 请求路由
- 流量切分
- 金丝雀发布
- 流量镜像
- 速率控制

好吧，它们确实有重叠。那么你需要一个？还是两个？还是都不需要？

## 它们的分叉点在哪里

The service mesh operates at a lower level than the API Gateway and on all of the individual services within the architecture. The service mesh gives “more detail” to service clients about the topology of the architecture (client-side load balancing, service discovery, request routing), the resilience mechanisms they should implement (timeouts, retries, circuit breaking), telemetry they should collect (metrics, tracing), and security flows they participate (mTLS, RBAC). All of these implementation details are provided to applications typically by some sidecar process (think [Envoy](https://www.envoyproxy.io/)), though they don’t have to. See my talk on the [evolution of the service-mesh data plane](https://www.slideshare.net/ceposta/the-truth-about-the-service-mesh-data-plane) from ServiceMeshCon.

服务网格运行在比API网关更低的级别，并在架构中的所有单个服务上运行。服务网格为服务客户提供关于架构拓扑的“更多细节”（包括客户端负载均衡、服务发现、请求路由），应该实现的弹性机制（超时、重试、熔断），应该收集的遥测（度量、跟踪）和参与的安全流（mTLS、RBAC）。所有这些实现细节通常由某个sidecar（请考虑[Envoy](https://www.envoyproxy.io/)）提供给应用程序，但它们不必这样做。请参阅我关于ServiceMeshCon的服务网格数据平面演化的演讲。

下面的话引自 [API 身份危机](https://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/)：

> The goal of the service mesh is to solve these problems [those listed above] generically for any service/application by doing so transparently at L7. In other words, the service mesh wishes to blend into the service (without actually being coded into the service’s code).
>
> 服务网格的目标是通过在L7上透明地操作来解决任何服务/应用程序的这些列举的问题。换句话说，服务网格希望混合到服务中(而不是到服务中编写代码)。

**Bottom line**: service mesh gives more details/fidelity to the services/clients about the implementation of the rest of architecture.

**结论：**服务网格为服务/客户提供了更多关于架构其余部分实现的细节/保真度。

![img](https://blog.christianposta.com/images/mesh-details.png)

The API Gateway on the other hand serves a different role: “abstract away details” and decouple implementations. The API gateway provides a cohesive abstraction across all of the services in an application architecture – as a whole, while solving some of the edge/boundary problems on behalf of specific APIs.

另一方面，API网关则扮演着不同的角色：“抽象细节”和解耦实现。API网关提供了跨应用程序架构中所有服务的内聚抽象——作为一个整体，为特定的API解决了一些边缘/边界问题。

![img](https://blog.christianposta.com/images/abstract-api.png)

API gateways live *above* the applications/services regardless of whether a service mesh exists and provides an abstraction to other groups. They do things like aggregate APIs, abstract APIs and expose them differently than they’re implemented, and add more sophisticated zero-trust security policies at the edge based on the user. The *issues at the boundary of an application architecture* are not the same as those within the boundary.

无论服务网格是否存在，API网关都存在于应用程序/服务之上，并为其他部分提供抽象。它们做的事情包括聚合API、抽象API和用不同的实现方式暴露它们，并基于用户在边缘添加更复杂的零信任安全策略。应用程序架构边界上的问题与边界内的问题不同。

![img](https://blog.christianposta.com/images/infra-layers.png)

## 作为服务到服务挑战的边界问题是不一样的

At the boundary of a microservices/cloud-native architecture, an API Gateway provides three main capabilities that a service mesh does not solve to the same degree:

在微服务/云原生架构的边界上，API网关提供了服务网格无法在同等程度上解决的三个主要能力：

- 边界解耦
- 严格控制数据的进出
- 桥接安全信任域

让我们看看：

### 边界解耦

A core functionality of the API Gateway is to provide a stable API interface to clients outside of the boundary. From [Chris Richardson’s Microservices Patterns Book](https://microservices.io/book), we could paraphrase the “API Gateway pattern” as:

API网关的核心功能是为边界外的客户端提供稳定的API接口。从[Chris Richardson的微服务模式一书](https://microservices.io/book)中，我们可以将“API网关模式”改写为:

> explicitly simplifying the calling of a group of APIs/microservices
> 显式地简化一组APIi /微服务的调用

> emulate a cohesive API for an “application” for a specific set of users, clients, or consumers.
>
> 为一组特定的用户、客户或消费者模拟“应用程序”的内聚API。

> The key here is the API gateway, when it’s implemented, becomes the API for clients as a single entry point to the application architecture
>
> 这里的关键是API网关，当它实现时，它将成为客户机的API，作为应用程序体系结构的单一入口点

来自 [API 网关身份危机](https://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/) 一文中API网关的实现案例：

- [Solo.io Gloo](https://gloo.solo.io/)
- [Spring Cloud Gateway](http://spring.io/projects/spring-cloud-gateway)
- [Netflix Zuul](https://github.com/Netflix/zuul)
- [IBM-Strongloop Loopback/Microgateway](https://strongloop.com/)

From a functionality standpoint, what would an API Gateway need to support? And what real-life usecases do enterprises see that would require an API Gateway [where a service mesh isn’t well suited]:

从功能的角度来看，API网关需要支持什么?企业在现实的用例中会看到哪些需要API网关(服务网格不太适合)的情况:

- 请求/响应转换
- 应用协议转换如 REST/SOAP/XSLT
- 错误/速率定制响应
- 直接响应
- 对API/代理管道的精确控制
- API 聚合/分组

让我们挨个来看。

#### 请求/响应传输

As part of exposing an API on an API gateway, you may wish to hide the details of how the backend API is implemented. This could be some combination of changing the shape of the request, removing/adding headers, placing headers into the body or vice versa. This provides a nice decoupling point from clients when backend services are making changes to the API or when clients cannot update as fast as the provider.

作为在API网关上暴露API的一部分，您可能希望隐藏后端API实现方式的细节。这可能是改变请求内容、删除/添加标头、将标头放入正文的一些组合，反之亦然。当后端服务对API进行更改时，或者当客户端不能像提供方那样快速更新时，这提供了一个与客户端很好的解耦点。

#### 应用协议转换

Many enterprises have investments into technology like XML over HTTP, SOAP, or JSON over HTTP. They may wish to expose these with a tighter, client-specific API and continue to have interoperability. Additionally, service providers may wish to take advantage of new RPC mechanisms like gRPC or streaming protocols like rSocket.

许多企业在技术上进行了投资，如基于HTTP、SOAP的XML，或基于HTTP的JSON。他们可能希望使用更严格的、特定于客户端的API来公开这些API，并继续保持互操作性。此外，服务提供者可能希望利用新的RPC机制(如gRPC)或流协议(如rSocket)。

#### 错误/速率定制响应

Transforming requests from upstream services is a vital capability of an API Gateway, but so too is customizing responses coming from the gateway itself. Clients that adopt the API Gateway’s virtual API for request/response/error handling expect the gateway to customize its responses to fit that model as well.

转换来自上游服务的请求是API网关的一项重要功能，定制来自网关本身的响应也是如此。采用API网关的虚拟API进行请求/响应/错误处理的客户端也希望网关自定义其响应以适应该模型。

#### 直接响应

When a client (trusted or nefarious) requests a resource that is not available, or is blocked from going upstream for some reason, it’s best to be able to terminate proxying and respond with a pre-canned response.

当客户端(受信任的或恶意的)请求不可用的资源，或由于某种原因被阻止上行时，最好能够终止代理并使用预先屏蔽的响应返回。

#### 对API/代理管道的精确控制

There is no one-size fits all proxying expectation. An API Gateway should have the ability to both change the order in which its capabilities get applied (rate limiting, authz/n, routing, transformation, etc) as well as offer a way to debug when things go wrong.

没有一种方法可以满足所有代理的期望。API网关应该能够改变应用其功能的顺序(速率限制、authz/n、路由、转换等)，并在出现问题时提供一种调试方法。

#### API 聚合

Exposing an abstraction over multiple services often comes with the expectation of mashing up multiple APIs into a single API. Something like GraphQL could fit this bill.

As you can see, providing a powerful decoupling point between clients and provider services involves more than just allowing HTTP traffic into the cluster.

在多个服务上公开一个抽象常常伴随着将多个API混合成一个API的期望。类似于GraphQL的东西可以满足这个需求。

正如您所看到的，在客户端和提供服务者之间提供一个强大的解耦点涉及的不仅仅是允许HTTP通信进入集群。

## 严格控制什么可以进入/离开服务

Another important functionality of an API Gateway is that of “governing” what data/requests are allowed into the application architecture and which data/responses are allowed out. This means, the gateway will need deep understanding of the requests coming into the architecture or those requests coming out. For example, a common scenario is Web Application firewalling to prevent SQL injection attacks. Another is “data loss prevention” techniques to prevent SSN or PII to be returned in requests for PCI-DSS/HIPPA/GDPR. The edge is a natural place to help implement these policies.

Again, defining and enforcing these capabilities aren’t as simple as just allowing HTTP traffic into a cluster.

API网关的另一个重要功能是“控制”哪些数据/请求被允许进入应用架构，哪些数据/响应允许流出。这意味着，网关需要对进入或发出的请求有深入的理解。例如，一个常见的场景是Web应用程序防火墙以防止SQL注入攻击。另一种是“数据丢失预防”技术，用于在请求PCI-DSS/HIPPA/GDPR时阻止SSN或PII被返回。边界是帮助实现这些策略的天然位置。

同样，定义和实施这些功能并不像允许HTTP通信流进入集群那么简单。

## 定制安全/桥接信任域

The last major piece of functionality that an API Gateway provides is edge security. This involves challenging users and services that exist outside of the application architecture to provide identity and scope policies so that access to specific services and business functionality can be restricted. This ties into the previous section.

API网关提供的最后一个主要功能是边缘安全性。这涉及到向存在于应用程序体系结构之外的用户和服务提供身份和范围策略，从而限制对特定服务和业务功能的访问。这与前面的部分相关。

A common example is to be able to tie into OAuth/SSO flows including Open ID Connect. The challenge with these “standards” is that they may not be fully implemented or implemented incorrectly. The API Gateway needs a way to flexibly fit into these environments *as well as provide customization*.

一个常见的例子是能够绑定到OAuth/SSO流，包括Open ID Connect。这些“标准”的挑战在于，它们可能没有得到充分实施，也可能没有得到正确实施。API网关需要一种方法来灵活地适应这些环境*以及提供定制*。

In many enterprises there are already existing identity/trust/auth mechanisms and a big part of the API Gateway is to be able to integrate natively for backward compatibility. Although new standards like [SPIFEE](https://spiffe.io/) have emerged, it will take a while for enterprises to adopt and in the meantime an API Gateway (even one for applications running on their next-generation architecture) is a hard requirement. Again, you can kind of squint and say this is also related to the transformation/decoupling point made above.

在许多企业中，已经存在身份/信任/认证机制，API网关的很大一部分是为了向后兼容而进行本地集成。虽然出现了[SPIFEE](https://spiffe.io/)这样的新标准，但企业需要一段时间才能落地，与此同时，API网关（甚至是针对在其下一代架构上运行的应用程序的网关）是一个艰难的要求。同样，你可以检视并说这也和上面提到的变换/解耦点有关。

## 怎样落地其中一个/另一个/两者/两者都不？

In a previous blog I outlined some of the [challenges of adopting this type of technology (API Gateways and Service Mesh)](https://blog.christianposta.com/challenges-of-adopting-service-mesh-in-enterprise-organizations/) and gave some tips on how best to adopt.

在之前的一篇博客中，我概述了一些[采用这种技术的挑战(API网关和服务网格)](https://blog.christianposta.com/challenges-of-adopting-service-mesh-in-enterprise-organizations/)，并给出了关于如何最好地应用这种技术的提示。

Re-iterating here: Start with the edge. It’s a familiar part of the architecture. Picking one that best fits is also something to consider. Assumptions have changed since we’ve introduced cloud infrastructure and cloud-native application architectures. For example, if you’re going to adopt Kubernetes, I would highly recommend considering application networking technology built from the ground up to live in that world (ie, check out [Envoy Proxy](https://www.envoyproxy.io/) vs something that’s been lifted and shifted. For example, at [Solo.io](https://www.solo.io/), we’ve built an open-source project leveraging Envoy called Gloo for this purpose.

重申一下：从边缘开始。这是架构中熟悉的一部分。选择一个最合适的也是要考虑的。自从我们引入了云基础设施和云原生应用架构以来，假设已经发生了变化。例如，如果您打算采用Kubernetes，我强烈建议您考虑使用从头开始构建的应用程序网络技术(例如，检查[Envoy Proxy](https://www.envoyproxy.io/)和已经被提升和转移的应用程序网络技术)。例如，在[Solo.io](https://www.solo.io/)，我们已经为此目的建立了一个名为Gloo的开源项目。

Do you need a service mesh? If you’re deploying to a cloud platform, have multiple types of languages/frameworks implementing your workloads, and building a microservices architecture, then you may need one. There are many options. I have done talks on comparing and contrasting various, with my [OSCON presentation being the most recent](https://www.slideshare.net/ceposta/navigating-the-service-mesh-landscape-with-istio-consul-connect-and-linkerd). Feel free to [reach out for guidance](http://twitter.com/christianposta?lang=en) on which one is best for you.

你需要一个服务网格吗?如果您部署到云平台，有多种类型的语言/框架来实现您的工作负载，并构建一个微服务架构，那么您可能需要一个。有很多选择。我做过各种比较和对比的演讲，最近的是[OSCON演讲](https://www.slideshare.net/ceposta/navigating-mesh - -istio- -connect-and-linkerd)。请随意[参考](http://twitter.com/christianposta)并找到最合适你的。

## 结论

Yes, API Gateways have an overlap with service mesh in terms of functionality. They may also have an overlap in terms of technology used (e.g., Envoy). Their roles are quite a bit different, however, and understanding this can save you a lot of pain as you deploy your microservices architectures and discover unintended assumptions along the way.

是的，API网关在功能上与服务网格有重叠。它们在使用的技术方面也可能有重叠（例如，Envoy）。但是，它们的角色有很大的不同，理解这一点可以在部署微服务架构和发现无意的假设时为您省去很多麻烦。