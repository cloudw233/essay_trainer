# 发布签名发行版

正式版在本机构建、签名并发布：APK 用发布密钥签名，由 `tool/release.sh` 调用本机
`gh` 创建 GitHub Release。GitHub Actions 不持有发布密钥，也不创建 Release；它只
构建每天一次的 nightly 测试包（debug 签名，见 `.github/workflows/nightly.yml`）。

## 签名材料（只在本机）

| 项目 | 位置 / 值 |
| --- | --- |
| keystore | `android/app/essay-release.jks`（已 gitignore） |
| 签名配置 | `android/key.properties`（已 gitignore） |
| alias | `essay` |
| 算法 | RSA 4096，自签名证书，有效期 10000 天 |
| 证书 SHA-256 | `BD:30:06:6F:4F:89:92:89:53:6C:C7:3D:E6:87:80:A2:5A:53:44:47:E6:46:E6:EA:C8:68:6D:93:50:07:2C:1F` |

`android/key.properties` 长这样：

```properties
storePassword=<密码>
keyPassword=<密码>
keyAlias=essay
storeFile=essay-release.jks
```

**必须备份**：把 `android/app/essay-release.jks` 和 `android/key.properties` 存进
密码管理器。Android 只允许同一包名用同一签名升级；密钥丢失后已经安装的用户无法
再收到更新，只能换一个 `applicationId` 重新发一个新应用。

不要把 keystore 或密码放进 GitHub secrets、issue、日志或任何远端。真实设备上的
覆盖安装才需要这个密钥，CI 构建的包一律 debug 签名。

**换密钥**：密钥泄露或丢失时，删除 `android/` 下的 keystore 和 `key.properties`，
重新生成，更新 `tool/release.sh` 里的 `EXPECTED_CERT_SHA256` 和本文的指纹，并同时
更换 `applicationId` —— 旧包名已经无法用新密钥更新。

## 发版步骤

1. 改 `pubspec.yaml` 的 `version`（例如 `0.4.1+5`），在 `CHANGELOG.md` 加同版本的
   `## 0.4.1 - YYYY-MM-DD` 段落。
2. 提交并推送 `master`。
3. 打 tag 并推送：

   ```bash
   git tag -a v0.4.1 -m "文衡 0.4.1"
   git push origin v0.4.1
   ```

4. 在本机发布：

   ```bash
   tool/release.sh
   ```

   脚本依次检查 `android/key.properties` 和 keystore 存在、工作区干净、`HEAD` 正好
   在 `v<version>` tag 上、CHANGELOG 有对应段落；然后跑格式检查、`flutter analyze`、
   `flutter test`，构建 arm64 release APK，用 `apksigner` 验签（要求 v2 通过且证书
   SHA-256 等于 `EXPECTED_CERT_SHA256`）、确认 APK 只有 arm64-v8a，生成
   `dist/essay_trainer-<version>-arm64-v8a.apk` 和 `dist/SHA256SUMS`，最后用本机
   `gh release create` 创建 Release（说明取 CHANGELOG 段落，附哈希和证书指纹）。

5. 确认：

   ```bash
   gh release view v0.4.1
   ```

只构建不发布：

```bash
tool/release.sh --no-publish
```

重发同一个版本：先 `gh release delete v0.4.1 --yes`，再跑脚本。不要拿同一个 tag
指向新提交后复用旧 Release。

## 本机环境

- Flutter 3.35.6、JDK 17、Android SDK 36、NDK 27.0.12077973
- `ANDROID_HOME`（或 `ANDROID_SDK_ROOT`）指向 SDK
- `android/key.properties` 和 keystore 就位

Linux 上跑 SQLite 测试需要 `libsqlite3`；本仓库的 `.tooling/native/libsqlite3.so`
软链存在时脚本会自动加进 `LD_LIBRARY_PATH`。

## 用户怎么校验

```bash
sha256sum -c SHA256SUMS
apksigner verify --print-certs essay_trainer-0.4.0-arm64-v8a.apk
# Signer #1 certificate SHA-256 digest: bd30066f4f899289536cc73de68780a25a534447e646e6eac8686d9350072c1f
```

`apksigner` 在 Android SDK 的 `build-tools/<version>/` 下。证书指纹以 Release 说明里
的值为准。

## Nightly

`.github/workflows/nightly.yml` 每天 03:00（Asia/Shanghai）和手动触发时构建
arm64-v8a 的 debug APK，命名 `essay_trainer-nightly-<日期>-<commit>-arm64-v8a.apk`，
带 `SHA256SUMS`，作为 Actions artifact 保留 14 天。它不读取任何签名密钥，不创建
Release。手动触发：

```bash
gh workflow run nightly.yml
```

## 限制

- 只发布 arm64-v8a，32 位设备和模拟器需要自行构建。
- 包名仍是 `com.example.essay_trainer`，不是商店标识；更换包名会让已安装用户
  变成另一个应用，需要重装。
- 只有 APK，没有 AAB 和 Play Store 发布链路。
