# 架构与设计

## 目标

一个只做「学习提问」的 Android 客户端：比通用聊天更轻、更专注，
并且把「追问」从主对话里分离出来。

## 数据模型

- `Conversation`：一次学习对话，按 `subject` 分组；
- `ChatMessage`：主对话消息；
- `Branch`：从某条助手回复切出来的分支，保存 `anchor`（原文末尾 2500 字）
  和自己的 `messages`。

分支数据属于对话，不写回主对话的消息列表；UI 上只在对话页显示分支入口和数量。

## 交互

- 主对话：流式回答，底部固定输入框；助手消息下有「分支」按钮；
- 分支页：顶部可折叠的「原对话片段」，下面是分支问答，输入框固定在底部；
- 滚动：只有用户本来就在底部时才自动跟随；否则出现“到底”按钮；
- 流式：先在纯文本里增量刷新，结束后一次性渲染 Markdown/公式，避免每帧重排。

## 渲染

v0.1 不引入完整 Markdown 引擎，`rich_text.dart` 自己处理：

- 围栏代码块；
- `$$...$$` 独立公式；
- `$...$` 行内公式（WidgetSpan + flutter_math_fork）；
- 其余按纯文本排版。

标题、列表、表格等富文本后续再加，优先保证公式和代码正确。

## API

- OpenAI 兼容：`POST {baseUrl}/chat/completions`，`stream: true`；
- 默认 `https://api.deepseek.com`，模型 `deepseek-chat`；
- 分支请求把锚点、分支历史、当前问题拼成一条 user 消息；
- 主对话用 system 提示约束“先结论后推导 + LaTeX”。

## 安全与成本

- API Key 存 `flutter_secure_storage`（Android Keystore），不进 APK、不进日志；
- 分支上下文只带锚点和该分支自己的历史，不重放主对话，控制 token；
- 之后可加：单次最大 token、用量统计、请求取消。

## 后续

1. 科目/工作区分组与筛选；
2. 分支标题用模型润色（现在用首句截断）；
3. 导出/导入（沿用 DSH 迁移包的 zip + restore 思路）；
4. Markdown 表格/标题；
5. 真机性能优化（长列表、公式缓存）。


## v0.2：图片 / 文件 / 视觉模型

- 默认模型改为 `deepseek-flash`（支持图片输入），设置里可选 `deepseek-v4-pro`。
- 输入框「+」：拍照、相册、文件（PDF / Word / PPT / 文本）。
- 图片以 base64 `image_url` 直接发给模型；文本文件读取后作为文本块；PDF / Word / PPT 先 `POST /files`（`text_recognition`）拿 `file_id`，再以 `file` 块引用。
- 流式渲染：50ms 节流、Markdown 解析结果缓存、流式阶段纯文本渲染，减少卡顿。
- Agora 风格配色：浅鼠尾草背景、圆角胶囊输入框、圆形发送键、模型胶囊。
