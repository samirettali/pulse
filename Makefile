APP_NAME := Pulse
# CONFIG=debug drops the optimiser: a rebuild takes a couple of seconds instead
# of tens of them. Nothing else differs — there is no DEBUG-gated code.
CONFIG   ?= release
BUNDLE   := dist/$(APP_NAME).app
BINARY   := .build/$(CONFIG)/$(APP_NAME)
PLIST    := Packaging/Info.plist
VERSION  := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(PLIST))
DMG      := dist/$(APP_NAME)-$(VERSION).dmg
ZIP      := dist/$(APP_NAME).zip

# Developer ID is used for dev builds too, so the designated requirement is the
# same one the shipped app gets. Falls back to Apple Development, then ad-hoc.
# `release` insists on the real Developer ID certificate.
SIGN_IDENTITY  ?= Developer ID Application
# notarytool keychain profile. Shared across apps on purpose: the credentials
# belong to the Apple account, not to any one app, so a per-app name would mean
# several keychain items holding identical secrets and a fresh machine needing
# one `store-credentials` run per app.
NOTARY_PROFILE ?= notary

.PHONY: build bundle run dev verify release dmg clean

build:
	swift build -c $(CONFIG)

# No entitlements file: Pulse only makes outgoing network connections, which
# the hardened runtime allows unclaimed. It is not sandboxed, so no
# com.apple.security.network.client either.
bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp $(PLIST) $(BUNDLE)/Contents/Info.plist
	@identity="$(SIGN_IDENTITY)"; timestamp="--timestamp"; \
	if ! security find-identity -p codesigning | grep -q "$$identity"; then \
		if security find-identity -p codesigning | grep -q "Apple Development"; then \
			echo "warning: '$$identity' not found — signing with Apple Development"; \
			identity="Apple Development"; \
		else \
			echo "warning: no signing identity found — ad-hoc signing"; \
			identity="-"; timestamp="--timestamp=none"; \
		fi; \
	fi; \
	set -x; \
	codesign --force --options runtime $$timestamp --sign "$$identity" $(BUNDLE)

run: bundle
	@pkill -x $(APP_NAME) || true
	open $(BUNDLE)

# Fast loop while working on a change: unoptimised build, running copy replaced.
#
# Quitting first is not optional. Two instances mean two menu bar items, both
# holding their own websocket connections. `open` would not have helped either:
# faced with a running app of the same bundle id it just activates it, so you
# would be looking at the old binary believing you were testing the new one.
dev:
	@pkill -x $(APP_NAME) || true
	$(MAKE) bundle CONFIG=debug
	open $(BUNDLE)

verify:
	codesign --verify --strict --verbose=2 $(BUNDLE)
	codesign --display --verbose=2 $(BUNDLE)

# Notarised, stapled disk image. Both the .app and the .dmg are notarised: the
# ticket stapled to the DMG only covers the app while it sits on the mounted
# image, so the app needs its own ticket to launch offline once dragged out.
release: bundle
	@security find-identity -p codesigning | grep -q "Developer ID Application" \
		|| { echo "error: no 'Developer ID Application' certificate in the keychain"; exit 1; }
	$(MAKE) verify
	rm -f $(ZIP)
	ditto -c -k --keepParent $(BUNDLE) $(ZIP)
	xcrun notarytool submit $(ZIP) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(BUNDLE)
	rm -f $(ZIP)
	$(MAKE) dmg
	xcrun notarytool submit $(DMG) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(DMG)
	spctl --assess --type open --context context:primary-signature -vv $(DMG)
	spctl --assess --type exec -vv $(BUNDLE)

dmg:
	Packaging/make-dmg.sh $(APP_NAME) $(BUNDLE) $(DMG)
	codesign --force --timestamp --sign "$(SIGN_IDENTITY)" $(DMG)

clean:
	rm -rf .build dist
