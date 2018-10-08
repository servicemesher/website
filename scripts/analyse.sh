#!/bin/bash
# Analysis the blogs
orig_json="../public/algolia.json"
formated_json="../public/blog_list.json"
translators="../content/translators.md"
authors="../content/authors.md"

if [ ! -f $orig_json ];then
    echo "The file $orig_json doesn't exist, please run hugo to generate it."
    exit 0
fi
cat $orig_json|jq .|cat>$formated_json
echo -e '''
---
title: "译者投稿"
description: "投稿译者文章数统计"
keywords: ["service mesh"]
---

以下是投稿的译者及译文数目统计信息。
'''> $translators
echo -e "| 译者 | 文章数 |\n| ---- | ---- |" >> $translators
cat $formated_json|grep translator|sort -n|cut -d ":" -f2|grep -v "null"|tr -d '"',","|uniq -c|sort -rn|awk '{ print "|" $2 " | " $1 "|"}' >> $translators
echo -e "提交文章线索或译文请访问 https://github.com/servicemesher/trans" >> $translators

echo -e '''
---
title: "作者投稿"
description: "投稿作者文章数统计"
keywords: ["service mesh"]
---

以下是投稿的作者及原创文章数目统计信息。
'''> $authors
echo -e "| 作者 | 文章数 |\n| ---- | ---- |" >> $authors
cat $formated_json|grep author|grep -v "authorlink"|sort|cut -d ":" -f2|tr -d ","'"'|uniq -c|sort -nr|awk '$2 >"z" { print "|" $2 " | " $1 "|"}' >> $authors
echo -e "投递原创文章请访问 https://github.com/servicemesher/trans" >> $authors

rm $orig_json
