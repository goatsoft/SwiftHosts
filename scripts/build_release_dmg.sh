#!/bin/bash
set -e

VERSION=$(git grep -h "MARKETING_VERSION =" SwiftHosts.xcodeproj/project.pbxproj | head -n 1 | awk '{print $3}' | tr -d ';')
if [ -z "$VERSION" ]; then
    VERSION="0.1.1"
fi

echo "==> Building SwiftHosts v${VERSION} Release DMG..."

rm -rf build SwiftHosts-*.dmg
xcodebuild -project SwiftHosts.xcodeproj -scheme SwiftHosts -configuration Release -derivedDataPath ./build build -quiet

APP_PATH="./build/Build/Products/Release/SwiftHosts.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: SwiftHosts.app build failed."
    exit 1
fi

echo "==> Clearing quarantine attributes..."
xattr -cr "$APP_PATH"

echo "==> Ad-hoc signing app bundle..."
codesign --force --deep --options runtime --sign - "$APP_PATH"

DMG_NAME="SwiftHosts-v${VERSION}.dmg"
STAGING_DIR="./build/DMG_Staging"
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Packaging into ${DMG_NAME}..."
hdiutil create -volname "SwiftHosts" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME" -quiet

codesign --force --sign - "$DMG_NAME"

rm -rf "$STAGING_DIR"
echo "==> Success! Release DMG created at ${DMG_NAME} (Version: ${VERSION})"
