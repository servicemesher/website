---
originallink: "https://aws.amazon.com/cn/blogs/aws/aws-app-mesh-application-level-networking-for-cloud-applications/"
author: "Jeff Barr"
date: "2019-09-07T10:42:00+08:00"
draft: false
banner: "/img/blog/banners/006tKfTcly1g0t1i9oxo4j31400u0npe.jpg"
translator: "马若飞"
translatorlink: "https://github.com/malphi"
reviewer:  ["罗广明"]
reviewerlink:  ["https://github.com/GuangmingLuo"]
title: "AWS App Mesh - 云应用的应用层网络"
description: "本文是一篇介绍容器运行时和管理工具的文章，对主要的容器管理工具做了介绍"
categories: ["Service Mesh"]
tags: ["Service Mesh"]
---

## 编者按

[AWS App Mesh](https://aws.amazon.com/app-mesh/) helps you to run and monitor HTTP and TCP services at scale. You get a consistent way to route and monitor traffic, giving you insight into problems and the ability to re-route traffic after failures or code changes. App Mesh uses the open source [Envoy](https://www.envoyproxy.io/) proxy, giving you access to a wide range of tools from AWS partners and the open source community.

AWS App Mesh可以帮助您大规模地运行和监视HTTP和TCP服务。您获得了一种一致的路由和监视流量的方法，使您能够洞察问题，并在失败或代码更改后重新路由流量。App Mesh使用开源的Envoy代理，让您可以访问来自AWS合作伙伴和开源社区的各种工具。

Services can run on [AWS Fargate](https://aws.amazon.com/fargate/), [Amazon EC2](https://aws.amazon.com/ec2/), [Amazon ECS](https://aws.amazon.com/ecs/), [Amazon Elastic Container Service for Kubernetes](https://aws.amazon.com/eks/), or [Kubernetes](https://aws.amazon.com/kubernetes/). All traffic in and out of the each service goes through the Envoy proxy so that it can be routed, shaped, measured, and logged. This extra level of indirection lets you build your services in any desired languages without having to use a common set of communication libraries.

服务可以运行在AWS Fargate、Amazon EC2、Amazon ECS、Amazon Elastic Container Services for Kubernetes或Kubernetes上。每个服务的所有进出流量都通过Envoy代理，以便对其进行路由、成形、测量和记录。这种额外的间接层让您可以用任何想要的语言构建服务，而不必使用一组公共的通信库。

## App Mesh Concepts

Before we dive in, let’s review a couple of important App Mesh concepts and components:

[**Service Mesh**](https://docs.aws.amazon.com/app-mesh/latest/userguide/meshes.html) – A a logical boundary for network traffic between the services that reside within it. A mesh can contain virtual services, virtual nodes, virtual routers, and routes.

[**Virtual Service**](https://docs.aws.amazon.com/app-mesh/latest/userguide/virtual_services.html) – An abstraction (logical name) for a service that is provided directly (by a virtual node) or indirectly (through a virtual router). Services within a mesh use the logical names to reference and make use of other services.

[**Virtual Node**](https://docs.aws.amazon.com/app-mesh/latest/userguide/virtual_nodes.html) – A pointer to a task group (an ECS service or a Kubernetes deployment) or a service running on one or more EC2 instances. Each virtual node can accept inbound traffic via **listeners**, and can connect to other virtual nodes via **backends**. Also, each node has a service discovery configuration (currently a DNS name) that allows other nodes to discover the IP addresses of the tasks, pods, or instances.

指向任务组(ECS服务或Kubernetes部署)或运行在一个或多个EC2实例上的服务的指针。每个虚拟节点都可以通过侦听器接受入站流量，并可以通过后端连接到其他虚拟节点。此外，每个节点都有一个服务发现配置(当前是DNS名称)，允许其他节点发现任务、pod或实例的IP地址。

[**Virtual Router**](https://docs.aws.amazon.com/app-mesh/latest/userguide/virtual_routers.html) – A handler for one or more virtual services within a mesh. Each virtual router listens for HTTP traffic on a specific port.

[**Route**](https://docs.aws.amazon.com/app-mesh/latest/userguide/routes.html) – Routes use prefix-based matching on URLs to route traffic to virtual nodes, with optional per-node weights. The weights can be used to test new service versions in production while gradually increasing the amount of traffic that they handle.

Putting it all together, each service mesh contains a set of services that can be accessed by URL paths specified by routes. Within the mesh, services refer to each other by name.

I can access App Mesh from the App Mesh Console, the App Mesh CLI, or the App Mesh API. I’ll show you how to use the Console and take a brief look at the CLI.

路由使用基于前缀的url匹配将流量路由到虚拟节点，每个节点都有可选的权重。权重可用于测试生产中的新服务版本，同时逐渐增加它们所处理的通信量。

把它们放在一起，每个服务网格包含一组服务，可以通过路由指定的URL路径访问这些服务。在网格中，服务通过名称相互引用。

我可以从App Mesh控制台、App Mesh CLI或App Mesh API访问App Mesh。我将向您展示如何使用控制台，并简要介绍CLI。

## Using the App Mesh Console

The console lets me create my service mesh and the components within it. I open the [App Mesh Console](https://console.aws.amazon.com/appmesh/landing-page) and click **Get started**:

![img](https://media.amazonwebservices.com/blog/2019/am_console_1.png)

I enter the name of my mesh and my first virtual service (I can add more later), and click **Next**:

![img](https://media.amazonwebservices.com/blog/2019/am_step1_2.png)

I define the first virtual node:

![img](https://media.amazonwebservices.com/blog/2019/am_step2_1.png)

I can click **Additional configuration** to specify service backends (other services that this one can call) and logging:

![img](https://media.amazonwebservices.com/blog/2019/am_step2_p2_2.png)

I define my node’s listener via protocol (HTTP or TCP) and port, set up an optional health check, and click **Next**:

![img](https://media.amazonwebservices.com/blog/2019/am_step2_p3_1.png)

Next, I define my first virtual router and a route for it:

![img](https://media.amazonwebservices.com/blog/2019/am_step3_p1_1.png)

I can apportion traffic across several virtual nodes (targets) on a percentage basis, and I can use prefix-based routing for incoming traffic:

![img](https://media.amazonwebservices.com/blog/2019/am_step3_p2_1.png)

I review my choices and click **Create mesh service**:

![img](https://media.amazonwebservices.com/blog/2019/am_review_1.png)

The components are created in a few seconds and I am just about ready to go:

![img](https://media.amazonwebservices.com/blog/2019/am_ready_1.png)

The final step, as described in the [App Mesh Getting Started Guide](https://docs.aws.amazon.com/app-mesh/latest/userguide/getting_started.html), is to update my task definitions (Amazon ECS or AWS Fargate) or pod specifications (Amazon EKS or Kubernetes) to reference the Envoy container image and the proxy container image. If my service is running on an EC2 instance, I will need to deploy Envoy there.

## Using the AWS App Mesh Command Line

App Mesh lets you specify each type of component in a simple JSON form and provides you with [command-line tools](https://docs.aws.amazon.com/cli/latest/reference/appmesh/) to create each one (`create-mesh`, `create-virtual-service`, `create-virtual-node`, and `create-virtual-router`). For example, I can define a virtual router in a file:

```bash
{
  "meshName": "mymesh",
  "spec": {
        "listeners": [
            {
                "portMapping": {
                    "port": 80,
                    "protocol": "http"
                }
            }
        ]
    },
  "virtualRouterName": "serviceA"
}
```

And create it with one command:

```bash
$ aws appmesh create-virtual-router --cli-input-json file://serviceA-router.json
```

## Now Available

AWS App Mesh is available now and you can start using it today in the US East (N. Virginia), US East (Ohio), US West (Oregon), US West (N. California), Canada (Central), Europe (Ireland), Europe (Frankfurt), Europe (London), Asia Pacific (Mumbai), Asia Pacific (Tokyo), Asia Pacific (Sydney), Asia Pacific (Singapore), and Asia Pacific (Seoul) Regions today.

AWS应用网现在是可用的,你可以今天开始使用它在美国东部(n维吉尼亚),美国东部(俄亥俄州),美国西部(俄勒冈州),美国西部加州(n),加拿大(中央)、欧洲(爱尔兰),欧洲(法兰克福),欧洲(伦敦)亚太(孟买)亚太(东京)亚太(悉尼)、亚太(新加坡),今天和亚太(首尔)地区。