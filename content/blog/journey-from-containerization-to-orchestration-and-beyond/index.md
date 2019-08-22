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

## Container Runtimes

I want to start the journey from the lowest level non-kernel primitive - **container runtime**. The word *runtime* is a bit ambiguous in the containerverse. Each project, company or community has its own and usually context-specific understanding of the term *container runtime*. Mostly, the hallmark of the runtime is defined by the set of responsibilities varying from a bare minimum (creating namespaces, starting *init*process) to comprehensive container management including (but not limiting) images operation. A good overview of runtimes can be found in [this article](https://www.ianlewis.org/en/container-runtimes-part-1-introduction-container-r).

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/runtime-levels.png)

This section is dedicated to *low-level container runtimes*. A group of big players forming an [Open Container Initiative](https://www.opencontainers.org/) standartized the low-level runtime in the [*OCI runtime specification*](https://github.com/opencontainers/runtime-spec). Making a long story short - a low-level container runtime is a piece of software that takes as an input a folder containing rootfs and a configuration [file] describing container parameters (such as resource limits, mount points, process to start, etc) and as a result the runtime starts an isolated process, i.e. container.

As of 2019, the most widely used container runtime is [runc](https://github.com/opencontainers/runc). This project started as a part of Docker (hence it's written in Go) but eventually was extracted and transformed into a self-sufficient CLI tool. It is difficult to overestimate the importance of this component - *runc* is basically a reference implementation of the OCI runtime specification. During our journey we will work a lot with *runc* and here is [an introductory article](https://iximiuz.com/en/posts/implementing-container-runtime-shim/).

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/runc.png)



One more notable OCI runtime implementation out there is [crun](https://github.com/containers/crun). It's written in C and can be used both as an executable and as a library.

## Container management

Using *runc* in command line we can launch as many containers as we want. But what if we need to automate this process? Imagine we need to launch tens of containers keeping track of their statuses. Some of them need to be restarted on failure, resources need to be released on termination, images have to be pulled from registries, inter-containers networks need to be configured and so on. This is already a slightly higher-level job and it's a responsibility of a *container manager*. To be honest, I have no idea whether this term is in common use or not, but I found it convenient to structure things this way. I would classify the following projects as *container managers*: [containerd](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#containerd), [cri-o](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#cri-o), [dockerd](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#dockerd), and [podman](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#dockerd).

#### containerd

As with *runc*, we again can see a Docker's heritage here - [*containerd*](https://github.com/containerd/containerd) used to be a part of the original Docker project. Nowadays though *containerd* is another self-sufficient piece of software. It calls itself a container runtime but obviously, it's not the same kind of runtime *runc* is. Not only the responsibilities of *containerd* and *runc* differ but also the organizational form does. While *runc* is a just a command-line tool, *containerd* is a long-living daemon. An instance of *runc* cannot outlive an underlying container process. Normally it starts its life on `create` invocation and then just [`exec`](https://linux.die.net/man/3/exec)s the specified file from container's rootfs on `start`. On the other hand, *containerd* can outlive thousands of containers. It's rather a server listening for incoming requests to start, stop, or report the status of the containers. And under the hood *containerd* uses *runc*. However, *containerd* is more than just a container lifecycle manager. It is also responsible for image management (pull & push images from a registry, store images locally, etc), cross-container networking management and some other functions.

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/containerd.png)



#### cri-o

Another container manager example is [cri-o](https://github.com/cri-o/cri-o). While *containerd* evolved as a result of Docker re-architecting, *cri-o* has its roots in the Kubernetes realm. Back in the day, Kubernetes (ab)used Docker to manage containers. However, with rising of [rkt](https://github.com/rkt/rkt) some brave people added support of interchangeably container runtimes in Kubernetes, allowing container management to be done by Docker and/or rkt. This change, however, led to a huge number of conditional code in Kubernetes and nobody likes too many `if`s in the code. As a result, [Container Runtime Interface (CRI)](https://kubernetes.io/blog/2016/12/container-runtime-interface-cri-in-kubernetes/) has been introduced to Kubernetes making it possible to any CRI-compliant higher-level runtimes (i.e. container managers) to be used without any code change on the Kubernetes side. And *cri-o* is a Red Hat's implementation of CRI-complaint runtime. As with *containerd* *cri-o* is also a daemon exposing a [gRPC] server with endpoints to create, start, stop (and many more other actions) containers. Under the hood, *cri-o* can use any OCI-compliant [low-level] runtimes to work with containers but the default one is ~~again~~ *runc*. The main focus of *cri-o* is being a Kubernetes container runtime. The versioning is the same as k8s versioning, the scope of the project is well-defined and the code base is expectedly smaller (as of July 2019 it's around 20 CLOC and it's approximately 5 times less than *containerd*).

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/cri-o.png)

*cri-o architecture (image from cri-o.io)*

The nice thing about specifications is that everything complaint can be used interchangeably. Once CRI has been introduced, a plugin for *containerd*, implementing CRI gRPC server on top of containerd's functionality appeared. The idea happened to be viable and later on, *containerd* itself got a native CRI support. Thus, Kubernetes can use both *cri-o* and *containerd* as a runtime.

#### dockerd

One more daemon here is [*dockerd*](https://github.com/moby/moby/tree/master/cmd/dockerd). This daemon is manifold. On the one hand, it exposes an API for [Docker command-line client](https://github.com/docker/cli) which gives us all these famous Docker workflows (`docker pull`, `docker push`, `docker run`, `docker stats`, etc). But since we already know, that this piece of functionality has been extracted to *containerd* it's not a surprise that under the hood *dockerd* relies on *containerd*. But that basically would mean that *dockerd* is just a front-end adapter converting *containerd* API to a historically widely used *docker engine* API.

However, [*dockerd*](https://github.com/moby/moby) also provides `compose` and *swarm* things in an attempt to solve container orchestration problem, including multi-machine clusters of containers. As we can see with Kubernetes, this problem is rather hard to address. And having two big responsibilities for a single *dockerd* daemon doesn't sound good to me.

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/dockerd.png)

*dockerd is a part in front of containerd (image from Docker Blog)*



#### podman

An interesting exception from this daemons list is [*podman*](https://github.com/containers/libpod). It's yet another Red Hat project and the aim is to provide a library (not a daemon) called `libpod` to manage images, container lifecycles, and pods (groups of containers). And `podman` is a management command-line tool built on top of this library. As a low-level container runtime this project ~~as usual~~ uses *runc*. There is a lot in common between *podman*and *cri-o* (both are Red Hat projects) from the code standpoint. For instance, they both heavily use outstanding [*storage*](https://github.com/containers/storage) and [*image*](https://github.com/containers/image) libraries internally. It seems that there's an ongoing effort to use *libpod*instead of *runc* directly in *cri-o*. Another interesting feature of *podman* is a drop-in replacement of some (most popular?) `docker` commands in a daily workflow. The project claims compatibility (to some extent of course) of the *docker CLI API*.

Why start a project like this when we already have *dockerd*, *containerd* or *cir-o*? The problem with daemons as container managers is that most of the time a daemon has to be run with *root* privileges. Even though 90% of the daemon's functionality can be hypothetically done without having *root* rights in the system since daemon is a monolithic thing, the remaining 10% requires that the daemon is launched as *root*. With *podman*, it's finally possible to have rootless containers utilizing Linux user namespaces. And this can be a big deal, especially in extensive CI or multi-tenant environments, because even non-privileged Docker containers are actually only [one kernel bug away from gaining root access](https://brauner.github.io/2019/02/12/privileged-containers.html) on the system.

More information on this intriguing project can be found [here](http://crunchtools.com/podman-and-cri-o-in-rhel-8-and-openshift-4) and [here](https://www.redhat.com/en/blog/why-red-hat-investing-cri-o-and-podman).

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/podman.png)

#### conman

Here is my (WiP) [project](https://github.com/iximiuz/conman) aiming at the implementation of a tiny container manager. It's primarily for educational purposes, but the ultimate goal though is to make it CRI-compatible and launch a Kubernetes cluster with *conman* as a container runtime.

### Runtime shims

If you try it yourself, you would find pretty quickly that using *runc* programmatically from a container manager is a quite tricky task. Following is a list of difficulties need to be addressed.

#### Keep containers alive if container manager restarts

Containers can be long-running while a container manager may need to be restarted due to a crash, or update (or due to unforeseen reasons). It means that we need to make every container instance independent of the container manager process that has launched it. Luckily, *runc* provides a way to detach from a running container via `runc run --detach`. However, we might need to be able to [attach to a running container later on](https://iximiuz.com/en/posts/linux-pty-what-powers-docker-attach-functionality/). For that, *runc* can run a container controlled by a Linux pseudoterminal. However, the master side of the PTY is communicated back to a launching process by passing a PTY master file descriptor though Unix socket (see `runc create --console-socket` option). It means that we need to keep the launching process alive to hold the PTY file descriptor as long as the underlying container instance exists. If we decide to store the master PTY file descriptor in the container manager process, a restart of the manager will lead to loss of such file descriptor and thus to lose an ability to re-attach to running containers. It means that we need a dedicated (and lightweight) wrapper process responsible for the demonization and keeping the collateral state of a running container.

#### Synchronize container manager and wrapped runc instance

Since we have daemonized runc by adding a wrapper process, we need a side-channel (it might again be a Unix socket) to communicate the actual start of the container back to a container manager.

#### Keep track of container exit code

Having containers detached leads to an absence of container status update. We need to have a way to communicate status back to the manager. For that purpose file system again sounds like a good option. We can teach our wrapper process to wait for the child *runc* process termination and then write its exit code to a predefined location on the disk.

To address all these problems (and probably some other) so-called *runtime shims* are usually used. A shim is a lightweight daemon controlling a running container. Examples of the shims out there are [conmon](https://github.com/containers/conmon) and containerd [*runtime shim*](https://github.com/containerd/containerd/blob/master/runtime/v2/shim.go). I spent some time trying to implement my own shim as a part of the [*conman*](https://github.com/iximiuz/conman) project and the results can be found in the article ["Implementing container runtime shim"](https://iximiuz.com/en/posts/implementing-container-runtime-shim/).

### Container Network Interface (CNI)

Since we have multiple container runtimes (or *managers*) with overlapping responsibilities it's pretty much obvious that we either need to extract networking-related code to a dedicated project and then reuse it, or each runtime should have its own way to configure NIC devices, IP routing, firewalls, and other networking aspects. For instance, both *cri-o* and *containerd* have to create Linux network namespaces and setup Linux `bridge`s and `veth` devices to create sandboxes for Kubernetes pods. To address this problem, [the Container Network Interface](https://github.com/containernetworking/cni) project was introduced.

The CNI project provides a [Container Network Interface Specification](https://github.com/containernetworking/cni/blob/master/SPEC.md) defining a CNI Plugin. A plugin is an *executable* [sic] which is supposed to be called by container runtime (or manager) to set up (or release) a network resource. Plugins can be used to create a network interface, manage IP addresses allocation, or do some custom configuration of the system. CNI project is language-agnostic, and since a plugin defined as an executable, it can be used in a runtime management system implemented in any programming language. However, CNI project also provides a set of reference plugin implementations for the most popular use cases shipped as a separate repository named [plugins](https://github.com/containernetworking/plugins). Examples are [bridge](https://github.com/containernetworking/plugins/tree/master/plugins/main/bridge), [loopback](https://github.com/containernetworking/plugins/tree/master/plugins/main/loopback), [flannel](https://github.com/containernetworking/plugins/tree/master/plugins/meta/flannel), etc.

Some 3rd party projects implement their network-related functionality as CNI plugins. To name a few most famous things here we should mention [Project Calico](https://github.com/projectcalico/cni-plugin) and [Weave](https://github.com/weaveworks/weave).

## Orchestration

Orchestration of the containers is an extra-large topic. In reality, the biggest part of the Kubernetes code addresses rather the orchestration problem than containerization. Thus, orchestration deserves its own article (or a few). Hopefully, they will follow soon.

![img](https://iximiuz.com/journey-from-containerization-to-orchestration-and-beyond/orchestration.png)



## Notable projects

#### [buildah](https://github.com/containers/buildah)

Buildah is a command-line tool to work with [OCI container images](https://github.com/opencontainers/image-spec). It's a part of a group of projects (podman, skopeo, buildah) started by RedHat with an aim at redesigning Docker's way to work with containers (primarily to switch from monolithic and daemon-based to more fine-grained approach).

#### [cni](https://github.com/containernetworking/cni)

CNI Project defines a Container Network Interface plugin specification as well as some Go tools to work with it. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#cni).

#### [cni-plugins](https://github.com/containernetworking/plugins)

A home repository for the most popular CNI plugins (such as bridge, host-device, loopback, dhcp, firewall, etc). For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#cni).

#### [containerd](https://github.com/containerd/containerd)

A higher-level container runtime (or *container manager*) started as a part of Docker and extracted to an independent project. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#containerd).

#### [conmon](https://github.com/containers/conmon)

A tiny OCI runtime shim written in C and used primarily by [cri-o](https://github.com/cri-o/cri-o). It provides synchronization between a parent process (cri-o) and the starting containers, tracking of container exit codes, PTY forwarding, and some other features. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#containerd).

#### [cri-o](https://github.com/cri-o/cri-o)

Kubernetes-focused container manager following Kubernetes Container Runtime Interface (CRI) specification. The versioning is same as k8s versioning. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#cri-o).

#### [crun](https://github.com/containers/crun)

Yet another OCI runtime spec implementation. It claims to be a "...fast and low-memory footprint OCI Container Runtime fully written in C." But the most importantly it can be used as a library from any C/C++ code (or providing bindings - from other languages). It allows avoiding some *runc* specific drawbacks caused by its daemon-nature. See [Runtime Shims](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#runtime-shims) section for more.

#### [image](https://github.com/containers/image)

An underrated (warn: opinions!) Go library powered such well-known projects as *cri-o*, *podman* and *skopeo*. Probably it's easy to guess by its name - the aim is at working in various way with containers' images and container image registries.

#### [lxc](https://github.com/lxc/lxc)

An alternative and low-level container runtime written in C.

#### [lxd](https://github.com/lxc/lxd)

A higher-level container runtime (or *container manager*) written in Go. Under the hood, it uses *lxc* as low-level runtime.

#### [moby](https://github.com/moby/moby)

A higher-level container runtime (or *container manager*) formerly known as `docker/docker`. Provides a well-known Docker engine API based on *containerd* functionality. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#dockerd).

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

#### [runc](https://github.com/opencontainers/runc)

A low-level container runtime and a reference implementation of OCI runtime spec. Started as a part of Docker and extracted to an independent project. Extremely ubiquitous. For a more in-depth explanation see the corresponding [section of the article](https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/#container-runtimes).

#### [skopeo](https://github.com/containers/skopeo)

Skopeo is a command-line utility that performs various operations on container images and image repositories. It's a part of RedHat effort to redesign Docker (see also *podman* and *buildah*) by extracting its responsibilities to dedicated and independent tools.

#### [storage](https://github.com/containers/storage)

An underrated (warn: opinions!) Go library powered such well-known projects as *cri-o*, *podman* and *skopeo*. is a Go library which aims to provide methods for storing filesystem layers, container images, and containers (on disk). It also manages mounting of bundles.