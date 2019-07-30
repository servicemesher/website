# 服务网格的三个技术优势及其操作限制 第2部分

Tobias Kunze, June 11, 2019

欢迎来到关于服务网格的优势和操作限制的系列文章的第2部分。在[第1部分](https://glasnostic.com/blog/services- mesh-istio- limited -and-benefit -part-1)中，我们了解了开发人员如何从服务网格为微服务架构提供附加的可观察性、流量控制和安全功能的能力中获益。在这篇文章中，我们将关注同样的三个维度，但不同于开发人员的关注点，我们会从操作团队的角度深入研究服务网格的局限性。

## 可观测性的限制

可观察性始终是分布式系统工程师的首选。因此，服务网格尽其所能来满足这种需求就不足为奇了。然而，工程师期望的以及服务网格提供的可观察性并没有针对传统的运维行为，比如容量规划：它关注的是*运行时调试*的开发活动。

当然，运行时调试要求指标在请求的执行线程上下文中是“可解释的”。这与当今联合的，[有组织发展的服务架构](https://glasnostic.com/blog/microservices-architecture-patterns-service-mesh-glossary#Organic-Architecture)是不一致的，它的度量标准是不可预测和不确定的。

如果一个分布式系统的服务构建了一个应用，并且其设计在很长一段时间内保持静态，那么观测这个分布式系统是有意义的。这样的系统可以被基线化和合理化，作为结果，从它们收集到的指标可以被解释——特别是架构主要是同步模式。

但是，随着现代企业今天运行的那种联合的、有组织的架构的消失，可解释性也消失了。首先，基线——以及实践人员的“基线理解”——在一个有组织的架构世界中已经过时了。如果没有基线，对度量的最终解释可能会很有挑战。此外，服务的组合减少了单个开发团队的职责范围。联合的、有组织的服务环境是由并行的、在快速决策和学习周期中发展的自我管理团队创建的。换句话说，开发团队只负责少量的服务：他们的控制范围有限。因为没有必要跟踪到不属于团队的依赖，所以可观察性只在开发团队的控制范围内才有意义。在联合的、有组织的架构中，惟一的全局控制视野是负责“整个”服务场景的运维团队，而不仅仅是一组相关服务或应用——换句话说，是“任务控制”的操作团队。

可观测性在尺度上也会变成数据密集型。随着联合的、有组织架构的增长，在遥测和追踪中收集的数据量呈指数级增长，而单个服务实例的重要性下降。换句话说，以运行时调试为目标的可观察性导致从业者收集的数据越来越多，而这些数据却越来越不重要。因此，收集到的指标几乎没有可用的。

随着这些架构的发展，可观察性需要“在技术栈中向上移动”。与收集开发人员能够理解的宠物指标不同，运维人员需要关注更高级别的KPI，让他们能够实时检测和反应。这些KPI需要具有全局的意义。这也是服务网格提供的可观察性不足的地方。由于其固执己见的特性，服务网格往往在企业中被孤立地部署，特别是运行在Kubernetes上的环境中。另一方面，可操作的观察性需要高级的“黄金信号”指标，它可以跨裸机、虚拟机和容器部署以及跨多个区域和云工作。

总之，服务网格为运行时调试提供了可观察性。这在开发人员的控制范围内是有价值的，但是需要的指标是可以在请求执行的线程上下文中可解释的。然而，在当今联合的、有组织的服务环境中，缺乏基准指标和缩小的控制范围破坏了这种可解释性。

运行时调试的可观察性也是数据密集型的，这导致以更高的成本收集更多的数据，但价值却更低。为了避免价值的螺旋下降，可观测性需要“向上移动栈”，收集更高级别的全局的*黄金信号*，以使*任务控制*运维团队能够实时检测并做出反应。服务网格提供的可观察性不符合这个目标，这不仅是因为它的目标是支持运行时调试，还因为黄金信号需要是全局的，而且服务网格过于武断和具有侵入，不适合部署在每个地方。

## 流量控制的限制

服务网格的发展是为了解决如何将对服务的调用路由到最佳目标实例，例如可以最快地为请求提供服务的实例。这就是为什么服务网格是面向开发人员或“面向路由”的：它们服务于开发人员的视角，开发人员希望调用服务而不必处理复杂的远程服务调用。因此，服务网格被证明是不适合管理这样一个架构下的工作负载，它涉及了不是数百个也是数十个的微服务之间的跨越开发团队、业务部门甚至是公司防火墙的交互，例如随着时间的推移，具有不断变化的服务到服务交互和依赖关系的组合服务架构会有机地发展。

例如，在服务网格下要表达[*向前*路由策略](https://glasnostic.com/blog/how-canary-deployments-work-1-kubernetes-istio-linkerd#figure-3)和向后的流量控制是比较简单的，而下游客户端如[施加反压力](https://glasnostic.com/blog/preventing-systemic-failure-backpressure)或[实现舱壁](https://glasnostic.com/blog/preventing-systemic-failure-bulkheads)就要更加困难，即使不是不可能实现。服务网格的数据平面基于源和目标规则去构建流量决策从理论上讲是可能的，开发人员定位像[Istio](https://glasnostic.com/blog/kubernetes-service-mesh-what-is-istio)这样的控制平面，让他们提供对任意的服务交互集的流量控制。

这种将策略应用于任意服务交互集的能力的缺乏也使得策略的分层变得极其困难。例如，当一个[壁](https://glasnostic.com/blog/preventing-systemic-failure-bulkheads)在两个可用性区域之间，但一个关键服务需要能够在需要是故障转移，这几乎不可能找到正确的服务网格规则的阈值，特别是自动扩展的部署情况下。

然而，对于运维人员来说，最重要的问题是服务网格在kubernetes之外的有限的可部署性——这是他们“固执己见”的直接结果。修改部署和部署过程正确的包括一个数据平面的sidecar通常是不可能的，添加一个虚拟机到服务网格是[最令人费解的](https://istio.io/docs/setup/kubernetes/additional-setup/mesh-expansion/)，但仍然不允许操作员捕捉内部虚拟机的流量。更糟的是，要将现有的非Kubernetes工作负载集成到基于Kubernetes的服务网格中，运维人员不仅需要调整应用程序代码，还需要根据Kubernetes网格进行部署。

最后，通过YAML部署描述配置了当前服务网格实现的流量控制。部署描述是在版本控制中存储配置的一种很好的方法，因此可以用来重建定义良好的初始状态，但是它们不太适合运维团队在遇到困难时需要进行持续、实时的更改。

总之，虽然服务网格提供的流量控制支持许多面向开发人员的控制机制，如目标规则和虚拟服务定义，它不支持面向无路由的操作模式如[反压力](https://glasnostic.com/blog/preventing-systemic-failure-backpressure)或舱壁。面对架构更改，服务网格策略不可能预先分层，而且很难部署到Kubernetes之外。服务网格配置通常基于部署描述，当需要进行补救时，这些描述必然会妨碍到运维团队。

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