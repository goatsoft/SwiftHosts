# SwiftHosts Makefile
CONFIG ?= Release
-include signing.local.mk

DERIVED := .build/DerivedData
APP := $(DERIVED)/Build/Products/$(CONFIG)/SwiftHosts.app
DIST := dist
RELEASE_TAG ?= v0.1.0

CODE_SIGN_IDENTITY ?= -
RELEASE_SIGNING_IDENTITY ?= $(CODE_SIGN_IDENTITY)
DEVELOPMENT_TEAM ?=

.PHONY: build release dmg clean

build:
	xcodebuild -project SwiftHosts.xcodeproj -scheme SwiftHosts -configuration $(CONFIG) \
	  -derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=arm64' ARCHS=arm64 build

# Release build: Hardened Runtime enabled, signed with Developer ID identity from local Keychain.
release:
	xcodebuild -project SwiftHosts.xcodeproj -scheme SwiftHosts -configuration Release \
	  -derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=arm64' ARCHS=arm64 \
	  ENABLE_HARDENED_RUNTIME=YES \
	  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
	  CODE_SIGN_STYLE=Manual \
	  CODE_SIGN_IDENTITY="$(RELEASE_SIGNING_IDENTITY)" \
	  DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)" \
	  OTHER_CODE_SIGN_FLAGS="$(if $(filter -,$(RELEASE_SIGNING_IDENTITY)),,--timestamp)" \
	  build
	@if [ -f scripts/check-release-signing.py ] && [ "$(RELEASE_SIGNING_IDENTITY)" != "-" ]; then \
	  DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)" CODE_SIGN_IDENTITY="$(RELEASE_SIGNING_IDENTITY)" python3 scripts/check-release-signing.py --verify "$(APP)"; \
	fi

dmg: release
	RELEASE_TAG="$(RELEASE_TAG)" APP="$(APP)" DIST="$(DIST)" RELEASE_SIGNING_IDENTITY="$(RELEASE_SIGNING_IDENTITY)" ./scripts/package-dmg.sh

clean:
	rm -rf .build $(DIST)
