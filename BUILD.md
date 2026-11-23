# 构建说明

## 为什么不能在手机上直接出 APK

Flutter 官方暂不支持在 Linux arm64 主机上做 Android AOT 构建
（缺少 arm64 的 Android `gen_snapshot`，见 flutter#189724），
Android SDK 的 `aapt2` 等工具官方也只有 x86_64。
所以「写代码」可以在手机，**第一次构建和排错放 PC/CI**。

## PC 环境

- Flutter stable（3.22+）
- Android SDK（platform 34+、build-tools）
- JDK 17
- 一台能跑模拟器的机器（推荐 16GB 内存）

检查：

```bash
flutter doctor -v
```

## 构建

```bash
cd study-chat
bash tool/ci_build.sh
```

脚本会在 `/tmp/study-chat-build` 生成一次性 Android 壳，把 `lib/` 和
`pubspec.yaml` 拷进去再构建，产物在 `dist/app-debug.apk`。

也可以在已有工程里直接跑：

```bash
flutter create --platforms=android --project-name study_chat /tmp/build
cp -R lib pubspec.yaml /tmp/build/
cd /tmp/build
flutter pub get
flutter analyze
flutter run              # 连真机或模拟器
flutter build apk --debug
```

## 首次构建要留意

代码是手机端写的、还没经过编译器，第一次 `flutter analyze` 大概率会有
小错误（类型、API 版本）。按报错修即可，集中在：

- `flutter_math_fork` 的 `Math.tex` / `MathStyle`；
- `ExpansionTile.childrenPadding` 等版本差异；
- `flutter_secure_storage` Android 配置。

## 发布签名

debug APK 只能自己装。要发布：

```bash
flutter build apk --release
```

需要 `android/key.properties` 和 keystore，按 Flutter 官方签名文档配置。

## GitHub Actions

`.github/workflows/android.yml` 在 push 或手动触发时构建，
产物 `study-chat-debug-apk` 在 Actions 页面下载。
