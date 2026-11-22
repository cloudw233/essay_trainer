# 发布签名发行版

发行版由 GitHub Actions 在 `v*.*.*` tag 上构建并签名，产物是 arm64-v8a 的
release APK 和一份 `SHA256SUMS`，通过 GitHub Release 发布。

## 签名材料

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

GitHub Actions 用这 4 个 repository secret：

- `ANDROID_KEYSTORE_BASE64`：`base64 -w0 android/app/essay-release.jks` 的结果
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

**必须备份**：把 `android/app/essay-release.jks` 和 `android/key.properties` 存进
密码管理器。Android 只允许同一包名用同一签名升级；密钥丢失后已经安装的用户
无法再收到更新，只能换一个 `applicationId` 重新发一个新应用。GitHub secret 只能
覆盖写入，不能读回，别把它当唯一备份。

**换密钥**：如果密钥泄露或丢失，删除 `android/` 下的 keystore 和 `key.properties`，
换新的 alias 重新生成，更新 4 个 secret 和 `release.yml` 里的
`EXPECTED_CERT_SHA256`，并同时更换 `applicationId` —— 旧包名已经无法用新密钥更新。

## 发版步骤

1. 改 `pubspec.yaml` 的 `version`（例如 `0.4.1+5`），在 `CHANGELOG.md` 加同版本
   的 `## 0.4.1 - YYYY-MM-DD` 段落。
2. 本地过一遍 `dart format --output=none --set-exit-if-changed lib test tool`、
   `flutter analyze --no-pub`、`flutter test --no-pub`。
3. 提交并推送 `master`。
4. 打 tag 并推送：

   ```bash
   git tag -a v0.4.1 -m "文衡 0.4.1"
   git push origin v0.4.1
   ```

5. `Release` workflow 会依次：

   - 校验 tag 版本和 `pubspec.yaml` 一致、`CHANGELOG.md` 有对应段落；
   - 跑格式检查、`flutter analyze`、`flutter test`；
   - 从 secret 还原 keystore，构建 `flutter build apk --release --target-platform android-arm64`；
   - 用 `apksigner` 验签，要求 v2 方案通过且证书 SHA-256 等于
     `EXPECTED_CERT_SHA256`，否则中止（防止 secret 缺失时静默发出 debug 签名的包）；
   - 生成 `essay_trainer-<version>-arm64-v8a.apk` 和 `SHA256SUMS`；
   - 用 `gh release create` 建 Release，标题 `文衡 <version>`，说明取 CHANGELOG
     对应段落，附安装步骤、APK 哈希和证书指纹。

6. 确认：

   ```bash
   gh release view v0.4.1
   gh run list --workflow Release
   ```

重跑失败的发布：先 `gh release delete v0.4.1 --yes`（如果 Release 已建），再
`gh workflow run release.yml -f tag=v0.4.1`。不要复用同一个 tag 指到新提交。

## 本地构建签名 APK

本机需要 `android/key.properties`：

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
# build/app/outputs/flutter-apk/app-release.apk
```

没有 `android/key.properties` 时 release 构建回退到 debug 签名，方便
`flutter run --release` 调试；这种包不能发布。

## 用户怎么校验

```bash
sha256sum -c SHA256SUMS
apksigner verify --print-certs essay_trainer-0.4.0-arm64-v8a.apk
# Signer #1 certificate SHA-256 digest: bd30066f4f899289536cc73de68780a25a534447e646e6eac8686d9350072c1f
```

`apksigner` 在 Android SDK 的 `build-tools/<version>/` 下。证书指纹以 Release 说明里
的值为准。

## 限制

- 只构建 arm64-v8a，32 位设备和模拟器需要自行构建。
- 包名仍是 `com.example.essay_trainer`，不是商店标识；更换包名会让已安装用户
  变成另一个应用，需要重装。
- Release 目前只提供 APK，没有 AAB 和 Play Store 发布链路。
