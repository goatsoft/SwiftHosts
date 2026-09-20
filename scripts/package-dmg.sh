#!/usr/bin/env bash
# Package SwiftHosts.app into a distributable DMG image in dist/
set -euo pipefail

APP="${APP:-.build/DerivedData/Build/Products/Release/SwiftHosts.app}"
DIST="${DIST:-dist}"
RELEASE_TAG="${RELEASE_TAG:-v0.1.0}"
VERSION="${RELEASE_TAG#v}"

[ -d "$APP" ] || { echo "error: $APP bundle not found" >&2; exit 1; }

mkdir -p "$DIST"
DMG_NAME="SwiftHosts-${VERSION}.dmg"
DMG_PATH="$DIST/$DMG_NAME"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

STAGE_DIR="$WORK_DIR/stage"
mkdir -p "$STAGE_DIR"

echo "Copying $APP to DMG staging..."
ditto "$APP" "$STAGE_DIR/SwiftHosts.app"

# Create Applications shortcut symlink
ln -s /Applications "$STAGE_DIR/Applications"

echo "Creating DMG image $DMG_PATH..."
hdiutil create -volname "SwiftHosts ${VERSION}" \
  -srcfolder "$STAGE_DIR" \
  -format UDZO \
  -ov "$DMG_PATH" >/dev/null

echo "Created DMG: $DMG_PATH"
