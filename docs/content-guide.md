# 内容管理指南

本站除主页外的所有内容都是用 Markdown 格式文档编写，然后由 Hugo 渲染出 HTML 页面。所有的 Markdown 内容都保存在 `content` 目录下。

## 默认模板

创建博客的默认模版位于 `archetypes/default.md`。

```yaml
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: true
banner: "https://ws1.sinaimg.cn/large/00704eQkgy1frk001fkixj30rs0ku4qp.jpg"
author: "N/A"
summary: "文章摘要"
tags: [""]
categories: [""]
```

其中包含了博客文章的一些元数据。

- title：文章标题
- date：博客文章创建时间
- draft：是否是草稿，设置为 `false` 才会发布出去，默认是 `true`
- banner：“最新文章”一栏下的博客横幅
- author：文章作者
- summary：文章摘要，会在“最新文章”一栏显示
- tags：标签，可以写多个
- categories：分类，可以写多个，一般写一个就行

下图是以上元数据对应的单个博客页面上的地方。

![](https://ws1.sinaimg.cn/large/00704eQkgy1frqwaf6ulnj31t616s7wh.jpg)

注意：页面右侧的“分类”和“标签“显示的是所有博客的，而非当前博客页面的”分类“和”标签“。

## 创建新的博客

如果需要创建新的博客，只需要运行下面的命令：

```bash
hugo new blog/new-blog.md
```

新创建的博客位于 `content/blog/new-blog.md`。

打开该文件，修改文档的元数据，然后就可以欢快的编辑内容了。

## 创建新的 tab 页面

使用下面的命令创建新的 tab 页面：

```bash
hugo new new-tab.md
```

新的页面文件位于 `content/new-tab.md`。

在 `config.toml` 中增加一个 tab 配置：

```toml
[[menu.main]]
	name = "新的页面"
	url = "/new-tab/"
	weight = 6
```

- name：tab 显示在主页上的名称
- url：对应于新的 tab 页面的文件名
- weight：在主页上的排列顺序