---
originallink: "https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/"
author: "Ivan Velichko"
date: "2019-08-22T10:42:00+08:00"
draft: false
banner: "/img/blog/banners/006tKfTcly1g0t1i9oxo4j31400u0npe.jpg"
translator: "马若飞"
translatorlink: "https://github.com/malphi"
reviewer:  ["宋净超"]
reviewerlink:  ["https://jimmysong.io"]
title: "从容器化到编排的旅程"
description: "作者对在Istio环境下运行的Kafka进行了基准测试，并对测试结果进行了分析。"
categories: ["kubernetes"]
tags: ["kubernetes"]
---

## 编者按

> 本文是 todo

Containers gave birth to more advanced server-side architectures and sophisticated deployment techniques. Containers nowadays are so widespread that there is already a bunch of standard-alike specifications ([1](https://github.com/opencontainers/runtime-spec), [2](https://github.com/opencontainers/image-spec), [3](https://kubernetes.io/blog/2016/12/container-runtime-interface-cri-in-kubernetes/), [4](https://github.com/containernetworking/cni), ...) describing different aspects of the containers universe. Of course, on the lowest level lie Linux primitives such as *namespaces* and *cgroups*. But containerization software is already so massive that it would be barely possible to implement it without its own concern separation layers. What I'm trying to achieve in this **ongoing effort** is to guide myself starting from the lowest layers to the topmost ones, having as much practice (code, installation, configuration, integration, etc) and, of course, **fun** as possible. The content of this page is going to be changing over time, reflecting my understanding of the topic.

容器产生了更高级的服务器端体系结构和更复杂的部署技术。现在容器非常普遍，已经有一堆类似标准的规范描述了容器领域的不同方面。当然，底层是Linux原语，比如名称空间和cgroups。但是，容器化软件已经非常庞大，如果没有它自己的关注点分离层，几乎不可能实现它。在这个持续的过程中，我想要做的是引导自己从最低的层开始，到最高的层，拥有尽可能多的实践(代码、安装、配置、集成等等)，当然，还有尽可能多的乐趣。这一页的内容会随着时间的推移而改变，反映出我对这个主题的理解。

## Container Runtimes

I want to start the journey from the lowest level non-kernel primitive - **container runtime**. The word *runtime* is a bit ambiguous in the containerverse. Each project, company or community has its own and usually context-specific understanding of the term *container runtime*. Mostly, the hallmark of the runtime is defined by the set of responsibilities varying from a bare minimum (creating namespaces, starting *init*process) to comprehensive container management including (but not limiting) images operation. A good overview of runtimes can be found in [this article](https://www.ianlewis.org/en/container-runtimes-part-1-introduction-container-r).

我想从最低级别的非内核原语开始——**容器运行时**。在containerverse中，“运行时”这个词有点含糊不清。每个项目、公司或社区对术语“容器运行时”都有自己的、通常是上下文特定的理解。大多数情况下，运行时的特征是由一组职责定义的，从最基本的职责(创建名称空间、启动*init*进程)到全面的容器管理，包括(但不限于)映像操作。本文对运行时有一个很好的概述

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/runtime-levels.png)

This section is dedicated to *low-level container runtimes*. A group of big players forming an [Open Container Initiative](https://www.opencontainers.org/) standartized the low-level runtime in the [*OCI runtime specification*](https://github.com/opencontainers/runtime-spec). Making a long story short - a low-level container runtime is a piece of software that takes as an input a folder containing rootfs and a configuration [file] describing container parameters (such as resource limits, mount points, process to start, etc) and as a result the runtime starts an isolated process, i.e. container.

本节专门讨论*低级容器运行时*。在[*OCI运行时规范*]中，组成[开放容器倡议]的一组大型参与者对底层运行时进行了标准化。长话短说,低级容器运行时是一个软件,作为输入一个文件夹包含rootfs和配置[文件]描述容器参数(如资源限制、挂载点、流程开始,等),因此运行时启动一个孤立的过程,即容器。

As of 2019, the most widely used container runtime is [runc](https://github.com/opencontainers/runc). This project started as a part of Docker (hence it's written in Go) but eventually was extracted and transformed into a self-sufficient CLI tool. It is difficult to overestimate the importance of this component - *runc* is basically a reference implementation of the OCI runtime specification. During our journey we will work a lot with *runc* and here is [an introductory article](https://iximiuz.com/en/posts/implementing-container-runtime-shim/).

到2019年，最广泛使用的容器运行时是[runc](https://github.com/opencontainers/runc)。这个项目最初是Docker的一部分(因此它是用Go编写的)，但最终被提取并转换为一个自给自足的CLI工具。很难高估这个组件的重要性——*runc*基本上是OCI运行时规范的一个参考实现。在我们的旅程中，我们将大量使用*runc*，下面是[一篇介绍性文章](https://iximiuz.com/en/posts/implementing-container-runtime-shim/)。

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/runc.png)



One more notable OCI runtime implementation out there is [crun](https://github.com/containers/crun). It's written in C and can be used both as an executable and as a library.

一个更值得注意的OCI运行时实现是[crun](https://github.com/containers/crun)。它是用C语言编写的，既可以作为可执行文件，也可以作为库使用。

## Container management

Using *runc* in command line we can launch as many containers as we want. But what if we need to automate this process? Imagine we need to launch tens of containers keeping track of their statuses. Some of them need to be restarted on failure, resources need to be released on termination, images have to be pulled from registries, inter-containers networks need to be configured and so on. This is already a slightly higher-level job and it's a responsibility of a *container manager*. To be honest, I have no idea whether this term is in common use or not, but I found it convenient to structure things this way. I would classify the following projects as *container managers*: [containerd](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#containerd), [cri-o](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#cri-o), [dockerd](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#dockerd), and [podman](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#dockerd).

在命令行中使用*runc*，我们可以启动任意数量的容器。但是如果我们需要自动化这个过程呢?假设我们需要启动数十个容器来跟踪它们的状态。其中一些在失败时需要重新启动，在终止时需要释放资源，必须从注册中心提取映像，需要配置容器间网络，等等。这已经是一个稍微高级的工作，并且是一个“容器管理器”的职责。老实说，我不知道这个词是否常用，但我发现用这种方式来组织事物很方便。我将以下项目分类为“容器管理器”

#### containerd

As with *runc*, we again can see a Docker's heritage here - [*containerd*](https://github.com/containerd/containerd) used to be a part of the original Docker project. Nowadays though *containerd* is another self-sufficient piece of software. It calls itself a container runtime but obviously, it's not the same kind of runtime *runc* is. Not only the responsibilities of *containerd* and *runc* differ but also the organizational form does. While *runc* is a just a command-line tool, *containerd* is a long-living daemon. An instance of *runc* cannot outlive an underlying container process. Normally it starts its life on `create` invocation and then just [`exec`](https://linux.die.net/man/3/exec)s the specified file from container's rootfs on `start`. On the other hand, *containerd* can outlive thousands of containers. It's rather a server listening for incoming requests to start, stop, or report the status of the containers. And under the hood *containerd* uses *runc*. However, *containerd* is more than just a container lifecycle manager. It is also responsible for image management (pull & push images from a registry, store images locally, etc), cross-container networking management and some other functions.

与*runc*一样，我们可以在这里再次看到Docker的传统——[*containerd*]曾经是原始Docker项目的一部分。尽管现在*containerd*是另一个自给自足的软件。它自称为容器运行时，但显然，它与运行时*runc*不是同一种类型的运行时。不仅*containerd*和*runc*的职责不同，组织形式也不同。虽然*runc*只是一个命令行工具，但*containerd*是一个长寿的守护进程。*runc*的实例不能比底层容器进程活得更长。通常，它在“create”调用时启动，然后在“start”上从容器的rootfs中指定文件[' exec ']。另一方面，*containerd*可以比成千上万个容器更长寿。它更像是一个服务器，侦听传入的请求来启动、停止或报告容器的状态。在引擎盖下*containerd*使用*runc*。然而，*containerd*不仅仅是一个容器生命周期管理器。它还负责图像管理(从注册表中拖放图像，本地存储图像，等等)、跨容器联网管理和其他一些功能。

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/containerd.png)



#### cri-o

Another container manager example is [cri-o](https://github.com/cri-o/cri-o). While *containerd* evolved as a result of Docker re-architecting, *cri-o* has its roots in the Kubernetes realm. Back in the day, Kubernetes (ab)used Docker to manage containers. However, with rising of [rkt](https://github.com/rkt/rkt) some brave people added support of interchangeably container runtimes in Kubernetes, allowing container management to be done by Docker and/or rkt. This change, however, led to a huge number of conditional code in Kubernetes and nobody likes too many `if`s in the code. As a result, [Container Runtime Interface (CRI)](https://kubernetes.io/blog/2016/12/container-runtime-interface-cri-in-kubernetes/) has been introduced to Kubernetes making it possible to any CRI-compliant higher-level runtimes (i.e. container managers) to be used without any code change on the Kubernetes side. And *cri-o* is a Red Hat's implementation of CRI-complaint runtime. As with *containerd* *cri-o* is also a daemon exposing a [gRPC] server with endpoints to create, start, stop (and many more other actions) containers. Under the hood, *cri-o* can use any OCI-compliant [low-level] runtimes to work with containers but the default one is ~~again~~ *runc*. The main focus of *cri-o* is being a Kubernetes container runtime. The versioning is the same as k8s versioning, the scope of the project is well-defined and the code base is expectedly smaller (as of July 2019 it's around 20 CLOC and it's approximately 5 times less than *containerd*).

另一个容器管理器示例是[crio]。虽然*containerd*是Docker重新架构的结果，但* crio *却起源于Kubernetes领域。在过去，Kubernetes (ab)使用Docker管理容器。然而，随着[rkt]的崛起，一些勇敢的人增加了对Kubernetes中可互换的容器运行时的支持，允许Docker和/或rkt完成容器管理。然而，这种变化导致Kubernetes中有大量的条件代码，没有人喜欢代码中有太多的“if”。因此，[容器运行时接口(CRI)]被引入到Kubernetes中，使得任何符合crie的高级运行时(即容器管理器)都可以在Kubernetes端使用，而无需进行任何代码更改。而* crio *是Red Hat实现的crio -complaint运行时。与*containerd* * crio *一样，它也是一个守护进程，它公开了一个[gRPC]服务器，该服务器具有创建、启动、停止(以及许多其他操作)容器的端点。在底层，* crio *可以使用任何符合oci的[低级]运行时来处理容器，但是默认的运行时仍然是~~ ~ *runc*。* crio *的主要焦点是Kubernetes容器运行时。版本控制与k8s版本控制相同，项目的范围定义良好，代码库预期更小(截止到2019年7月，大约是20个CLOC，大约是*containerd*的5倍)。

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/cri-o.png)

*cri-o architecture (image from cri-o.io)*

The nice thing about specifications is that everything complaint can be used interchangeably. Once CRI has been introduced, a plugin for *containerd*, implementing CRI gRPC server on top of containerd's functionality appeared. The idea happened to be viable and later on, *containerd* itself got a native CRI support. Thus, Kubernetes can use both *cri-o* and *containerd* as a runtime.

规范的好处是所有抱怨都可以互换使用。一旦CRI被引入，一个用于*containerd*的插件就会在containerd的功能之上实现CRI gRPC服务器。这个想法碰巧是可行的，后来，*containerd*本身获得了本地CRI支持。因此，Kubernetes可以同时使用* crio *和*containerd*作为运行时。

#### dockerd

One more daemon here is [*dockerd*](https://github.com/moby/moby/tree/master/cmd/dockerd). This daemon is manifold. On the one hand, it exposes an API for [Docker command-line client](https://github.com/docker/cli) which gives us all these famous Docker workflows (`docker pull`, `docker push`, `docker run`, `docker stats`, etc). But since we already know, that this piece of functionality has been extracted to *containerd* it's not a surprise that under the hood *dockerd* relies on *containerd*. But that basically would mean that *dockerd* is just a front-end adapter converting *containerd* API to a historically widely used *docker engine* API.

这里还有一个守护进程是[*dockerd*](https://github.com/moby/moby/tree/master/cmd/dockerd)。这个守护进程是多方面的。一方面，它为[Docker命令行客户端]公开了一个API (https://github.com/docker/cli)，它为我们提供了所有这些著名的Docker工作流(' Docker pull '、' Docker push '、' Docker run '、' Docker stats '等)。但是既然我们已经知道，这部分功能已经被提取到*containerd*中，那么在底层*dockerd*依赖于*containerd*就不足为奇了。但这基本上意味着*dockerd*只是一个前端适配器，它将*containerd* API转换为历史上广泛使用的*docker engine* API。

However, [*dockerd*](https://github.com/moby/moby) also provides `compose` and *swarm* things in an attempt to solve container orchestration problem, including multi-machine clusters of containers. As we can see with Kubernetes, this problem is rather hard to address. And having two big responsibilities for a single *dockerd* daemon doesn't sound good to me.

然而，[*dockerd*](https://github.com/moby/moby)也提供了“组合”和“群集”功能，试图解决容器编配问题，包括容器的多机器集群。正如我们在Kubernetes身上看到的，这个问题相当难以解决。对于一个单*dockerd*守护进程来说，同时承担两大职责对我来说并不好。

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/dockerd.png)

*dockerd is a part in front of containerd (image from Docker Blog)*



#### podman

An interesting exception from this daemons list is [*podman*](https://github.com/containers/libpod). It's yet another Red Hat project and the aim is to provide a library (not a daemon) called `libpod` to manage images, container lifecycles, and pods (groups of containers). And `podman` is a management command-line tool built on top of this library. As a low-level container runtime this project ~~as usual~~ uses *runc*. There is a lot in common between *podman*and *cri-o* (both are Red Hat projects) from the code standpoint. For instance, they both heavily use outstanding [*storage*](https://github.com/containers/storage) and [*image*](https://github.com/containers/image) libraries internally. It seems that there's an ongoing effort to use *libpod*instead of *runc* directly in *cri-o*. Another interesting feature of *podman* is a drop-in replacement of some (most popular?) `docker` commands in a daily workflow. The project claims compatibility (to some extent of course) of the *docker CLI API*.

这个守护进程列表中一个有趣的例外是[*podman*](https://github.com/containers/libpod)。这是另一个Red Hat项目，目标是提供一个名为“libpod”的库(而不是守护进程)来管理映像、容器生命周期和pod(容器组)。“podman”是一个构建在这个库之上的管理命令行工具。作为一个底层的容器运行时，这个项目像往常一样使用*runc*。从代码的角度来看，*podman*和* crio *(都是Red Hat项目)有很多共同点。例如，它们都在内部大量使用优秀的[*storage* (https://github.com/containers/storage)和[*image*](https://github.com/containers/image)库。在* crio *中直接使用*libpod*而不是*runc*，这似乎是一项正在进行的工作。*podman*的另一个有趣的特性是用drop-in替换一些(最流行的?)日常工作流程中的“docker”命令。该项目声称兼容(当然在一定程度上)的*docker CLI API*。

Why start a project like this when we already have *dockerd*, *containerd* or *cir-o*? The problem with daemons as container managers is that most of the time a daemon has to be run with *root* privileges. Even though 90% of the daemon's functionality can be hypothetically done without having *root* rights in the system since daemon is a monolithic thing, the remaining 10% requires that the daemon is launched as *root*. With *podman*, it's finally possible to have rootless containers utilizing Linux user namespaces. And this can be a big deal, especially in extensive CI or multi-tenant environments, because even non-privileged Docker containers are actually only [one kernel bug away from gaining root access](https://brauner.github.io/2019/02/12/privileged-containers.html) on the system.

既然我们已经有了*dockerd*、*containerd*或* ciro *，为什么还要启动这样的项目呢?守护进程作为容器管理器的问题是，守护进程大多数时候必须使用*root*特权运行。尽管由于守护进程是一个整体，假设系统中没有*root*权限就可以完成守护进程90%的功能，但是剩下的10%需要以*root*启动守护进程。使用*podman*，最终有可能使用Linux用户名称空间拥有无根容器。这可能是一个大问题，特别是在广泛的CI或多租户环境中，因为即使是非特权Docker容器实际上也只是系统上的一个内核错误(https://brauner.github.io/2019/02/12/privileged.containes.html)。

More information on this intriguing project can be found [here](http://crunchtools.com/podman-and-cri-o-in-rhel-8-and-openshift-4) and [here](https://www.redhat.com/en/blog/why-red-hat-investing-cri-o-and-podman).

关于这个有趣项目的更多信息可以在这里找到(http://crunchtools.com/podmanand -cri-o-in- rhel-8-andopenshift -4)和(https://www.redhat.com/en/blog/why-redhat-investing-cri-o -and-podman)。

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/podman.png)

#### conman

Here is my (WiP) [project](https://github.com/iximiuz/conman) aiming at the implementation of a tiny container manager. It's primarily for educational purposes, but the ultimate goal though is to make it CRI-compatible and launch a Kubernetes cluster with *conman* as a container runtime.

这是我的(WiP)[项目](https://github.com/iximiuz/conman)，目标是实现一个微型容器管理器。它主要用于教学目的，但是最终的目标是使它与cric兼容，并使用*conman*作为容器运行时启动Kubernetes集群。

### Runtime shims

If you try it yourself, you would find pretty quickly that using *runc* programmatically from a container manager is a quite tricky task. Following is a list of difficulties need to be addressed.

如果您亲自尝试一下，您会很快发现从容器管理器以编程方式使用*runc*是一项相当棘手的任务。以下是需要解决的困难清单。

#### Keep containers alive if container manager restarts

Containers can be long-running while a container manager may need to be restarted due to a crash, or update (or due to unforeseen reasons). It means that we need to make every container instance independent of the container manager process that has launched it. Luckily, *runc* provides a way to detach from a running container via `runc run --detach`. However, we might need to be able to [attach to a running container later on](https://iximiuz.com/en/posts/linux-pty-what-powers-docker-attach-functionality/). For that, *runc* can run a container controlled by a Linux pseudoterminal. However, the master side of the PTY is communicated back to a launching process by passing a PTY master file descriptor though Unix socket (see `runc create --console-socket` option). It means that we need to keep the launching process alive to hold the PTY file descriptor as long as the underlying container instance exists. If we decide to store the master PTY file descriptor in the container manager process, a restart of the manager will lead to loss of such file descriptor and thus to lose an ability to re-attach to running containers. It means that we need a dedicated (and lightweight) wrapper process responsible for the demonization and keeping the collateral state of a running container.

容器可以长时间运行，而容器管理器可能由于崩溃或更新(或由于无法预见的原因)而需要重新启动。这意味着我们需要使每个容器实例独立于启动它的容器管理器进程。幸运的是，*runc*提供了一种通过“runc run——detach”从正在运行的容器中分离的方法。但是，我们可能需要能够[稍后附加到一个正在运行的容器](https://iximiuz.com/en/posts/linux-pty-what-powers-docker-attach-functionality/)。为此，*runc*可以运行由Linux伪终端控制的容器。但是，通过通过Unix套接字传递PTY主文件描述符，可以将PTY的主端通信回启动进程(请参阅“runc create——console-socket”选项)。这意味着，只要底层容器实例存在，我们就需要保持启动进程的活动状态，以保存PTY文件描述符。如果我们决定在容器管理器进程中存储主PTY文件描述符，则重新启动该管理器将导致丢失该文件描述符，从而失去重新附加到正在运行的容器的能力。这意味着我们需要一个专用的(轻量级的)包装程序来负责妖魔化和保持运行容器的附属状态。

#### Synchronize container manager and wrapped runc instance

Since we have daemonized runc by adding a wrapper process, we need a side-channel (it might again be a Unix socket) to communicate the actual start of the container back to a container manager.

由于我们通过添加包装器进程对runc进行了daemon化，所以我们需要一个侧通道(也可能是Unix套接字)来将容器的实际开始部分通信回容器管理器。

#### Keep track of container exit code

Having containers detached leads to an absence of container status update. We need to have a way to communicate status back to the manager. For that purpose file system again sounds like a good option. We can teach our wrapper process to wait for the child *runc* process termination and then write its exit code to a predefined location on the disk.

分离容器会导致缺少容器状态更新。我们需要有一种方式将状态反馈给经理。出于这个目的，文件系统听起来也是一个不错的选择。我们可以教包装器进程等待子*runc*进程终止，然后将其退出代码写到磁盘上预定义的位置。

To address all these problems (and probably some other) so-called *runtime shims* are usually used. A shim is a lightweight daemon controlling a running container. Examples of the shims out there are [conmon](https://github.com/containers/conmon) and containerd [*runtime shim*](https://github.com/containerd/containerd/blob/master/runtime/v2/shim.go). I spent some time trying to implement my own shim as a part of the [*conman*](https://github.com/iximiuz/conman) project and the results can be found in the article ["Implementing container runtime shim"](https://iximiuz.com/en/posts/implementing-container-runtime-shim/).

为了解决所有这些问题(可能还有其他一些问题)，通常使用所谓的*运行时垫片*。shim是一个轻量级守护进程，控制一个正在运行的容器。shims的例子有[conmon](https://github.com/containers/conmon)和containerd [*runtime shim*](https://github.com/containerd/containerd/blob/master/runtime/v2/shim.go)。我花了一些时间来实现我自己的shim作为[*conman* (https://github.com/iximiuz/conman)项目的一部分，结果可以在文章[“实现容器运行时shim”(https://iximiuz.com/en/posts/implementing-container-runtime-shim/)中找到。

### Container Network Interface (CNI)

Since we have multiple container runtimes (or *managers*) with overlapping responsibilities it's pretty much obvious that we either need to extract networking-related code to a dedicated project and then reuse it, or each runtime should have its own way to configure NIC devices, IP routing, firewalls, and other networking aspects. For instance, both *cri-o* and *containerd* have to create Linux network namespaces and setup Linux `bridge`s and `veth` devices to create sandboxes for Kubernetes pods. To address this problem, [the Container Network Interface](https://github.com/containernetworking/cni) project was introduced.

因为我们有多个容器运行时(或* *经理)责任重叠的很明显,我们需要提取网络相关代码一个专门的项目,然后重用它,或每个运行时都应该有自己的方式来配置网卡设备,IP路由、防火墙和其他网络方面。例如，* crio *和*containerd*都必须创建Linux网络名称空间，并设置Linux ' bridge '和' veth '设备来为Kubernetes pods创建沙箱。为了解决这个问题，引入了[Container Network Interface](https://github.com/containernetworking/cni)项目。

The CNI project provides a [Container Network Interface Specification](https://github.com/containernetworking/cni/blob/master/SPEC.md) defining a CNI Plugin. A plugin is an *executable* [sic] which is supposed to be called by container runtime (or manager) to set up (or release) a network resource. Plugins can be used to create a network interface, manage IP addresses allocation, or do some custom configuration of the system. CNI project is language-agnostic, and since a plugin defined as an executable, it can be used in a runtime management system implemented in any programming language. However, CNI project also provides a set of reference plugin implementations for the most popular use cases shipped as a separate repository named [plugins](https://github.com/containernetworking/plugins). Examples are [bridge](https://github.com/containernetworking/plugins/tree/master/plugins/main/bridge), [loopback](https://github.com/containernetworking/plugins/tree/master/plugins/main/loopback), [flannel](https://github.com/containernetworking/plugins/tree/master/plugins/meta/flannel), etc.

CNI项目提供了一个定义CNI插件的[容器网络接口规范](https://github.com/containernetworking/cni/blob/master/SPEC.md)。插件是一个“可执行的”[sic]，容器运行时(或管理器)应该调用它来设置(或释放)网络资源。插件可以用来创建网络接口，管理IP地址分配，或者对系统进行一些自定义配置。CNI项目与语言无关，由于插件定义为可执行文件，所以它可以用于任何编程语言实现的运行时管理系统。然而，CNI项目还为作为一个名为[plugins]的单独存储库(https://github.com/containernetworking/plugins)交付的最流行用例提供了一组参考插件实现。例如[bridge](https://github.com/containernetworking/plugins/treins/main/bridge)、[loopback](https://github.com/containernetworking/plugins/master/plugins/main/loopback)、[flannel](https://github.com/containernetworking/plugins/treins/master/plugins/meta/flannel)等。

Some 3rd party projects implement their network-related functionality as CNI plugins. To name a few most famous things here we should mention [Project Calico](https://github.com/projectcalico/cni-plugin) and [Weave](https://github.com/weaveworks/weave).

一些第三方项目将其网络相关功能实现为CNI插件。为了列举一些最著名的项目，我们应该提到[Project Calico](https://github.com/projectcalico/cni-plugin)和[Weave](https://github.com/weaveworks/weave)。

## Orchestration

Orchestration of the containers is an extra-large topic. In reality, the biggest part of the Kubernetes code addresses rather the orchestration problem than containerization. Thus, orchestration deserves its own article (or a few). Hopefully, they will follow soon.

容器的编制是一个非常大的主题。实际上，Kubernetes代码中最大的部分解决的是编排问题，而不是容器化问题。因此，业务流程应该有自己的文章(或几篇)。希望他们能很快跟进。

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/orchestration.png)



## Notable projects

#### [buildah](https://github.com/containers/buildah)

Buildah is a command-line tool to work with [OCI container images](https://github.com/opencontainers/image-spec). It's a part of a group of projects (podman, skopeo, buildah) started by RedHat with an aim at redesigning Docker's way to work with containers (primarily to switch from monolithic and daemon-based to more fine-grained approach).

Buildah是一个命令行工具，用于处理[OCI容器映像](https://github.com/opencontainers/image-spec)。它是RedHat发起的一组项目(podman、skopeo、buildah)的一部分，目的是重新设计Docker处理容器的方法(主要是将单块和基于守护进程的方法转换为更细粒度的方法)。

#### [cni](https://github.com/containernetworking/cni)

CNI Project defines a Container Network Interface plugin specification as well as some Go tools to work with it. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#cni).

CNI项目定义了一个容器网络接口插件规范以及一些Go工具。有关更深入的解释，请参见相应的[文章的部分](https://iximiuz.com/en/posts/jourfrom - containerizationto -orchestra -and-beyond/#cni)。

#### [cni-plugins](https://github.com/containernetworking/plugins)

A home repository for the most popular CNI plugins (such as bridge, host-device, loopback, dhcp, firewall, etc). For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#cni).

一个最流行的CNI插件(如网桥、主机设备、环回、dhcp、防火墙等)的主库。有关更深入的解释，请参见相应的[文章的部分](https://iximiuz.com/en/posts/jourfrom - containerizationto -orchestra -and-beyond/#cni)。

#### [containerd](https://github.com/containerd/containerd)

A higher-level container runtime (or *container manager*) started as a part of Docker and extracted to an independent project. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#containerd).

高级容器运行时(或*容器管理器*)作为Docker的一部分启动，并提取到独立的项目中。有关更深入的解释，请参见相应的[文章的部分](https://iximiuz.com/en/posts/jourfrom - containerizationto -管弦乐队和beyond/#containerd)。

#### [conmon](https://github.com/containers/conmon)

A tiny OCI runtime shim written in C and used primarily by [cri-o](https://github.com/cri-o/cri-o). It provides synchronization between a parent process (cri-o) and the starting containers, tracking of container exit codes, PTY forwarding, and some other features. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#containerd).

一个用C语言编写的小型OCI运行时shim，主要由[crio](https://github.com/cri-o/cri-o)使用。它提供了父进程(crio)与启动容器之间的同步、容器出口代码的跟踪、PTY转发和其他一些功能。有关更深入的解释，请参见相应的[文章的部分](https://iximiuz.com/en/posts/jourfrom - containerizationto -管弦乐队和beyond/#containerd)。

#### [cri-o](https://github.com/cri-o/cri-o)

Kubernetes-focused container manager following Kubernetes Container Runtime Interface (CRI) specification. The versioning is same as k8s versioning. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#cri-o).

专注于Kubernetes容器管理器，遵循Kubernetes容器运行时接口(CRI)规范。版本控制与k8s版本控制相同。有关更深入的解释，请参见相应的[文章的部分](https://iximiuz.com/en/posts/jourfrom - containerizationto - -and-beyond/#cri-o)。

#### [crun](https://github.com/containers/crun)

Yet another OCI runtime spec implementation. It claims to be a "...fast and low-memory footprint OCI Container Runtime fully written in C." But the most importantly it can be used as a library from any C/C++ code (or providing bindings - from other languages). It allows avoiding some *runc* specific drawbacks caused by its daemon-nature. See [Runtime Shims](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#runtime-shims) section for more.

另一个OCI运行时规范实现。它声称是“……快速和低内存占用OCI容器运行时完全用c编写。但最重要的是，它可以用作任何C/ c++代码(或提供绑定——来自其他语言)的库。它允许避免一些由它的守护进程特性引起的特定的“runc”缺陷。有关更多信息，请参见[Runtime Shims](https://iximiuz.com/en/posts/jourfrom -container erizationto -and-beyond/# Runtime - Shims)一节。

#### [image](https://github.com/containers/image)

An underrated (warn: opinions!) Go library powered such well-known projects as *cri-o*, *podman* and *skopeo*. Probably it's easy to guess by its name - the aim is at working in various way with containers' images and container image registries.

一个被低估的(警告:意见!)Go library为* crio *、*podman*和*skopeo*等知名项目提供了支持。通过它的名称可能很容易猜到—其目的是用各种方式处理容器的映像和容器映像注册表。

#### [lxc](https://github.com/lxc/lxc)

An alternative and low-level container runtime written in C.

#### [lxd](https://github.com/lxc/lxd)

A higher-level container runtime (or *container manager*) written in Go. Under the hood, it uses *lxc* as low-level runtime.

#### [moby](https://github.com/moby/moby)

A higher-level container runtime (or *container manager*) formerly known as `docker/docker`. Provides a well-known Docker engine API based on *containerd* functionality. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#dockerd).

高级容器运行时(或*容器管理器*)，以前称为“docker/docker”。提供一个著名的基于*containerd*功能的Docker引擎API。有关更深入的解释，请参见相应的[文章的部分](https://iximiuz.com/en/posts/jourfrom - containerizationto - -and-beyond/#dockerd)。

#### [OCI distribution spec](https://github.com/opencontainers/distribution-spec)

A specification of a container image distribution (WiP).

#### [OCI image spec](https://github.com/opencontainers/image-spec)

A specification of a container image.

#### [OCI runtime spec](https://github.com/opencontainers/runtime-spec)

A specification of a [low level] container runtime.

#### [podman](https://github.com/containers/libpod)

A daemon-less Docker replacement. The frontman project of Docker redesign effort. More explanation can be found on [RedHat developers blog](https://developers.redhat.com/blog/2019/02/21/podman-and-buildah-for-docker-users/).

#### [rkt](https://github.com/rkt/rkt)

Another container management system. It provides a low-level runtime as well as a higher-level management interface. It advertises to be pod-native. An idea to add *rkt* support to Kubernetes gave birth to CRI specification. The project was started by CoreOS team ~5 years ago, but after its acquisition by RedHat, it is rather stagnating. As of August 2019, the last commit to the project is about 2 months old. **UPDATE**: On August, 16th, CNCF [announced](https://www.cncf.io/blog/2019/08/16/cncf-archives-the-rkt-project/) that the Technical Oversight Committee (TOC) has voted to archive the rkt project.

另一个容器管理系统。它提供了一个低层运行时和一个高层管理接口。它的广告是原生的。向Kubernetes添加*rkt*支持的想法催生了CRI规范。该项目由CoreOS团队于5年前启动，但在被RedHat收购后，却停滞不前。截止到2019年8月，该项目的最后一次承诺已经进行了大约两个月。**更新**:8月16日，CNCF[宣布](https://www.cncf.io/blog/2019/08/16/cncf- archives-rkt -project/)技术监督委员会(TOC)投票决定将rkt项目存档。

#### [runc](https://github.com/opencontainers/runc)

A low-level container runtime and a reference implementation of OCI runtime spec. Started as a part of Docker and extracted to an independent project. Extremely ubiquitous. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#container-runtimes).

一个低级容器运行时和OCI运行时规范的参考实现。作为Docker的一部分开始并提取到一个独立的项目中。非常普遍。有关更深入的解释，请参见相应的[文章的部分](https://iximiuz.com/en/posts/jourfrom - containerizationto -管弦乐队和beyond/#container-runtimes)。

#### [skopeo](https://github.com/containers/skopeo)

Skopeo is a command-line utility that performs various operations on container images and image repositories. It's a part of RedHat effort to redesign Docker (see also *podman* and *buildah*) by extracting its responsibilities to dedicated and independent tools.

Skopeo是一个命令行实用程序，它对容器映像和映像存储库执行各种操作。这是RedHat重新设计Docker(参见*podman*和*buildah*)工作的一部分，它将自己的职责分解为专用的和独立的工具。

#### [storage](https://github.com/containers/storage)

An underrated (warn: opinions!) Go library powered such well-known projects as *cri-o*, *podman* and *skopeo*. is a Go library which aims to provide methods for storing filesystem layers, container images, and containers (on disk). It also manages mounting of bundles.

一个被低估的(警告:意见!)Go library为* crio *、*podman*和*skopeo*等知名项目提供了支持。是一个Go库，目的是提供存储文件系统层、容器映像和容器(在磁盘上)的方法。它还管理捆绑包的安装。