---
title: "活动"
description: "Service Mesh活动页面"
keywords: ["service mesh","meetup"]
---

## Service Mesh Meetup #2 北京站

Service Mesh Meetup北京站，是ServiceMesher社区举行的第二届meetup，关于第一届的情况请查看[杭州站回顾](/blog/hangzhou-meetup-20180630)。

扫描下图中的二维码或者直接访问[活动行](http://www.huodongxing.com/event/5449229731500)报名。

![Service Mesh Meetup北京站报名](https://ws4.sinaimg.cn/large/006tNc79gy1ftf203y85sj318g0oge81.jpg)

- 时间：2018年7月29日（星期日）下午 1:00 - 5:30

- 地点：北京市海淀区中关村大街11号e世界财富中心A座B2

![Service Mesh meetup北京站活动地点](https://ws4.sinaimg.cn/large/006tKfTcgy1ftdvakko2qj319g0yutrm.jpg)

![Service Mesh meetup北京站报名](https://ws4.sinaimg.cn/large/006tNc79ly1ftf2h13vlgj315p2q9kjq.jpg)

## Topic与讲师介绍

### 张亮（京东金融数据研发负责人）

个人简介：张亮，京东金融数据研发负责人。热爱开源，目前主导两个开源项目Elastic-Job和Sharding-Sphere(Sharding-JDBC)。擅长以java为主分布式架构以及以Kubernetes和Mesos为主的云平台方向，推崇优雅代码，对如何写出具有展现力的代码有较多研究。2018年初加入京东金融，现担任数据研发负责人。目前主要精力投入在将Sharding-Sphere打造为业界一流的金融级数据解决方案之上。 

![张亮](https://ws4.sinaimg.cn/large/006tKfTcgy1ftcqm90akkj30ru0is4qp.jpg)

**Service Mesh的延伸 —— 论道Database Mesh**

随着Service Mesh概念的推广与普及，云原生、低接入成本以及分布式组件下移等理念，已逐渐被认可。在Service Mesh依旧处于高速迭代的发展期的同时，以它的理念为参考，其他的Mesh思想也在崭露萌芽。
Database Mesh即是Service Mesh的其中一种延伸，虽然理念与Service Mesh相近，但数据库与无状态的服务却有着巨大的差别。Database Mesh与分布式数据库（如NoSQL和NewSQL）的功能范畴并非重叠而是互补，它更加关注数据库之上的中间啮合层。本次将与您一起交流Database Mesh的一些思考，以及探讨如何与现有产品相结合，实现更加强大与优雅的云原生数据库解决方案。

------

### 吴晟（Apache SkyWalking创始人）

个人简介：Apache SkyWalking 创始人，PPMC和Committer，比特大陆资深技术专家，[Tetrate.io](http://Tetrate.io) Founding Engineer，专注APM和自动化运维相关领域。Microsoft MVP。CNCF OpenTracing标准化委员会成员。ShardingSphere PMC 成员。

![吴晟](https://ws2.sinaimg.cn/large/006tKfTcgy1ftcv8l5cx8j31kw11xnpf.jpg)

**Observability on Service Mesh —— Apache SkyWalking 6.0**

APM在传统意义上，都是通过语言探针，对应用性能进行整体分析。但随着Cloud Native, K8s容器化之后，以Istio为代表的Service Mesh的出现，为可观测性和APM提供了一种新的选择。SkyWalking作为传统上提供多语言自动探针的Apache开源项目，在service mesh的大背景下，也开始从新的角度提供可观测性支持。

SkyWalking和Tetrate Inc. Istio核心团队合作，从Mixer接口提取遥感数据，提供SkyWalking语言探针一样的功能，展现service mesh风格探针的强大力量。之后，也会和更多的mesh实现进行合作，深入在此领域的运用。

------

### 朵晓东（蚂蚁金服，高级技术专家）

个人简介：蚂蚁金服高级技术专家，专注云计算技术及产品。Apache Kylin创始团队核心成员；蚂蚁金融云PaaS创始团队核心成员，Antstack网络产品负责人；SOFAMesh创始团队核心成员。

![朵晓东-蚂蚁金服](https://ws2.sinaimg.cn/large/006tKfTcgy1ftcqds9ceej30pf0pfn4f.jpg)

**蚂蚁金服开源的Service Mesh数据平面SOFA MOSN深层揭秘**

Service Mesh技术体系在蚂蚁落地过程中，我们意识到Mesh结合云原生在多语言，流量调度等各方面的优势，同时面对蚂蚁内部语言体系与运维构架深度融合，7层流量调度规则方式复杂多样，金融级安全要求等诸多特征带来的问题和挑战，最终选择结合蚂蚁自身情况自研Golang版本数据平面MOSN，同时拥抱开源社区，支持作为Envoy替代方案与Istio集成工作。本次session将从功能、构架、跨语言、安全、性能、开源等多方面分享Service Mesh在蚂蚁落地过程中在数据平面的思考和阶段成果。

------

### 丁振凯（新浪微博，微博搜索架构师）

个人简介：微博搜索架构师，主要负责搜索泛前端架构工作。主导搜索结果和热搜榜峰值应对及稳定性解决方案，以及微服务化方案落地。在Web系统架构方面拥有比较丰富的实践和积累。喜欢思考，深究技术本质。去年十一鹿晗关晓彤事件中一不小心成为网红工程师，并成功登上自家热搜榜。 

![丁振凯-微博](https://ws1.sinaimg.cn/large/006tKfTcgy1ftcv7v8ovwj31kw16okjl.jpg)

**微博Service Mesh实践 -  WeiboMesh**

WeiboMesh源自于微博内部对异构体系服务化的强烈需求以及对历史沉淀的取舍权衡，它没有把历史作为包袱，而是巧妙的结合自身实际情况完成了对Service Mesh规范的实现。目前WeiboMesh在公司内部已经大规模落地，并且已经开源，WeiboMesh是非常接地气的Service Mesh实现。本次分享主要介绍微博在跨语言服务化面临的问题及WeiboMesh方案介绍，并结合业务实例分析WeiboMesh的独到之处。

## 合作社区

**[Sharding-sphere](http://shardingjdbc.io/)**

![sharding-sphere](https://ws4.sinaimg.cn/large/006tNc79ly1ftf00s8uvdj30tg04xjsr.jpg)

[新浪微博](https://weibo.com)

![新浪微博](https://ws3.sinaimg.cn/large/006tNc79ly1ftezukrdtlj30rs08hdh9.jpg)

**[Apache Skywalking](http://skywalking.apache.org/)**

![skywalking](https://ws2.sinaimg.cn/large/006tKfTcgy1ftcvoe75i5j30xa07rmy7.jpg)

视频直播：[IT大咖说](http://www.itdks.com)

![IT大咖说](https://ws1.sinaimg.cn/large/00704eQkgy1fswks89xukj30b4035jsf.jpg)

## 关于ServiceMesher

这里是Service Mesher社区，Service Mesh人共同的家园。我们的使命是：传播Service Mesh技术、加强行业内部交流、促进开源文化构建、推动Service Mesh在企业落地，官方网站：http://www.servicemesher

![ServiceMesher公众号二维码](https://ws1.sinaimg.cn/large/00704eQkgy1fshv989hhqj309k09k0t6.jpg)

## Service Mesh Meetup #1 杭州站

Service Mesh Meetup #1，2018年6月30日，杭州蚂蚁Z空间，[查看回顾](../blog/hangzhou-meetup-20180630)。
