# ServiceMesher 社区网站 ---------------> Amazing website enjoy

本网站由 [ServiceMesher](https://www.servicemesher.com) 社区成员共建，源码位于 GitHub。

## 使用技术

- 构建工具：[hugo](https://gohugo.io)
- 主题：[hugo-universal](https://github.com/devcows/hugo-universal-theme) 
- 搜索：[algolia](https://algolia.com)
- 图床：Github 或其他支持 https 的图床

## 投稿

向社区投稿请参考[投稿指南](https://www.servicemesher.com/contributing-specification/)。

## 贡献指南

参与贡献前请先查看[贡献和使用说明](CONTRIBUTING.md)。

## 注意事项

在提交博客文章时需要注意以下事项。

- 每篇文章都需要设置一个 banner，图片尺寸为 1000*750 px，可以使用更高分辨率的图片只要符合该比例即可，banner 可以引用外链，也可以使用该仓库中的图片。
- 首页中风车图片的尺寸为 1600*880px，可以使用更高分辨率的图片只要符合该比例即可。
- 注意文章的 front matters 填写，译者和审校者使用数组格式。

## 网站构建与托管

**编译与预览**

执行 `hugo` 命令即可构建网站，执行 `hugo server` 后可以通过 <http://localhost:1313> 实时预览。

**搜索数据更新**

执行 algolia index 更新的 python 脚本中 import 的 `algoliasearch` 的版本为 1.6.8，使用 `pip install algoliasearch==1.6.8` 安装。

**网站托管**

ServiceMesher 社区网站托管在阿里云上，使用 Nginx 做为 Web 服务器，网站支持 HTTPS。
