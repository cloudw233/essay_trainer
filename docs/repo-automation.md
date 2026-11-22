# 仓库外围与 CI 配置

日期：2026-11-22

## 新增文件

- `.github/workflows/ci.yml`
- `.github/dependabot.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.gitignore`（在原 Flutter 忽略规则上补齐）
- `.gitattributes`
- `.editorconfig`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `CHANGELOG.md`
- `LICENSE`：Mozilla Public License 2.0 官方完整文本

## CI 工作流

`.github/workflows/ci.yml`：

- 触发：push 到 `main`/`master`、PR、手动 `workflow_dispatch`。
- `quality`：
  - Flutter 3.35.6、JDK 17；
  - 安装 `libsqlite3-dev`；
  - `dart format --output=none --set-exit-if-changed lib test tool`
  - `flutter analyze --no-pub`
  - `flutter test --no-pub`
- `android-debug`（非 PR）：
  - 安装 Android SDK 与 NDK 27.0.12077973；
  - 在 CI 内把 Gradle 的华为云镜像替换为官方 distribution（本地配置不改）；
  - `flutter build apk --debug --target-platform android-arm64 --no-pub`
  - 上传 `app-debug.apk` artifact，保留 7 天。
- 权限仅 `contents: read`；不使用 API Key，不运行 `tool/live_*`。

## Nightly 与本地发布

`.github/workflows/nightly.yml`：

- 触发：每天 03:00（Asia/Shanghai，cron `0 19 * * *` UTC）和手动 `workflow_dispatch`。
- 构建 arm64 debug APK，命名 `essay_trainer-nightly-<日期>-<commit>-arm64-v8a.apk`，
  带 `SHA256SUMS`，作为 artifact 保留 14 天。
- 不读取发布密钥，不创建 Release，权限仅 `contents: read`。

正式版在本机发布（`tool/release.sh`）：校验工作区干净、`HEAD` 在 tag 上、CHANGELOG 有
对应段落，跑格式/analyze/test，用本地 keystore 构建并验签（v2 + 证书 SHA-256），生成
`SHA256SUMS`，用本机 `gh` 创建 Release。发布密钥只存在本机，仓库不保存任何签名
secret。步骤见 [releasing.md](releasing.md)。

## 本地验证

```text
dart format --output=none --set-exit-if-changed lib test tool
→ exit 0, 71 files, 0 changed

flutter analyze
→ No issues found!

flutter test --no-pub
→ 60 tests passed

flutter build apk --debug --target-platform android-arm64 --no-pub
→ Built app-debug.apk (80 MB)

PyYAML BaseLoader parse
→ ci.yml jobs: quality, android-debug
→ dependabot.yml: 3 update ecosystems

temp git repo check-ignore
→ .tooling/.jspace/.env/key.properties/*.jks/build/*.apk ignored
→ docs/screenshots, .github/workflows, lib, pubspec.lock not ignored
```

本地验证 arm64 debug 构建时需要：

- `ANDROID_USER_HOME` 指向可写的 Android home（否则 debug keystore 无法创建）；
- `FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com`（本机默认腾讯镜像
  不提供 arm64 debug Maven 工件，官方存储返回 200）。CI 默认使用官方存储，
  因此不需要这项本地覆盖。

## 未执行

- 尚未在 GitHub 托管 runner 上实际触发 workflow（当前目录不是 Git 仓库，
  也没有远端）；只在本地验证了同一组命令和 YAML 语法。
- 未安装 `actionlint`，因此 action 引用只做了人工核对，未做 actionlint 级别的
  语义检查。
