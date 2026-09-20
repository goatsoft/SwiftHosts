#!/bin/bash
set -euo pipefail

VERSION=$(git grep -h "MARKETING_VERSION =" SwiftHosts.xcodeproj/project.pbxproj | head -n 1 | awk '{print $3}' | tr -d ';')
if [ -z "$VERSION" ]; then
    VERSION="0.1.1"
fi
RELEASE_TAG="v${VERSION}"

echo "==> Building SwiftHosts ${RELEASE_TAG} Release via Makefile (Developer ID Signed)..."

make clean
make dmg RELEASE_TAG="${RELEASE_TAG}"

DMG_PATH="dist/SwiftHosts-${VERSION}.dmg"
ZIP_PATH="dist/SwiftHosts-${RELEASE_TAG}.zip"

echo "==> Creating matching zip archive in dist/..."
(cd .build/DerivedData/Build/Products/Release && zip -r -9 "${PWD}/dist/SwiftHosts-${RELEASE_TAG}.zip" "SwiftHosts.app" >/dev/null)
(cd dist && shasum -a 256 "SwiftHosts-${VERSION}.dmg" "SwiftHosts-${RELEASE_TAG}.zip" > SHA256SUMS.txt)

echo "==> Success! Release artifacts ready in dist/:"
ls -lh dist/
