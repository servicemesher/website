# 服务网格的三个技术优势及其操作限制 第2部分

Tobias Kunze, June 11, 2019



Welcome to part 2 of our blog series on the benefits and operational limitations of service meshes. In [part 1](https://glasnostic.com/blog/service-mesh-istio-limits-and-benefits-part-1), we saw how developers can benefit from a service mesh’s ability to provide added observability, traffic control and security capabilities to microservices architectures. In this post, we are going to look at these same three dimensions, but instead of focusing on developer concerns, we are going to dive in and explore a service mesh’s limitations from the perspective of the operations team.

欢迎来到关于服务网格的优势和操作限制的系列文章的第2部分。在[第1部分](https://glasnostic.com/blog/services- mesh-istio- limited -and-benefit -part-1)中，我们了解了开发人员如何从服务网格为微服务体系结构提供附加的可观察性、流量控制和安全功能的能力中获益。在这篇文章中，我们将关注同样的三个维度，但代替开发人员的关注点的，是从操作团队的角度深入研究服务网格的局限性。



## 可观测性的限制

Observability consistently tops the wishlist of distributed systems engineers. It is therefore no surprise that service meshes try their best to cater to this need. However, the observability that engineers desire and that service meshes provide does not aim to support traditional operations activities such as capacity planning: it focuses on the development activity of *runtime debugging*.

可观察性始终是分布式系统工程师的首选。因此，服务网格尽其所能来满足这种需求就不足为奇了。然而，工程师希望的可观察性和服务网格提供的可观察性并不旨在支持传统的操作活动，比如容量规划:它关注的是*运行时调试*的开发活动。

Runtime debugging, of course, requires that metrics be *interpretable* In the context of a request’s thread of execution. This is at odds with today’s federated, [organically evolving service architectures](https://glasnostic.com/blog/microservices-architecture-patterns-service-mesh-glossary#Organic-Architecture) whose metrics are increasingly unpredictable and inconclusive.

当然，运行时调试要求指标在请求的执行线程上下文中是“可解释的”。这与今天的联合的[有机发展的服务架构](https://glasnostic.com/blog/microservices-architecture-patterns-service-mesh-glossary#Organic-Architecture)是不一致的，它的度量标准越来越不可预测和不确定。

Observing a distributed system makes sense if its services make up a single application whose design remains static over an extended period of time. Such systems can be baselined and reasoned about and, as a result, metrics collected from them can be interpreted—in particular if the architecture is predominantly synchronous.

如果一个分布式系统的服务组成一个应用程序，并且该应用程序的设计在很长一段时间内保持静态，那么观察这个分布式系统是有意义的。这样的系统可以被基线化和推理，因此，从它们收集到的度量可以被解释——特别是如果体系结构主要是同步的。

But interpretability goes away with the kind of federated, organically evolving architectures modern enterprises are running today. For one, baselines—and thus the “baseline understanding” of practitioners—have become obsolete in a world of organically evolving architectures. And without baselines, the conclusive interpretation of metrics can prove challenging. Also, the federation of services reduces the area of responsibility of individual development teams. Federated, organically evolving service landscapes are created by parallel, self-managing teams that develop in rapid decision and learning cycles. In other words, development teams are only responsible for a handful of services: they have a limited horizon of control. Because there is no point tracing into a dependency that teams don’t own, observability only makes sense within a development team’s horizon of control. The only global horizon of control in federated, organically evolving architectures is that of the operations team that is responsible for the *entire* service landscape, not just a set of related services or an application—in other words, the *mission control*operations team.

但是，随着现代企业今天运行的那种联合的、有机发展的体系结构的消失，可解释性也消失了。首先，基线——以及实践人员的“基线理解”——在一个有机发展的架构世界中已经过时了。如果没有基线，对度量的最终解释可能会很有挑战性。此外，服务联盟减少了单个开发团队的职责范围。联合的、有机发展的服务环境是由并行的、在快速决策和学习周期中发展的自我管理团队创建的。换句话说，开发团队只负责少量的服务:他们的控制范围有限。因为没有必要跟踪到团队不拥有的依赖项，所以可观察性只在开发团队的控制范围内才有意义。在联合的、有机发展的体系结构中，惟一的全局控制视野是负责“整个”服务场景的操作团队，而不仅仅是一组相关服务或应用程序——换句话说，是“任务控制”操作团队。

Observability also becomes data-heavy at scale. As federated, organically evolving architectures grow, the volume of data collected in telemetry and traces grows exponentially while the importance of individual service instances declines. In other words, observability with the goal of runtime debugging causes practitioners to collect more and more data that is less and less important. As a result, hardly any metric collected is actionable.

可观测性在尺度上也变得数据量大。随着联合的、有机发展的体系结构的增长，在遥测和跟踪中收集的数据量呈指数级增长，而单个服务实例的重要性下降。换句话说，以运行时调试为目标的可观察性导致从业者收集的数据越来越多，而这些数据却越来越不重要。因此，几乎没有任何收集到的度量是可操作的。

As these architectures grow, observability needs to “move up in the stack.” Instead of collecting pet metrics developers can understand, operators need to focus on higher-level KPIs that allow them to *detect and react* in real-time. These KPIs need to be meaningful globally. This is where the observability provided by service meshes falls short as well. Due to their opinionated nature, service meshes tend to be deployed insularly in the enterprise, typically in environments that run on Kubernetes. Operational observability, on the other hand, requires high-level, *golden signal* metrics that work across bare metal, virtual machine and container deployments and across multiple regions and clouds.

随着这些体系结构的发展，可观察性需要“在堆栈中向上移动”。“与收集开发人员能够理解的宠物指标不同，运营商需要关注更高级别的kpi，让他们能够实时‘检测和反应’。”这些kpi需要具有全局意义。这也是服务网格提供的可观察性不足的地方。由于其固执己见的特性，服务网格往往在企业中被孤立地部署，特别是在运行在Kubernetes上的环境中。另一方面，操作可观察性需要高级的“黄金信号”度量，它可以跨裸金属、虚拟机和容器部署以及跨多个区域和云工作。

In summary, service meshes provide observability for runtime debugging. This is valuable within the developer’s horizon of control but requires metrics that can be interpreted within the context of a request’s thread of execution. However, in today’s federated, organically evolving service landscapes, the lack of baseline metrics and a reduced the horizon of control spoils such interpretability.

总之，服务网格为运行时调试提供了可观察性。这在开发人员的控制范围内是有价值的，但是需要可以在请求的执行线程上下文中解释的度量标准。然而，在当今联合的、有机发展的服务环境中，缺乏基线度量和控制范围的缩小破坏了这种可解释性。

Observability for runtime debugging is also data-heavy, leading to the collection of ever more data at an ever higher cost, yet ever lower value. To escape this downward value spiral, observability needs to “move up the stack,” collecting higher-level, global *golden signals* to enable *mission control* operations teams to detect and react in real-time. The observability provided by service meshes is unsuitable for this goal not just because it aims to support runtime debugging, but also because golden signals need to be global and service meshes are too opinionated and invasive to be deployed everywhere.

运行时调试的可观察性也是数据密集型的，这导致以更高的成本收集更多的数据，但价值却更低。为了避免这种价值螺旋下降，可观测性需要“向上移动堆栈”，收集更高级别的全局“黄金信号”，以使“任务控制”操作团队能够实时检测并做出反应。服务网格提供的可观察性不适合这个目标，这不仅是因为它的目标是支持运行时调试，还因为黄金信号需要是全局的，而且服务网格过于自以为是和侵入性，不适合部署在任何地方。

## 流量控制的限制

Service meshes evolved as a solution to the problem of how to route service calls to the best target instance, i.e. the instance that can serve the request fastest. This is why service meshes are developer- or “routing-oriented”: they serve the perspective of the developer, who is looking to call a service without having to deal with the intricacies of remote service calls. Because of this, service meshes prove to be not well-suited for managing workloads in an architecture that involves dozens, if not hundreds of microservices which communicate with each other across development teams, business units and even corporate firewalls, i.e. federated service architectures with shifting service-to-service interactions and dependencies that evolve organically over time.

服务网格的发展是为了解决如何将服务调用路由到最佳目标实例的问题，即可以最快地为请求提供服务的实例。这就是为什么服务网格是面向开发人员或“面向路由”的:它们服务于开发人员的视角，开发人员希望调用服务而不必处理复杂的远程服务调用。因此,服务网格被证明是不适合管理工作负载在一个架构,涉及几十个,如果不是数以百计的microservices相互沟通整个开发团队,业务部门甚至公司防火墙,即联邦服务架构service - to - service交互和依赖关系也发生了变化,随着时间的推移演变有机。

For instance, while it is relatively straightforward to express a [*forward*routing policy](https://glasnostic.com/blog/how-canary-deployments-work-1-kubernetes-istio-linkerd#figure-3) with a service mesh, expressing policies that control the flow of traffic *backwards*, against downstream clients to e.g. [exert backpressure](https://glasnostic.com/blog/preventing-systemic-failure-backpressure)or [implement bulkheads](https://glasnostic.com/blog/preventing-systemic-failure-bulkheads), is much harder, if not impossible to achieve. While it is in theory possible for a service mesh data plane to make traffic decisions based on both source *and* destination rules, the developer orientation of control planes such as [Istio](https://glasnostic.com/blog/kubernetes-service-mesh-what-is-istio) keeps them from providing traffic control over arbitrary sets of service interactions.

例如,是相对简单的表达[*向前*路由策略](https://glasnostic.com/blog/how-canary-deployments-work-1-kubernetes-istio-linkerd#figure-3)与服务网格,表达的政策控制交通流的* *,向后对下游客户如[施加反压力](https://glasnostic.com/blog/preventing-systemic-failure-backpressure)或[实现舱壁](https://glasnostic.com/blog/preventing-systemic-failure-bulkheads),即使不是不可能实现，也要困难得多。虽然在理论上是可能的服务网格数据平面交通决策基于源*和*目标规则,开发人员定位等控制飞机[Istio](https://glasnostic.com/blog/kubernetes-service-mesh-what-is-istio)让他们提供流量控制任意的服务交互集。

This lack of ability to apply policy to arbitrary sets of service interactions also makes it fiendishly hard to layer policies. For instance, when a [bulkhead](https://glasnostic.com/blog/preventing-systemic-failure-bulkheads) is in place between two availability zones, but a critical service needs to be able to fail over when necessary, it is near-impossible to figure out the correct thresholds service mesh rules, in particular if deployments auto-scale.

这种将策略应用于任意服务交互集的能力的缺乏也使得策略的分层变得极其困难。例如,当一个[壁](https://glasnostic.com/blog/preventing-systemic-failure-bulkheads)是两个可用性区域,但一个关键服务需要能够在必要时失败,这是不可能算出正确的阈值服务网格规则,特别是如果部署自动扩展。

Perhaps the most significant problem service meshes present for operators, however, is their limited deployability outside of Kubernetes—a direct result of their “opinionatedness.” Modifying deployments and deployment pipelines to correctly include a data plane sidecar is often impossible and adding a virtual machine to a service mesh is [convoluted at best](https://istio.io/docs/setup/kubernetes/additional-setup/mesh-expansion/), yet still does not enable operators to capture inter-VM traffic. Worse, to integrate existing, non-Kubernetes workloads in a Kubernetes-based service mesh requires operators not only to adapt application code—the resulting deployment is then dependent on the Kubernetes mesh.

然而，对于运营商来说，最重要的问题可能是他们在kubernet.com之外的有限可部署性——这是他们“固执己见”的直接结果。“修改部署和部署正确的管道包括一个数据平面的双轮马车通常是不可能的,添加一个虚拟机服务网格是[复杂的在最好的情况下](https://istio.io/docs/setup/kubernetes/additional-setup/mesh-expansion/),但仍然不允许操作员捕捉inter-VM流量。更糟的是，要将现有的非Kubernetes工作负载集成到基于Kubernetes的服务网格中，操作人员不仅需要调整应用程序代码，还需要根据Kubernetes网格进行部署。

Lastly, traffic control of current service mesh implementations is configured via YAML deployment descriptors. Deployment descriptors are an excellent way to store configuration in version control and thus can be used to reconstruct a well-defined initial state, but they are not very well suited for the continual, real-time changes that operations teams need to make during times of distress.
最后，通过YAML部署描述符配置了当前服务网格实现的流量控制。部署描述符是在版本控制中存储配置的一种很好的方法，因此可以用来重建定义良好的初始状态，但是它们不太适合操作团队在遇到困难时需要进行的持续、实时的更改。

In summary, while traffic control provided by service meshes supports a number of developer-oriented control mechanisms like destination rules and virtual service definitions, it does not support non-routing-oriented operational patterns like [backpressure](https://glasnostic.com/blog/preventing-systemic-failure-backpressure) or bulkheads. Service meshes policies are impossible to layer predictably in the face of architectural change and are very difficult to deploy outside of Kubernetes. Service mesh configuration is typically based on deployment descriptors that are bound to get in the way of operations teams when time to remediation is at a premium.

总之,虽然交通控制提供的服务网格支持许多面向开发人员的控制机制(如目的地规则和虚拟服务定义,它不支持non-routing-oriented操作模式[反压力](https://glasnostic.com/blog/preventing-systemic-failure-backpressure)或舱壁。面对体系结构更改，服务网格策略不可能预先分层，而且很难部署到Kubernetes之外。服务网格配置通常基于部署描述符，当需要进行补救时，部署描述符必然会妨碍操作团队。

## 安全限制

By virtue of proxying service-to-service calls, service meshes are in a great position to provide the core set of developer-oriented application security features such as authentication, authorization, accounting, secure transport and service identity. While providing these features out of the box can be a time-saver for application developers, configuring them using YAML deployment descriptors tends to be difficult and error-prone, which obviously detracts from their goals.

通过代理服务到服务的调用，服务网格可以很好地提供面向开发人员的应用程序安全特性的核心集，比如身份验证、授权、会计、安全传输和服务标识。虽然为应用程序开发人员提供开箱即用的这些特性可以节省时间，但是使用YAML部署描述符配置这些特性往往比较困难且容易出错，这显然会降低他们的目标。

From an operational perspective, these *service-call-based* security features provide limited security at best and do nothing to mitigate the systemic security issues that operations teams care about, such as impacted availability, denial-of-service attacks, intrusions or segmentation violations.

从操作的角度来看，这些“基于服务调用”的安全特性最多只能提供有限的安全，对于操作团队所关心的系统安全问题(如影响可用性、拒绝服务攻击、入侵或分割违规)毫无帮助。

Due to the opinionated, invasive character of service meshes, their application security features break down in heterogeneous environments that, apart from Kubernetes, also consist of bare metal, virtual machine, PaaS, plain container or serverless deployments. Similarly, service mesh security features break down in Kubernetes environments when not all services have sidecars, as is the case in “server sidecar” deployments, where only the target service has a sidecar injected [for performance reasons](https://istio.io/docs/concepts/performance-and-scalability/#latency-for-istio-hahahugoshortcode-s2-hbhb).

由于服务网格的固执己见和侵入性，它们的应用程序安全特性在异构环境中会崩溃，除了Kubernetes之外，异构环境还包括裸机、虚拟机、PaaS、普通容器或无服务器部署。同样,服务网格安全特性分解Kubernetes环境中不是所有的服务都有sidecar时,在“服务器的双轮马车”一样部署,只有目标服务的双轮马车注入[由于性能的原因](https://istio.io/docs/concepts/performance-and-scalability/ # latency-for-istio-hahahugoshortcode-s2-hbhb)。

The platform-oriented, opinionated approach of service meshes to application security also has the effect that most meshes don’t integrate well with other security solutions—something that operations teams deeply care about. Istio has the ability to use alternative CA plugins and external tools could conceivably call `kubectl` with a YAML deployment descriptor to apply security-relevant policies, but because service meshes don’t support policy layering, it is impossible for external tools to apply such policies correctly and safely.

面向平台、固执己见的服务与应用程序安全性相结合的方法也有一个影响，那就是大多数的服务与其他安全解决方案不能很好地集成—这是操作团队非常关心的问题。Istio能够使用替代的CA插件，外部工具可以使用YAML部署描述符调用“kubectl”来应用与安全性相关的策略，但是由于服务网格不支持策略分层，外部工具不可能正确和安全地应用这些策略。

In summary, services meshes provide a number of application security features that are valuable for developers but contribute little to the more challenging operational security concerns. Because service meshes are opinionated platforms as opposed to being an open tool that collaborates with external security solutions, even the application security provided by them tends to break down quickly in heterogeneous environments.

总之，服务网格提供了许多应用程序安全特性，这些特性对开发人员很有价值，但对更具挑战性的操作安全问题贡献甚微。由于服务网格是自定义的平台，而不是与外部安全解决方案协作的开放工具，因此即使是由它们提供的应用程序安全性在异构环境中也会很快崩溃。

## 操作需要

For development teams building microservice applications, service meshes provide many benefits that abstract away the complexities that distributing services brings about. Some of these benefits such as encryption, “intelligent” routing and runtime observability help with operating such applications, but quickly prove to be too limited as applications grow, services become increasingly connected and the business adopts a federated, organically evolving [service landscape](https://glasnostic.com/blog/microservices-architecture-patterns-service-mesh-glossary#Service-Landscape).

对于构建微服务应用程序的开发团队，服务网格提供了许多好处，可以抽象出分布式服务带来的复杂性。其中的一些好处,如加密、“智能”路由和运行时可观察性帮助操作这样的应用程序,但很快被证明是太有限,随着应用程序的增长,服务越来越连接和业务采用联合,有机发展[服务景观](https://glasnostic.com/blog/microservices-architecture-patterns-service-mesh-glossary)服务。

Operations teams need control over more than just service-to-service calls. They need to be able to apply [operational patterns](https://glasnostic.com/blog/microservices-architecture-patterns-service-mesh-glossary/#Operational-Patterns-and-Techniques) to arbitrary sets of interactions. They also need to be able to *layer* policies so they can be applied without affecting each other. Operations teams need to be able to control their service landscape in real-time, without having to manage hundreds of YAML descriptors. To do all that, they don’t need opinionated platforms, but instead tools that integrate with existing tools and tools that apply to the entire service landscape, without affecting any deployment.

运营团队需要控制的不仅仅是服务对服务的调用。他们需要能够将[操作模式](https://glasnostic.com/blog/microservices-architecture-patterns- services- mesh-glossary/# operationalpatterns -and- techniques)应用到任意一组交互中。它们还需要能够“分层”策略，以便能够在不影响彼此的情况下应用它们。运营团队需要能够实时控制他们的服务环境，而不需要管理数百个YAML描述符。要做到这一切，他们不需要固执己见的平台，而是需要与现有工具集成的工具，以及应用于整个服务场景的工具，而不影响任何部署。

So, if service meshes are, at their core, a technology for developers creating stand-alone applications with limited complexity on top of Kubernetes, not for operations teams that are responsible for ensuring the correct operation of an entire, heterogeneous and dynamic service landscape, how can we address the necessary operational concerns?

因此，如果服务网格的核心是一种技术，用于开发人员在Kubernetes之上创建复杂度有限的独立应用程序，而不是用于负责确保整个异构动态服务环境的正确操作的操作团队，那么我们如何解决必要的操作问题呢?

- **Solution 1: Wait Until Service Meshes Support Operational Concerns.** The naïve answer for those of us who see service meshes, in particular Istio, as an all-in-one solution to every distributed problem is to simply wait until service meshes support these concerns. Of course, this is unlikely to happen. Service meshes are designed around developer concerns like service linking and smarter instance routing and would have to change considerably to support operational patterns, which generally can’t be addressed by managing point-to-point connections.
- 对于我们这些将服务网格(特别是Istio)视为每个分布式问题的一体化解决方案的人来说，最简单的解决方案就是等待服务网格支持这些关注点。当然，这不大可能发生。服务网格是围绕开发人员的关注点(如服务链接和更智能的实例路由)设计的，必须进行很大的更改才能支持操作模式，而这通常无法通过管理点对点连接来解决。
- **Solution 2: Throw More Engineering at the Problem.** The engineer’s answer would be to, well, throw more engineering at the problem. Developers could write a policy engine, glue code to integrate service mesh security with other security tools, data aggregators to collect the high-level metrics that operators need, and so forth. Obviously, this would be quite costly and more than unlikely to work satisfactorily anytime soon.
- 工程师的答案是，在这个问题上投入更多的工程。开发人员可以编写策略引擎、粘接代码来集成服务网格安全性和其他安全工具、数据聚合器来收集操作人员需要的高级指标，等等。显然，这将是相当昂贵的，而且不太可能在短期内令人满意地工作。
- **Solution 3: Adopt a Cloud Traffic Controller.** The best alternative is to simply leave service meshes to the development teams and to let operations teams adopt a cloud traffic controller. That way, operations teams can detect [complex emergent behaviors](https://glasnostic.com/blog/microservices-architecture-patterns-service-mesh-glossary/#Emergent-Behaviors), remediate them in real-time and create the automations they need to effectively apply the operational patterns necessary to keep the architecture under control.
- 最好的选择是将服务网格留给开发团队，让运营团队采用云流量控制器。这样,运营团队可以检测[复杂紧急行为](https://glasnostic.com/blog/microservices-architecture-patterns-service-mesh-glossary/#Emergent-Behaviors),实时纠正他们,创造他们所需要的自动化有效应用的操作模式控制架构所必需的。

Glasnostic是这样一个云流量控制器。

<iframe src="https://player.vimeo.com/video/343154979?title=0&amp;profile=0&amp;byline=0&amp;dnt=1&amp;autoplay=1&amp;muted=1&amp;loop=1" allow="autoplay; fullscreen" allowfullscreen="" style="box-sizing: border-box; position: absolute; top: 0px; left: 0px; width: 540px; height: 328.75px; border: none;"></iframe>

**Figure 1:** Glasnostic is a cloud traffic controller that lets operations and security teams control the complex interactions and behaviors among federated microservice applications at scale. Glasnostic是一个云流量控制器，允许操作和安全团队大规模控制联邦微服务应用程序之间的复杂交互和行为。

Glasnostic is a control plane for service landscapes that helps operations and security teams control the complex interactions and behaviors among federated microservice applications at scale. This is in contrast to service meshes, which manage the service-to-service connections within an application. Glasnostic is an independent solution, not another platform. It requires no sidecars or agents and integrates cleanly into any existing environment.

Glasnostic是一个用于服务环境的控制平面，它帮助操作和安全团队大规模地控制联邦微服务应用程序之间的复杂交互和行为。这与服务网格相反，服务网格管理应用程序中的服务到服务连接。公开化是一个独立的解决方案，而不是另一个平台。它不需要侧车或代理，并且干净地集成到任何现有环境中。

By gaining control over service interactions, teams can control emergent behaviors, prevent cascading failures and avert security breaches.

通过获得对服务交互的控制，团队可以控制紧急行为、防止级联故障和避免安全漏洞。

Glasnostic was founded after learning first-hand that successful architectures are allowed to evolve organically as opposed to being rigidly designed upfront. It uses a unique network-based approach to provide operators with the observability and control they need to detect and remediate emergent behaviors in a service landscape.

Glasnostic是在直接了解到成功的架构可以有机地发展，而不是预先进行严格的设计之后成立的。它使用一种独特的基于网络的方法来为操作人员提供他们需要的可观察性和控制能力，以检测和纠正服务场景中的紧急行为。