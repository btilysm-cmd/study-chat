# PC 任务清单

手机端已经把代码写好（`lib/`），但 Flutter Android 构建需要 x86_64 主机。
下面是 PC / CI 要做的事，按顺序。

## 1. 选一条构建路线

### A. GitHub Actions（推荐）

1. 在 PC 或手机浏览器建一个空仓库；
2. 在 `study-chat/` 里：

```bash
git init
git add .
git commit -m "study-chat v0.1"
git branch -M main
git remote add origin <你的仓库地址>
git push -u origin main
```

3. Actions 会自动跑 `build-apk`；
4. 下载 `study-chat-debug-apk`，装到手机。

### B. PC 本地

```bash
# 先装 Flutter stable、Android SDK、JDK 17
flutter doctor -v
cd study-chat
bash tool/ci_build.sh
```

产物：`dist/app-debug.apk`。

## 2. 首次构建大概率的报错

代码没经过 Flutter 编译器，需要按报错修：

- `ExpansionTile.childrenPadding` 之类版本差异；
- `flutter_math_fork` 的 `Math.tex` / `MathStyle`；
- `flutter_secure_storage` 的 Android 配置；
- `Badge`、`IconButton.filled` 等 Material 3 组件版本。

把完整报错发回来，我按报错改。

## 3. 真机验证清单

1. 设置里填 DeepSeek API Key；
2. 新对话提问，确认流式输出；
3. 发一条带公式的回答，确认 `$...$` 渲染；
4. 点助手回复下的「分支」，在分支里追问，确认主对话没有新增；
5. 退出重进，确认对话和分支还在；
6. 长对话滚动到底、键盘弹出，输入框不被挡。
