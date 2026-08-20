# MMD Markdown 全语法预览

这是一份用于检查 **MMD 原生 Markdown 阅读器** 排版效果的综合示例，覆盖当前支持的 CommonMark 与 GFM 常用语法。

---

## 标题层级

# 一级标题 H1

## 二级标题 H2

### 三级标题 H3

#### 四级标题 H4

##### 五级标题 H5

###### 六级标题 H6

Setext 一级标题
===============

Setext 二级标题
---------------

---

## 段落与换行

这是一个普通段落。Markdown 源码中的单个换行会作为软换行处理，最终仍然保持自然的段落排版。

这一行末尾有两个空格，用于产生硬换行。  
这一行会从新的一行开始。

这一段包含中文、English、数字 1234567890，以及常用标点：，。！？；：“”《》（）。

---

## 文本强调

普通文本、*斜体文本*、_另一种斜体_、**粗体文本**、__另一种粗体__。

***粗斜体文本***、___另一种粗斜体___、~~删除线文本~~。

可以在一句话中组合 **粗体里的 *斜体* 与 `inline code`**，也可以显示 H~2~O 这样的普通字符。

---

## 行内代码与转义

使用 `⌘F` 查找内容，运行 `swift test` 验证项目，文件路径是 `/Users/example/README.md`。

相邻两行行内代码应保持独立：  
`第一行 inline code`  
`第二行 inline code`

反斜杠转义：\*不是斜体\*、\# 不是标题、\[不是链接\]、\`不是代码\`。

HTML 实体：&copy; &amp; &lt;MMD&gt; &quot;Markdown&quot;。

---

## 链接

- 行内链接：[Apple Developer](https://developer.apple.com/)
- 带标题链接：[Markdown 规范](https://spec.commonmark.org/ "CommonMark Specification")
- 自动链接：<https://github.github.com/gfm/>
- 邮箱链接：<reader@example.com>
- 引用链接：[Swift 官网][swift-site]

[swift-site]: https://www.swift.org/ "Swift"

---

## 图片

远程图片及替代文本：

![Swift 标志][swift-logo]

[swift-logo]: https://developer.apple.com/assets/elements/icons/swift/swift-64x64_2x.png "Swift Logo"

---

## 引用

> 这是一级引用。适合展示说明、摘要或引用内容。
>
> 引用中可以使用 **粗体**、*斜体*、`行内代码` 和 [链接](https://example.com)。
>
> > 这是嵌套的二级引用。

---

## 无序列表

- 第一项
- 第二项包含较长内容，用于观察列表换行以后文字是否与第一行正确对齐。
- 第三项
  - 二级项目 A
  - 二级项目 B
    - 三级项目

也可以使用其他无序列表标记：

* 星号列表
* 第二项

+ 加号列表
+ 第二项

---

## 有序列表

1. 第一步：打开 Markdown 文件
2. 第二步：解析文档结构
3. 第三步：使用 TextKit 2 排版
   1. 嵌套步骤一
   2. 嵌套步骤二

从其他数字开始：

5. 第五项
6. 第六项
7. 第七项

---

## 任务列表

- [x] Markdown 解析
- [x] 原生 TextKit 2 排版
- [x] 代码块整块背景
- [x] 表格网格线
- [ ] 继续检查更多文档样式

---

## 围栏代码块

```swift
struct MarkdownDocument {
    let title: String
    let source: String

    func render() throws -> NSAttributedString {
        try MarkdownRenderer.render(source)
    }
}
```

使用波浪线围栏：

~~~json
{
  "name": "MMD",
  "platform": "macOS",
  "usesWebView": false
}
~~~

缩进代码块：

    let app = NSApplication.shared
    app.activate(ignoringOtherApps: true)

---

## 表格

| 语法能力 | 实现方式 | 支持状态 |
| :--- | :---: | ---: |
| 标题与段落 | swift-markdown | 100% |
| 原生排版 | TextKit 2 | 100% |
| 窗口与菜单 | AppKit | 100% |
| 主题配置 | UserDefaults | 100% |

包含行内样式的表格：

| 类型 | 示例 | 说明 |
| --- | --- | --- |
| 强调 | **粗体** 与 *斜体* | 文本样式 |
| 代码 | `NSTextTable` | 行内代码 |
| 链接 | [打开](https://example.com) | 可点击链接 |
| 空单元格 |  | 保留网格 |

---

## 分隔线

上方和下方分别使用不同写法的分隔线。

***

分隔线中间的正文内容。

___

---

## 行内 HTML

行内 HTML 会以源码样式显示，例如 <mark>高亮标签</mark>、<kbd>⌘K</kbd> 和 <span>span 标签</span>。

HTML 块：

<details>
  <summary>HTML details 示例</summary>
  <p>MMD 当前以源码形式安全展示 HTML，不执行网页渲染。</p>
</details>

---

## 复杂组合

> ### 引用中的标题
>
> 1. 引用中的有序列表
> 2. 带有 **粗体**、~~删除线~~ 和 `代码`
>
> ```text
> 引用中的代码块
> 第二行代码
> ```

最后一段正文，用于确认长文档滚动、目录跳转、文本选择与复制效果。
