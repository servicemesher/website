---
title: "Istio1.5&Envoy数据面WASM实践"
date: 2020-04-11T11:40:00+08:00
draft: false
banner: ""
author: "王佰平"
authorlink: ""
reviewer: [""]
reviewerlink: [""]
summary: "Istio1.5回归单体架构，并抛却原有的out-of-process的数据面（Envoy）扩展方式，转而拥抱基于WASM的in-proxy扩展，以期获得更好的性能。本文基于网易杭州研究院轻舟云原生团队的调研与探索，介绍WASM的社区发展与实践。"
tags: ["service mesh"]
categories: ["istio"]
keywords: ["service mesh","服务网格","istio", "envoy", "WASM"]
---

## 0 简介
Istio1.5回归单体架构，并抛却原有的out-of-process的数据面（Envoy）扩展方式，转而拥抱基于WASM的in-proxy扩展，以期获得更好的性能。本文基于网易杭州研究院轻舟云原生团队的调研与探索，介绍WASM的社区发展与实践。

超简单版解释：
> --> Envoy内置Google V8 引擎，支持WASM字节码运行，并开放相关接口用于和WASM虚拟机交互数据；
> --> 使用各种语言开发相关扩展并编译为*.WASM文件；
> --> 将扩展文件挂载或者打包进入Envoy容器镜像，通过xDS动态下发文件路径及相关配置由虚拟机执行。

## 1 WebAssembly简述

Istio最新发布的1.5版本，架构发生了巨大调整，从原有的分布式结构回归为单体，同时抛却了原有的out-of-process的Envoy扩展方式，转而拥抱基于WASM的in-proxy扩展，以期获得更好的性能，同时减小部署和使用的复杂性。所有的WASM插件都在Envoy的沙箱中运行，相比于原生C++ Envoy插件，WASM插件具有以下的优点：

* 接近原生插件性能（存疑，待验证，社区未给出可信测试结果，但是WASM字节码和机器码比较接近，它的性能极限确实值得期待）；
* 沙箱运行，更安全，单个filter故障不会影响到Envoy主体执行，且filter通过特定接口和Envoy交互数据，Envoy可以对暴露的数据进行限制（沙箱安全性对于Envoy整体稳定性保障具有很重要的意义）；
* 可动态分发和载入运行（单个插件可以编译为*.WASM文件进行分发共享，动态挂载，动态载入，且没有平台限制）；
* 无开发语言限制，开发效率更高（WASM本身支持语言众多，但是限定到Envoy插件开发，必然依赖一些封装好的SDK用于和Envoy进行交互，目前只有C++语言本身、Rust以及AssemblysScript有一定的支持）。

WASM的诞生源自前端，是一种为了解决日益复杂的前端web应用以及有限的JavaScript性能而诞生的技术。它本身并不是一种语言，而是一种字节码标准，一个“编译目标”。WASM字节码和机器码非常接近，因此可以非常快速的装载运行。任何一种语言，都可以被编译成WASM字节码，然后在WASM虚拟机中执行（本身是为web设计，必然天然跨平台，同时为了沙箱运行保障安全，所以直接编译成机器码并不是最佳选择）。理论上，所有语言，包括JavaScript、C、C++、Rust、Go、Java等都可以编译成WASM字节码并在WASM虚拟机中执行。

![](./image/wasm.png)

## 2 社区发展及现状

### 2.1  Envoy & WASM

