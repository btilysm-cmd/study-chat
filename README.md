# 学习问答（study-chat）

一个专门用来学习提问的 Android 客户端：直连 DeepSeek（OpenAI 兼容）API，支持分支追问。

## 功能（v0.1）

- 对话列表按科目分组，本地保存；
- 流式回答，公式/代码块渲染；
- 长按或点助手回复下的「分支」：把这条回答做成独立分支，分支里的追问不进入主对话；
- 分支页顶部展示原对话片段，底部固定追问框，支持“到底”按钮；
- API Key 存在系统 Keystore，不写进 APK。

## 手机端能做什么

- 写 `lib/` 里的 Dart 代码、改文档、推 Git；
- 真机装 APK 测试。

## PC 要做的事

Flutter 的 Android AOT 构建目前不支持 Linux arm64 主机（[flutter#189724](https://github.com/flutter/flutter/issues/189724)），
所以第一次构建和排错需要 PC 或 CI。两条路选一条：

**A. GitHub Actions（推荐，手机也能触发）**

1. 建仓库，推代码；
2. Actions 里跑 `build-apk`；
3. 下载 `study-chat-debug-apk` 里的 APK 安装。

**B. PC 本地构建**

```bash
cd study-chat
bash tool/ci_build.sh          # 生成临时 android 壳并构建
# 或
flutter create --platforms=android --project-name study_chat /tmp/build
cp -R lib pubspec.yaml /tmp/build/ && cd /tmp/build
flutter pub get && flutter run
```

PC 上需要 Flutter stable、Android SDK、JDK 17。详见 `BUILD.md`。

## 结构

- `lib/api.dart`：SSE 流式调用；
- `lib/app_state.dart`：对话/分支状态与保存；
- `lib/screens/`：首页、对话、分支、设置；
- `lib/widgets/rich_text.dart`：Markdown 代码块 + LaTeX 渲染。

设计取舍见 `ARCHITECTURE.md`。
