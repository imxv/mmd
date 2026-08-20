# MMD

MMD 是一个不使用 WebView 的 macOS 原生 Markdown 轻量阅读器。

## 当前能力

- Finder、打开面板及拖拽打开 `.md` / `.markdown`
- Swift 官方 `swift-markdown` / cmark-gfm AST 解析
- TextKit 原生排版、选择、复制、链接和查找
- 标题目录与快速跳转
- 正文字号调整和系统/纸张主题
- 本地相对图片与异步网络图片
- UTF-8、带 BOM 的 UTF-8 和 UTF-16 文档

HTML block、Mermaid、LaTeX 和代码语法高亮暂未实现。

## 构建

要求 Xcode 及其 Command Line Tools，最低部署目标为 macOS 13。

```bash
swift test
./scripts/build_app.sh
open dist/MMD.app
```

默认构建 Apple Silicon 版本。构建 Universal 2：

```bash
MMD_UNIVERSAL=1 ./scripts/build_app.sh
```

生成的应用位于 `dist/MMD.app`。脚本会进行 Release 构建、剥离调试符号并执行 ad-hoc 签名。正式分发前仍需使用 Developer ID 签名和 Apple 公证。
第三方解析器的许可证会一并复制到应用的 `Contents/Resources`。

## 结构

- `MarkdownDocument`：只读文档与窗口生命周期
- `MarkdownRenderer`：Markdown AST、样式和图片 attachment
- `ReaderViewController`：TextKit 阅读视图、目录、主题和字号
- `WelcomeWindowController`：欢迎页及拖拽入口

MVP 未启用 App Sandbox，以保证官网直接分发时相对图片可以无额外授权读取。如果进入 Mac App Store，需要改为目录授权和 security-scoped bookmark 流程。