Envoy提供了一个特殊的Http七层filter，名为wasm，用于载入和执行WASM字节码。该七层filter同样也负责WASM虚拟机的创建和管理，使用的是Google内部的v8引擎（支持JS和WASM）。当前filter未进入Envoy主干，而是在单独的一个[工程](https://github.com/envoyproxy/envoy-WASM)中。该工程会周期性从主干合并代码。从机制看，WASM扩展和Lua扩展机制非常相似，只是Lua载入的是原始脚本，而WASM载入的是编译后的WASM字节码。Envoy暴露相关的接口如获取请求头、请求体，修改请求头，请求体，改变插件链执行流程等等，用于WASM插件和Envoy主体进行数据交互。

对于每一个WASM扩展插件都可以被编译为一个\*.WASM文件，而Envoy七层提供的wasm Filter可以通过动态下发相关配置（指定文件路径）使其载入对应的文件并执行：前提是对应的文件已经在镜像中或者挂载进入了对应的路径。当然，WASM Filter也支持从远程获取对应的\*.WASM文件（和目前网易轻舟API网关对Lua脚本扩展的支持非常相似）。

### 2.2  Istio & WASM

现有的Istio提供了名为Mixer插件模型用于扩展Envoy数据面功能，具体来说，在Envoy内部，Istio开发了一个原生C++插件用于收集和获取运行时请求信息并通过grpc将信息上报给Mixer，外部Mixer则调用各个Mixer Adapter用于监控、授权控制、限流等等操作，相关处理结果如有必要再返回给Envoy中C++插件用于做相关控制。
Mixer模型虽然提高了极高的灵活性，且对Envoy侵入性极低，但是引入了大量的额外的外部调用和数据交互，带来了巨大的性能开销（相关的测试结果很多，按照istio社区的数据：移除Mixer可以使整体CPU消耗减少50%）。而且Istio插件扩展模型和Envoy插件模型整体是割裂的，Istio插件在out-of-process中执行，通过GRPC进行插件与Envoy主体的数据交互，而Envoy原生插件则是in-proxy模式，在同一个进程中通过虚函数接口进行调用和执行。

因此在Istio 1.5中，Istio提供了全新的插件扩展模型：WASM in proxy。使用Envoy支持的WASM机制来扩展插件：兼顾性能、多语言支持、动态下发动态载入、以及安全性。唯一的缺点就是现有的支持还不够完善。

为了提升性能，Istio社区在1.5发布中，已经将几个扩展使用in-proxy模型（基于WASM API而非原生Envoy C++ HTTP插件API）进行实现。但是目前考虑到WASM还不够稳定，所以相关扩展默认不会执行在WSAM沙箱之中（在所谓NullVM中执行）。虽然istio也支持将相关扩展编译为WASM模块，并在沙箱中执行，但是不是默认选项。

所谓Mixer V2其最终目标就是将现有的out-of-process的插件模型最终用基于WASM的in-proxy扩展模型来替代。但是目前举例目标仍旧有较长一段路要走，毕竟即使Istio社区本身的插件，也未能完全在WASM沙箱中落地。但从Istio 1.5开始，Istio社区应该会快速推动WASM的发展。

### 2.3 solo.io & WASM

solo.io推出了WebAssembly Hub，用于构建、发布以及共享Envoy WASM扩展。WebAssembly Hub包括一套用于简化扩展开发的SDK（目前solo.io提供了AssemblysScript SDK，而Istio/Envoy社区提供了Rust/C++ SDK），相关的构建、发布命令，一个用于共享和复用的扩展仓库。具体的内容可以参考[solo.io提供的教程](https://docs.solo.io/web-assembly-hub/latest/tutorial_code/)。



## 3 WASM实践

下面简单实现一个WASM扩展作为演示DEMO，可以帮助大家对WASM有进一步了解。此处直接使用了solo.io提供的构建工具，避免环境搭建等各个方面的一些冗余工作。**该扩展名为path_rewrite，可以根据路由原始的path值匹配，来将请求path重写为不同值**。

执行以下命令安装wasme：

```shell
curl -sL https://run.solo.io/wasme/install | sh
export PATH=$HOME/.wasme/bin:$PATH
```

wasme是solo.io提供的一个命令行工具，一个简单的类比就是：docker cli之于容器镜像，wasme之于WASM扩展。

```shell
ping@ping-OptiPlex-3040:~/Desktop/wasm_example$ wasme init ./path_rewrite
Use the arrow keys to navigate: ↓ ↑ → ←
? What language do you wish to use for the filter:
  ▸ cpp
    assemblyscript

```

执行wasme初始化命令，会让用户选择使用何种语言开发WASM扩展，目前wasme工具仅支持C++和AssemblyScript，当前仍旧选择cpp进行开发（AssemblyScript没有开发经验，后续有机会可以学习一下）。执行命令之后，会自动创建一个bazel工程，目录结构如下：其中关键的几个文件已经添加了注释。从目录结构看，solo.io没有在wasme中添加任何黑科技，生成的模板非常的干净，完整而简洁。

```
.
├── bazel
│   └── external
│       ├── BUILD
│       ├── emscripten-toolchain.BUILD
│       └── envoy-wasm-api.BUILD      # 说明如何编译envoy api依赖
├── BUILD                             # 说明如何编译插件本身代码
├── filter.cc                         # 插件具体代码
├── filter.proto                      # 扩展数据面接口
├── README.md
├── runtime-config.json
├── toolchain
│   ├── BUILD
│   ├── cc_toolchain_config.bzl
│   ├── common.sh
│   ├── emar.sh
│   └── emcc.sh
└── WORKSPACE                         # 工程描述文件包含对envoy api依赖

```



**filter.cc中已经填充了样板代码，包括所有的插件需要实现的接口。开发者只需要按需修改某个接口的具体实现即可(此处列出了整个插件的全部代码，以供参考。虽然该代码没有实现什么特许功能，但是已经包含了一个WASM扩展（C++语言版）应当具备的所有结构，无论多么复杂的插件，都只是在该结构的基础上填充相关的逻辑代码而已**：



```C++
// NOLINT(namespace-envoy)
#include <string>
#include <unordered_map>

#include "google/protobuf/util/json_util.h"
#include "proxy_wasm_intrinsics.h"
#include "filter.pb.h"

class AddHeaderRootContext : public RootContext {
public:
  explicit AddHeaderRootContext(uint32_t id, StringView root_id) : RootContext(id, root_id) {}
  bool onConfigure(size_t /* configuration_size */) override;

  bool onStart(size_t) override;

  std::string header_name_;
  std::string header_value_;
};

class AddHeaderContext : public Context {
public:
  explicit AddHeaderContext(uint32_t id, RootContext* root) : Context(id, root), root_(static_cast<AddHeaderRootContext*>(static_cast<void*>(root))) {}

  void onCreate() override;
  FilterHeadersStatus onRequestHeaders(uint32_t headers) override;
  FilterDataStatus onRequestBody(size_t body_buffer_length, bool end_of_stream) override;
  FilterHeadersStatus onResponseHeaders(uint32_t headers) override;
  void onDone() override;
  void onLog() override;
  void onDelete() override;
private:

  AddHeaderRootContext* root_;
};
static RegisterContextFactory register_AddHeaderContext(CONTEXT_FACTORY(AddHeaderContext),
                                                      ROOT_FACTORY(AddHeaderRootContext),
                                                      "add_header_root_id");

bool AddHeaderRootContext::onConfigure(size_t) { 
  auto conf = getConfiguration();
  Config config;
  
  google::protobuf::util::JsonParseOptions options;
  options.case_insensitive_enum_parsing = true;
  options.ignore_unknown_fields = false;

  google::protobuf::util::JsonStringToMessage(conf->toString(), &config, options);
  LOG_DEBUG("onConfigure name " + config.name());
  LOG_DEBUG("onConfigure " + config.value());
  header_name_ = config.name();
  header_value_ = config.value();
  return true; 
}

bool AddHeaderRootContext::onStart(size_t) { LOG_DEBUG("onStart"); return true;}

void AddHeaderContext::onCreate() { LOG_DEBUG(std::string("onCreate " + std::to_string(id()))); }

FilterHeadersStatus AddHeaderContext::onRequestHeaders(uint32_t) {
  LOG_DEBUG(std::string("onRequestHeaders ") + std::to_string(id()));
  return FilterHeadersStatus::Continue;
}

FilterHeadersStatus AddHeaderContext::onResponseHeaders(uint32_t) {
  LOG_DEBUG(std::string("onResponseHeaders ") + std::to_string(id()));
  addResponseHeader(root_->header_name_, root_->header_value_);
  replaceResponseHeader("location", "envoy-wasm");
  return FilterHeadersStatus::Continue;
}

FilterDataStatus AddHeaderContext::onRequestBody(size_t body_buffer_length, bool end_of_stream) {
  return FilterDataStatus::Continue;
}

void AddHeaderContext::onDone() { LOG_DEBUG(std::string("onDone " + std::to_string(id()))); }

void AddHeaderContext::onLog() { LOG_DEBUG(std::string("onLog " + std::to_string(id()))); }

void AddHeaderContext::onDelete() { LOG_DEBUG(std::string("onDelete " + std::to_string(id()))); }

```



注意到生成的样板代码类型名称仍旧以`AddHeader`为前缀，而没有根据提供的路径名称生成，此处是wasme可以优化的一个地方。此外，**自动生成的样板代码中已经包含了AddHeader的一些代码，逻辑简单，但是配置解析、API访问，请求头修改等过程都具备，麻雀虽小，五脏俱全，正好可以帮助初次的开发者可以依葫芦画瓢熟悉WASM插件的开发过程**。对于入门是非常友好的。

针对path_rewrite具体的开发步骤如下：

**STEP ONE** 首先修改模板代码中filter.proto文件，因为path rewrite肯定不能简单的只能替换固定值，修改后proto文件如下所示：

```Protobuf
syntax = "proto3";

message PathRewriteConfig {
  message Rewrite {
    string regex_match = 1;      # path正则匹配时替换
    string custom_path = 2;      # 待替换值
  }
  repeated Rewrite rewrites = 1;
}
```

**STEP TWO** 修改配置解析接口，具体方法名为onConfigure。修改后解析接口如下：

```C++
bool AddHeaderRootContext::onConfigure(size_t) {
  auto conf = getConfiguration();
  PathRewriteConfig config; // message type in filter.proto
  if (!conf.get()) {
    return true;
  }
  google::protobuf::util::JsonParseOptions options;
  options.case_insensitive_enum_parsing = true;
  options.ignore_unknown_fields = false;
  // 解析字符串配置并转换为PathRewriteConfig类型：配置反序列化
  google::protobuf::util::JsonStringToMessage(conf->toString(), &config,
                                              options);

  // 配置阶段编译regex避免请求时重复编译，提高性能
  for (auto &rewrite : config.rewrites()) {
    rewrites_.push_back(
        {std::regex(rewrite.regex_match()), rewrite.custom_path()});
  }

  return true;
}
```



**STEP THREE** 修改请求头接口，具体方法名为onRequestHeaders，修改后接口代码如下：

```C++
FilterHeadersStatus AddHeaderContext::onRequestHeaders(uint32_t) {
  LOG_DEBUG(std::string("onRequestHeaders ") + std::to_string(id()));
  // Envoy中path同样存储在header中，key为:path
  auto path = getRequestHeader(":path");
  if (!path.get()) {
    return FilterHeadersStatus::Continue;
  }
  std::string path_string = path->toString();
  for (auto &rewrite : root_->rewrites_) {
    if (std::regex_match(path_string, rewrite.first) &&
        !rewrite.second.empty()) {
      replaceRequestHeader(":path", rewrite.second);
      replaceRequestHeader("location", "envoy-wasm");
      return FilterHeadersStatus::Continue;
    }
  }
  return FilterHeadersStatus::Continue;
}

```

从上述过程不难看出，整个扩展的开发体验相当简单，按需实现对应接口即可，扩展本身内容非常轻，内部具体的功能逻辑才是决定扩展开发复杂性的关键。而且借助wasme工具，自动生成代码后，效率可以更高（和目前在内部使用的filter_creator.py有部分相似，样板代码自动生成）。

至此，插件已经开发完成，可以打包编译了。wasm同样提供了打包编译的功能，甚至可以类似于容器镜像将编译后结构推送到远端仓库之中，用于分享或者存储。不过有一个提示，在开发之前，先直接执行bazel命令编译，编译过程中，一些基础依赖会被自动拉取并缓存到本地，借助IDE可以获得更好的代码提示和开发体验。



```shell
bazel build :filter.wasm
```

接下来是wasme命令编译：


```shell
wasme build cpp -t webassemblyhub.io/wbpcode/path_rewrite:v0.1 .
```



该命令会使用固定镜像作为编译环境，但是本质和直接使用bazel编译并无不同。具体的编译日志可以看出，实际上，该命令也是使用的`bazel build :filter.wasm`。



```shell
Status: Downloaded newer image for quay.io/solo-io/ee-builder:0.0.19
Building with bazel...running bazel build :filter.wasm
Extracting Bazel installation...
Starting local Bazel server and connecting to it...

```


注意，上述命令中wbpcode为用户名，具体实践时提议替换为自身用户名，如果注册了webassemblyhub.io账号，甚至可以进行push和pull操作。此次就不做相关操作了，直接本地启动带WASM的envoy。命令如下：



```
# --config参数用于指定wasm扩展配置
wasme deploy envoy webassemblyhub.io/wbpcode/path_rewrite:v0.1 --config "{\"rewrites\": [ {\"regex_match\":\"...\", \"custom_path\": \"/anything\"} ]}" --envoy-run-args "-l trace"
```



从envoy执行日志可以看到：最终envoy会执行七层Filter：`envoy.filters.http.wasm`，相关配置为：wasm文件位置（docker执行时挂载进入容器内部）、wasm文件对应插件配置、runtime等等。通过在http_filters中重复添加多个`envoy.filters.http.wasm`，即可实现多个WASM扩展的执行。从下面的日志也可以看出，即使不使用solo.io的工具，只需要为Envoy指定编译好的wasm文件，其执行结果是完全相同的。



```
[2020-03-31 08:41:24.831][1][debug][config] [external/envoy/source/extensions/filters/network/http_connection_manager/config.cc:388]       name: envoy.filters.http.wasm
[2020-03-31 08:41:24.831][1][debug][config] [external/envoy/source/extensions/filters/network/http_connection_manager/config.cc:390]     config: {
 "config": {
  "rootId": "add_header_root_id",
  "vmConfig": {
   "code": {
    "local": {
     "filename": "/home/ping/.wasme/store/e58ddd90347b671ad314f1c969771cea/filter.wasm"
    }
   },
   "runtime": "envoy.wasm.runtime.v8"
  },
  "configuration": "{\"rewrites\": [ {\"regex_match\":\"...\", \"custom_path\": \"/anything\"} ]}",
  "name": "add_header_root_id"
 }
}

```



之后使用对应path调用接口：可发现WASM插件已经生效：



```
':authority', 'localhost:8080'
':path', '/ab' # 原始请求path匹配"..."
':method', 'GET'
'user-agent', 'curl/7.58.0'
'accept', '*/*'
```

```
':authority', 'localhost:8080'
':path', '/anything'
':method', 'GET'
':scheme', 'https'
'user-agent', 'curl/7.58.0'
'accept', '*/*'
'x-forwarded-proto', 'http'
'x-request-id', '1009236e-ab57-4ded-a8ff-3d1b17c6787b'
'location', 'envoy-wasm'
'x-envoy-expected-rq-timeout-ms', '15000'
```



## 4 WASM总结

WASM扩展仍在快速发展当中，但是Isito使用WASM API实现了相关的插件，说明已经做好了迁移的准备。前景美好，值得期待，但有待进一步确定WASM沙箱本身稳定性和性能。

从开发体验来说：

* 借助solo.io工具，简单插件的开发几乎没有任何的难度，只是目前支持的语言只有C++/AssemblyScript（PS: Envoy社区开发了Rust语言SDK，但是正在开发当中而且使用Rust开发WASM扩展的价值存疑：Rust相比于C++最大的优势是通过严格的编译检查来保证内存安全，但是也使得上手难度又提升了一个台阶，在有WASM沙箱为内存安全兜底的情况下，使用Rust而不使用JS、Go等上手更简易的语言来开发扩展，实无必要）。

* 对于相对复杂的插件，如果使用WASM的话，测试相比于原生插件会更困难一些，WASM扩展配置的输入只能依赖手写JSON字符串，希望未来能够改善。

* 缺少路由粒度的配置，所有配置都是全局生效，依赖插件内部判断，但是这一部分如果确实有需要，支持起来应该很快，不存在技术上的阻碍，倒是不用担心。

## 作者简介

王佰平，网易杭州研究院轻舟云原生团队工程师，负责轻舟Envoy网关与轻舟Service Mesh数据面开发、功能增强、性能优化等工作，对Envoy数据面开发、增强、落地具有较为丰富的经验。
