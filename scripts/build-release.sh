#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_DIR="$BUILD_DIR/archive"
EXPORT_DIR="$BUILD_DIR/export"
APP_NAME="Coinbar.app"
ZIP_NAME="Coinbar-macOS-unsigned.zip"

rm -rf "$ARCHIVE_DIR" "$EXPORT_DIR"
mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR"

xcodebuild \
  -project "$ROOT_DIR/Coinbar.xcodeproj" \
  -scheme Coinbar \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found at: $APP_PATH" >&2
  exit 1
fi

cp -R "$APP_PATH" "$EXPORT_DIR/$APP_NAME"

ditto -c -k --sequesterRsrc --keepParent \
  "$EXPORT_DIR/$APP_NAME" \
  "$BUILD_DIR/$ZIP_NAME"

echo "Built app: $EXPORT_DIR/$APP_NAME"
echo "Created archive: $BUILD_DIR/$ZIP_NAME"
