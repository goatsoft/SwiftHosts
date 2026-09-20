#!/usr/bin/env bash
set -euo pipefail

APP="${APP:-.build/DerivedData/Build/Products/Release/SwiftHosts.app}"
DIST="${DIST:-dist}"
RELEASE_TAG="${RELEASE_TAG:-v0.1.0}"
VERSION="${RELEASE_TAG#v}"

if [ ! -d "$APP" ]; then
    echo "Error: Application bundle not found at $APP" >&2
    exit 1
fi

mkdir -p "$DIST"
DMG_PATH="$DIST/SwiftHosts-${VERSION}.dmg"

# Prepare staging directory
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Copying $APP to DMG staging..."
cp -R "$APP" "$STAGING_DIR/SwiftHosts.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG image $DMG_PATH..."
rm -f "$DMG_PATH"
hdiutil create -volname "SwiftHosts $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null

IDENTITY="${RELEASE_SIGNING_IDENTITY:-${CODE_SIGN_IDENTITY:-}}"
if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "-" ]; then
    echo "Signing DMG image with identity: $IDENTITY..."
    codesign -s "$IDENTITY" --timestamp "$DMG_PATH"
else
    echo "Ad-hoc signing DMG image..."
    codesign --force --sign - "$DMG_PATH"
fi

echo "Created DMG: $DMG_PATH"
