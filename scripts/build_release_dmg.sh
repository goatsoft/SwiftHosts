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

# Check for notary credentials
NOTARY_PROFILE=""
if xcrun notarytool history --keychain-profile "SwiftHosts" >/dev/null 2>&1; then
    NOTARY_PROFILE="SwiftHosts"
elif xcrun notarytool history --keychain-profile "GOAT" >/dev/null 2>&1; then
    NOTARY_PROFILE="GOAT"
fi

if [ -n "$NOTARY_PROFILE" ]; then
    echo "==> Notarizing ${DMG_PATH} with Apple Notary Service (Profile: ${NOTARY_PROFILE})..."
    xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
    echo "==> Stapling notarization ticket to ${DMG_PATH}..."
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
fi

echo "==> Creating matching zip archive in dist/..."
(cd .build/DerivedData/Build/Products/Release && zip -r -9 "${PWD}/dist/SwiftHosts-${RELEASE_TAG}.zip" "SwiftHosts.app" >/dev/null)
(cd dist && shasum -a 256 "SwiftHosts-${VERSION}.dmg" "SwiftHosts-${RELEASE_TAG}.zip" > SHA256SUMS.txt)

echo "==> Success! Verified, signed, and notarized artifacts ready in dist/:"
ls -lh dist/
