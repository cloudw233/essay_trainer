#!/usr/bin/env bash
# 在本机构建、验签并发布正式版 APK。
#
#   tool/release.sh              构建 + 验签 + 创建 GitHub Release
#   tool/release.sh --no-publish 只构建并验签，产物留在 dist/
#
# 发布密钥只存在本机：android/key.properties 和 android/app/essay-release.jks。
# GitHub Actions 不持有密钥，也不创建 Release（它只构建 nightly）。
set -euo pipefail
cd "$(dirname "$0")/.."

# 换密钥时同步更新这里和 docs/releasing.md。
EXPECTED_CERT_SHA256="bd30066f4f899289536cc73de68780a25a534447e646e6eac8686d9350072c1f"

publish=1
for arg in "$@"; do
  case "$arg" in
    --no-publish) publish=0 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

step "检查前置条件"
[ -f android/key.properties ] || fail "缺少 android/key.properties，见 docs/releasing.md"
[ -f android/app/essay-release.jks ] || fail "缺少 android/app/essay-release.jks"
[ -z "$(git status --porcelain)" ] || fail "工作区不干净，先提交或 stash"

version="$(sed -nE 's/^version:[[:space:]]+([^+[:space:]]+).*/\1/p' pubspec.yaml)"
[ -n "$version" ] || fail "读不到 pubspec.yaml 的 version"
tag="v$version"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null || fail "tag $tag 不存在"
[ "$(git rev-parse "$tag^{commit}")" = "$(git rev-parse HEAD)" ] || fail "HEAD 不在 $tag 上"
grep -qE "^## ${version//./\\.}([ -]|$)" CHANGELOG.md || fail "CHANGELOG.md 没有 $version 段落"
command -v flutter >/dev/null || fail "PATH 里没有 flutter"
command -v gh >/dev/null || fail "PATH 里没有 gh"
[ -n "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ] || fail "需要设置 ANDROID_HOME 或 ANDROID_SDK_ROOT"
sdk="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"

# 本机 SQLite 测试用的软链，别的机器上没有就跳过。
if [ -f .tooling/native/libsqlite3.so ]; then
  export LD_LIBRARY_PATH="$PWD/.tooling/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

step "质量检查"
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub

step "构建 release APK"
flutter build apk --release --target-platform android-arm64

apk="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$apk" ] || fail "构建产物不存在: $apk"

step "验签与架构检查"
apksigner="$(find "$sdk/build-tools" -maxdepth 2 -name apksigner | sort -V | tail -n1)"
[ -n "$apksigner" ] || fail "找不到 apksigner"
"$apksigner" verify --verbose --print-certs "$apk" | tee build/apksigner.txt
grep -q 'Verified using v2 scheme (APK Signature Scheme v2): true' build/apksigner.txt \
  || fail "APK 没有通过 v2 签名校验"
cert="$(sed -n 's/.*certificate SHA-256 digest: //p' build/apksigner.txt | head -n1)"
[ "$cert" = "$EXPECTED_CERT_SHA256" ] || fail "签名证书不匹配: $cert"
abis="$(unzip -Z1 "$apk" | sed -n 's#^lib/\([^/]*\)/.*#\1#p' | sort -u)"
[ "$abis" = "arm64-v8a" ] || fail "期望只有 arm64-v8a，实际: $abis"

step "打包产物"
mkdir -p dist
apk_name="essay_trainer-${version}-arm64-v8a.apk"
cp "$apk" "dist/$apk_name"
(cd dist && sha256sum "$apk_name" > SHA256SUMS)
apk_sha="$(awk '{print $1}' dist/SHA256SUMS)"
printf 'APK: %s\nSHA-256: %s\n签名证书: %s\n' "dist/$apk_name" "$apk_sha" "$cert"

step "生成 release notes"
{
  echo "文衡 $version 的正式签名发行版（arm64-v8a，Android 7.0+）。"
  echo
  awk -v ver="$version" '
    $0 ~ "^## " ver "([ -]|$)" { found = 1; next }
    found && /^## / { exit }
    found { print }
  ' CHANGELOG.md
  echo
  echo "### 安装"
  echo
  echo "1. 下载 \`$apk_name\`。"
  echo "2. 在手机上打开，允许“安装未知应用”后安装；旧版本可直接覆盖升级。"
  echo "3. 首次使用需要进入「设置 → DeepSeek 连接」填写自己的 API Key。"
  echo
  echo "### 校验"
  echo
  echo '```text'
  echo "APK SHA-256:      $apk_sha"
  echo "签名证书 SHA-256: $cert"
  echo '```'
  echo
  echo '本地校验：'
  echo
  echo '```bash'
  echo "sha256sum -c SHA256SUMS"
  echo "apksigner verify --print-certs $apk_name"
  echo '```'
} > dist/RELEASE_NOTES.md
cat dist/RELEASE_NOTES.md

if [ "$publish" -eq 0 ]; then
  echo
  echo "已跳过发布，产物在 dist/。"
  exit 0
fi

if gh release view "$tag" >/dev/null 2>&1; then
  fail "$tag 已经有 Release；先 gh release delete $tag --yes 再重跑"
fi

step "创建 GitHub Release $tag"
gh release create "$tag" "dist/$apk_name" dist/SHA256SUMS \
  --title "文衡 $version" \
  --notes-file dist/RELEASE_NOTES.md \
  --verify-tag
gh release view "$tag" --json url -q .url
