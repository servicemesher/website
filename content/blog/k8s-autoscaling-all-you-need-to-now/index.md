---
title: "你必知的Kubernetes 自动缩放"
date: 2019-09-20T20:50:15+08:00
---

<!-- 
Many Kubernetes users, especially those at enterprise level, swiftly come across the need to autoscale environments. Fortunately, the K8s Horizontal Pod Autoscaler (HPA) allows you to configure your deployments to scale horizontally in a myriad number of ways to do just that. One of the biggest advantages of using Kube Autoscaling is that your Cluster can track the load capabilities of your existing Pods and calculate if more Pods are required or not.
-->
许多Kubernetes用户，特别是那些企业级用户，很快就遇到了对环境自动缩放的需求。幸运的是，K8s Horizo​​ntal Pod Autoscaler（HPA）允许您将部署配置为以多种方式水平扩展。使用Kube Autoscaling的最大优势之一是您的集群可以跟踪现有Pod的加载能力，并计算是否需要更多的Pod。

## Kubernetes Autoscaling

<!-- 
Leverage efficient Kubernetes Autoscaling by harmonizing the two layers of scalability on offer:

1 – Autoscaling at Pod level: This plane includes the Horizontal Pod Autoscaler (HPA) and Vertical Pod Autoscaler (VPA); both of which scale your containers available resources

2 – Autoscaling at Cluster level: The Cluster Autoscaler (CA) manages this plane of scalability by scaling the number of nodes inside your Cluster up or down as necessary
-->

通过协调内置的两层可扩展性，可以充分利用高效的Kubernetes Autoscaling：

1 - Pod级别的自动缩放：包括Horizo​​ntal Pod Autoscaler（HPA）和Vertical Pod Autoscaler（VPA）; 两者都可以扩展容器
的可用资源

2 - 集群级别的自动缩放：集群自动调节器（CA）通过在必要时向上或向下扩展集群内的节点数来管理这种可扩展性平面


## Kubernetes Autoscaling 详情：

### Horizo​​ntal Pod Autoscaler（HPA）

<!-- 
HPA scales the number of Pod replicas for you in your Cluster. The move is triggered by CPU or memory to scale up or down as necessary. However, it’s possible to configure HPA to scale Pods according to varied, external, and custom metrics (metrics.k8s.io, external.metrics.k8s.io, and custom.metrics.k8s.io). 
-->
HPA会在集群中为您缩放Pod副本的数量。该操作由CPU或内存触发，以根据需要向上或向下扩展。但是，也可以根据各种外部的和自定义指标（metrics.k8s.io，external.metrics.k8s.io和custom.metrics.k8s.io）来配置HPA以扩展Pod。

### Vertical Pod Autoscaler（VPA）

<!-- 
Built predominantly for stateful services, VPA adds CPU or memory to Pods as required—it also works for both stateful and stateless Pods too though. To make these changes, VPA restarts Pods to update new CPU and memory resources, which can be configured to set off in reaction to OOM (out of memory) events. Upon restarting Pods, VPA always ensures there is the minimum number according to the Pods Distribution Budget (PDB) which you can set along with a resource allocation maximum and minimum rate. 
-->
VPA主要用于有状态服务，它可根据需要为Pod添加CPU或内存 - 它也适用于无状态的Pod。为了应用这些更改，VPA重新启动Pod以更新新的CPU和内存资源，这些资源可以配置为响应OOM（内存不足）事件而启动。重新启动Pod的时候，VPA始终确保根据Pod分配预算（PDB）确定最小数量，您可以设置该资源分配最大和最小速率。

### Cluster Autoscaler（CA）
<!-- 
The second layer of autoscaling involves CA, which automatically adjusts the size of the cluster when:
– Any Pod/s fail to run and fall into a pending state due to insufficient capacity in the Cluster (in which case CA will scale up).
– Nodes in the cluster have been underutilized for a certain period of time and there is a chance to relocate their pods on reaming nodes (in which case CA will scale down).

CA makes routine checks to determine whether any pods are in a pending state waiting for extra resources or if Cluster nodes are being underutilized. The function then adjusts the number of Cluster nodes accordingly if more resources are required. CA interacts with the cloud provider to request additional nodes or shut down idle ones and ensures the scaled-up Cluster remains within the limitations set by the user. It works with AWS, Azure, and GCP. 
-->

