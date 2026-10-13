#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

xcodegen generate
xcodebuild \
  -project QuietReader.xcodeproj \
  -scheme QuietReader \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$(find build/device/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "未找到设备构建产物" >&2
  exit 1
fi

# Debug 专用 dylib 在第三方重签名时易被漏签导致 dyld 拒载闪退，Release 构建不含这些，兜底再清一次
rm -f "$APP_PATH/__preview.dylib" "$APP_PATH"/*.debug.dylib

for resource in community-sources.json demo-source.json Assets.car; do
  if [[ ! -e "$APP_PATH/$resource" ]]; then
    echo "应用包缺少资源：$resource" >&2
    exit 1
  fi
done

rm -rf build/package build/QuietReader-unsigned.ipa
mkdir -p build/package/Payload
cp -R "$APP_PATH" build/package/Payload/

cd build/package
/usr/bin/zip -qry ../QuietReader-unsigned.ipa Payload
echo "已生成 build/QuietReader-unsigned.ipa"
