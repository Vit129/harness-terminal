.PHONY: build bench preview preview-stop preview-clean release package dmg sign appcast finalize icon clean

build:
	swift build

bench:
	HARNESS_BENCHMARKS=1 swift test -c release --filter HarnessBenchmarks

preview:
	./Scripts/preview.sh

preview-stop:
	-pkill -f '$(CURDIR)/.harness-preview/HarnessPreview.app/Contents/MacOS/Harness' 2>/dev/null
	-pkill -f '$(CURDIR)/.harness-preview/HarnessPreview.app/Contents/MacOS/HarnessDaemon' 2>/dev/null

preview-clean:
	rm -rf .harness-preview

icon:
	./Scripts/generate-app-icon.sh

release: icon
	./Scripts/build-release.sh

package: release

dmg: release
	./Scripts/create-dmg.sh

sign: release
	./Scripts/sign-and-notarize.sh

# Generate/refresh the Sparkle appcast from signed archives in ./dist (see the script header).
appcast:
	./Scripts/generate-appcast.sh

# Finalize a release: notarize + staple the DMG, re-upload to the GitHub release, build the
# appcast, optionally deploy it to the site. Needs ASC_ISSUER_ID (or APPLE_ID/APPLE_TEAM_ID/
# APPLE_APP_PASSWORD) and one keychain Allow for the Sparkle key. See Scripts/finalize-release.sh.
finalize:
	./Scripts/finalize-release.sh

clean:
	swift package clean
	rm -rf Harness.app Harness.dmg .dmg-staging .icon-staging.iconset
