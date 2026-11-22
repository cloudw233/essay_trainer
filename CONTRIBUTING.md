# Contributing

## 环境

- Flutter 3.35.6 / Dart 3.9
- JDK 17
- Android SDK 36；Flutter 3.35 默认使用 NDK 27.0.12077973
- Linux 下运行 SQLite 相关测试需要 `libsqlite3-dev`

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

如果本机只有 `libsqlite3.so.0` 而没有未版本化符号链接，可使用：

```bash
LD_LIBRARY_PATH="$PWD/.tooling/native" flutter test --no-pub
```

## 本地真实验证

真实 DeepSeek 检查脚本放在 `tool/`，从环境变量读取 Key，**不要把 Key 写进
任何文件或提交记录**：

```bash
DEEPSEEK_API_KEY=... flutter test tool/live_grading_check.dart
DEEPSEEK_API_KEY=... flutter test tool/live_prompt_check.dart
DEEPSEEK_API_KEY=... flutter test tool/live_chinese_grading_check.dart
```

这些检查会产生真实 API 费用，不属于默认 CI。

## 提交前

- 运行 `dart format lib test tool`
- 运行 `flutter analyze --no-pub`
- 运行 `flutter test --no-pub`
- 不提交 `.tooling/`、`.jspace/`、`build/`、`dist/`、签名文件或任何密钥
- UI 变化请附浅色/深色截图；没有设备验证时在 PR 中写明

安全问题和密钥泄露请按 [SECURITY.md](SECURITY.md) 处理。


## License

提交贡献即表示你同意将贡献按本项目的 **Mozilla Public License 2.0** 授权。
完整文本见 [LICENSE](LICENSE)。