第二层的自动缩放涉及CA，它在以下情况下自动调整集群的大小：

- 由于集群中的容量不足，任何Pod/s都无法运行并进入挂起状态（在这种情况下，CA将向上扩展）。

- 集群中的节点在一段时间内未得到充分利用，并且有可能迁移POD在节点上（在这种情况下，CA将缩小）。

CA进行例行检查以确定是否有任何pod因等待额外资源处于待定状态，或者集群节点是否未得到充分利用。如果需要更多资源，会相应地调整Cluster节点的数量。CA与云提供商交互以请求其他节点或关闭空闲节点，并确保按比例放大的集群保持在用户设置的限制范围内。它适用于AWS，Azure和GCP。

## 将HPA和CA与Amazon EKS配合使用的5个步骤

<!-- This article offers a step-by-step guide to installing and autoscaling through HPA and CA with an Amazon Elastic Container Service for Kubernetes (Amazon EKS) Cluster. Following the guidelines are two test use case examples to show the features in situ: -->

本文提供了通过适用于Kubernetes（Amazon EKS）集群的Amazon Elastic容器服务，通过HPA和CA安装和自动扩展的分步指南。以下指南是两个测试用例示例：

### 集群要求:

<!-- An [Amazon VPC](https://docs.aws.amazon.com/eks/latest/userguide/create-public-private-vpc.html) and a dedicated security group that meets the necessary set-up for an Amazon EKS Cluster.
Alternatively, to avoid a manual step-by-step VPC creation, AWS provides a CloudFormation stack which creates a VPC for EKS here.
The stack is highlighted here.

An Amazon EKS service role to apply to your Cluster. -->

* 满足EKS集群要求的Amazon VPC 和 一个安全组

* 或者，为免手动创建VPC，AWS提供了创建了VPC和EKS的[CloudFormation模板](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

[CloudFormation YAML文件](https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2018-08-30/amazon-eks-vpc-sample.yaml)

* 应用到集群的[EKS 角色]https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html


<!-- 1- Create an AWS EKS Cluster (control plane and workers) in line with the official instructions here. Once you launch an Auto Scaling group of worker nodes they can register to your Amazon EKS Cluster and you can begin deploying Kube applications to them.

2- Deploy a Metrics Server so that HPA can scale Pods in a deployment based on CPU/memory data provided by an API (as described above). The metrics.k8s.io API is usually provided by the metrics-server (which collects the CPU and memory metrics from the Summary API, as exposed by Kubelet on each node).

3- Add the following policy to the Role created by EKS for the K8S workers & nodes (this is for the K8S CA to work alongside the AWS Autoscaling Group (AWS AG)).
-->

1- 根据[官方指南](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html)创建一个AWS EKS 集群(控制面板和和工作节点). 一旦你把工作节点以auto scaling group的形式启动了，它们会自动向EKS集群注册，你就可以开始部署k8s应用了。

2- 部署度量服务器以便HPA能够根据API提供的CPU/内存数据自动缩放POD副本的数量。 metrics.k8s.io api 通常由metrics-server（负责从summary api收集cpu和内存度量）提供。

3- 把以下策略应用到EKS创建的worker节点的Role上

```
{
"Version": "2012-10-17",
"Statement": [
{
"Effect": "Allow",
"Action": [
"autoscaling:DescribeAutoScalingGroups",
"autoscaling:DescribeAutoScalingInstances",
"autoscaling:DescribeLaunchConfigurations",
"autoscaling:DescribeTags",
"autoscaling:SetDesiredCapacity",
"autoscaling:TerminateInstanceInAutoScalingGroup"
],
"Resource": "*"
}
]
}
```

4- [部署k8s CA特性](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml)

> 根据你使用的linux发行版，你可能需要更新部署文件和证书路径。 例如，如果使用AMI Linux，需要用/etc/ssl/certs/ca-bundle.crt替换/etc/ssl/certs/ca-certificates.crt

5- 更新CA的部署YAML文件，找到指定的AWS AG（k8s.io/cluster-autoscaler/<`CLUSTER NAME`>应该包含真实的集群名称）标签。
同时更新`AWS_REGION`环境变量。

把以下tag添加到 AWS AG， 以便 k8s 的 cluster autoscaler 能够自动识别 AWS AG：
  > k8s.io/cluster-autoscaler/enabled
  > k8s.io/cluster-autoscaler/


### Kubernetes Autoscaling 测试用例 #1

测试k8s hpa 特性和k8s ca 特性同时使用

要求:

– 一个运行中的eks集群
– 安装好metric server 
– 安装了k8s cluster autoscaler 特性

1- 部署一个测试app，为app部署创建HPA资源

2- 从不同的地理位置发起请求以增加负载

3- HPA 应该会随着负载的增加开始缩放pod的数量。它会根据hpa资源指定的进行缩放的。在某一时刻，新的POD在等待其他资源的时候会是等待状态。

```
$ kubectl get nodes -w
NAME                             STATUS    ROLES     AGE       VERSION
ip-192-168-189-29.ec2.internal   Ready         1h        v1.10.3
ip-192-168-200-20.ec2.internal   Ready         1h        v1.10.3
```

```
$ kubectl get Pods -o wide -w
NAME READY STATUS RESTARTS AGE IP NODE
ip-192-168-200-20.ec2.internal
php-apache-8699449574-4mg7w 0/1 Pending 0 17m
php-apache-8699449574-64zkm 1/1 Running 0 1h 192.168.210.90 ip-192-168-200-20
php-apache-8699449574-8nqwk 0/1 Pending 0 17m
php-apache-8699449574-cl8lj 1/1 Running 0 27m 192.168.172.71 ip-192-168-189-29
php-apache-8699449574-cpzdn 1/1 Running 0 17m 192.168.219.71 ip-192-168-200-20
php-apache-8699449574-dn9tb 0/1 Pending 0 17m
...
```

4- CA 检测到因为容量不足而进入等待状态的pods，调整AWS 自动缩放组的大小。一个新的节点加入了:

```
$ kubectl get nodes -w
NAME                                       STATUS    ROLES     AGE       VERSION
ip-192-168-189-29.ec2.internal   Ready         2h        v1.10.3
ip-192-168-200-20.ec2.internal   Ready         2h        v1.10.3
ip-192-168-92-187.ec2.internal   Ready         34s       v1.10.3
```

5- HPA能够把等待状态的POD调度到新的节点上了。 平均cpu使用率低于指定的目标，没有必要再调度新的pod了。

```
$ kubectl get hpa
NAME         REFERENCE                    TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   40%/50%   2                  25                 20               1h $ kubectl get Pods -o wide -w
```

```
$ kubectl get Pods -o wide -w
NAME READY STATUS RESTARTS AGE IP NODE
php-apache-8699449574-4mg7w 1/1 Running 0 25m 192.168.74.4 ip-192-168-92-187
php-apache-8699449574-64zkm 1/1 Running 0 1h 192.168.210.90 ip-192-168-200-20
php-apache-8699449574-8nqwk 1/1 Running 0 25m 192.168.127.85 ip-192-168-92-187
php-apache-8699449574-cl8lj 1/1 Running 0 35m 192.168.172.71 ip-192-168-189-29
...
```

6- 关闭几个terminal，停掉一些负载

7- CPU平均利用率减小了， 所以HPA开始更改部署里的pod副本数量并杀掉一些pods

```
$ kubectl get hpa
NAME         REFERENCE                     TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   47%/50%     2                20                 7                   1h 

$ kubectl get Pods -o wide -w
NAME READY STATUS RESTARTS AGE IP NODE
...
php-apache-8699449574-v5kwf 1/1 Running 0 36m 192.168.250.0 ip-192-168-200-20
php-apache-8699449574-vl4zj 1/1 Running 0 36m 192.168.242.153 ip-192-168-200-20
php-apache-8699449574-8nqwk 1/1 Terminating 0 26m 192.168.127.85 ip-192-168-92-187
php-apache-8699449574-dn9tb 1/1 Terminating 0 26m 192.168.124.108 ip-192-168-92-187
php-apache-8699449574-k5ngv 1/1 Terminating 0 26m 192.168.108.58 ip-192-168-92-187
...
```

8- CA 检测到一个节点未充分使用，正在运行的pods能够调度到其他节点上。 

```
$ kubectl get nodes
NAME                             STATUS    ROLES     AGE       VERSION
ip-192-168-189-29.ec2.internal   Ready         2h        v1.10.3
ip-192-168-200-20.ec2.internal   Ready         2h        v1.10.3
ip-192-168-92-187.ec2.internal   NotReady       23m       v1.10.3

$ kubectl get nodes
NAME                             STATUS    ROLES     AGE       VERSION
ip-192-168-189-29.ec2.internal   Ready         2h        v1.10.3
ip-192-168-200-20.ec2.internal   Ready         2h        v1.10.3
```

9- 在向下缩放的时候，terminal中应该没有明显的timeout

### Kubernetes Autoscaling 测试用例 #2

测试在如果没有足够的CPU容量调度pod下，CA是否能够自动调整集群的大小

要求:

– 一个运行中的aws eks集群

– k8s ca 特性已安装

1- 创建2个请求小于1vcpu的deployment

```
$ kubectl run nginx --image=nginx:latest --requests=cpu=200m
$ kubectl run nginx2 --image=nginx:latest --requests=cpu=200m
```

2- 创建一个新的deployment，请求比剩余的cpu更多的资源

```
$ kubectl run nginx3 --image=nginx:latest --requests=cpu=1
```

3- 新的POD会处于等待状态，因为没有可用的资源：

```
$ kubectl get Pods -w
NAME                      READY     STATUS    RESTARTS   AGE
nginx-5fcb54784c-lcfht    1/1       Running   0          13m
nginx2-66667bf959-2fmlr   1/1       Running   0          3m
nginx3-564b575974-xcm5t   0/1       Pending   0          41s
```

描述pod的时候，可能会看到没有足够的cpu的事件

```
$ kubectl describe Pod nginx3-564b575974-xcm5t
…..
…..
Events:
Type     Reason            Age               From               Message
----     ------            ----              ----               -------
Warning  FailedScheduling  32s (x7 over 1m)  default-scheduler  0/1 nodes are available: 1 Insufficient cpu
```

4- CA自动调整集群的大小， 新加了一个节点

```
$ kubectl get nodes
NAME                              STATUS    ROLES     AGE       VERSION
ip-192-168-142-179.ec2.internal   Ready         1m        v1.10.3  <<
ip-192-168-82-136.ec2.internal     Ready         1h        v1.10.3
```

5- 集群现在有了足够的资源以运行pod

```
$ kubectl get Pods
NAME                      READY     STATUS    RESTARTS   AGE
nginx-5fcb54784c-lcfht    1/1       Running   0          48m
nginx2-66667bf959-2fmlr   1/1       Running   0          37m
nginx3-564b575974-xcm5t   1/1       Running   0          35m
```

6- 两个部署删除了。 一段时间后，CA检测到集群中的一个节点未被充分利用，运行的pod可以安置到其他存在的节点上。 AWS AG 更新，节点数量减1。

```
$ kubectl get nodes
NAME                                      STATUS    ROLES     AGE       VERSION
ip-192-168-82-136.ec2.internal   Ready         1h          v1.10.3 

$ kubectl get Pods -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP                       NODE
nginx-5fcb54784c-lcfht   1/1       Running     0                   1h       192.168.98.139   ip-192-168-82-136
```

清除环境的步骤:

1- 删除添加到eks worker节点上Role的自定义策略

2- 按照这个[指南](https://docs.aws.amazon.com/eks/latest/userguide/delete-cluster.html)删除这个集群

其他的关于kubernetes autoscaling，可以阅读Stefan Prodan的文章 [Kubernetes Horizontal Pod Autoscaler with Prometheus Custom Metrics](https://github.com/stefanprodan/k8s-prom-hpa)

还有这些链接也可以看看 [link1](https://caylent.com/spotlight-on-kubernetes/), [link2](https://caylent.com/50-useful-kubernetes-tools/), [link3](https://caylent.com/best-practices-kubernetes-pods/)

