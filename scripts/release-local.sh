#!/usr/bin/env bash
#
# Cut a local release: build a universal ad-hoc app, EdDSA-sign it for Sparkle,
# update the appcast, and publish a GitHub Release.
#
# This is the un-notarized path (no Apple Developer ID needed). The build is
# ad-hoc signed, so users right-click → Open on first launch. For notarized
# releases, use the GitHub Actions workflow instead (see RELEASING.md).
#
# Prereqs: Xcode, xcodegen, gh (authenticated), and Sparkle keys in the keychain
# (run .tools/sparkle/bin/generate_keys once). The Sparkle tools are auto-fetched.
#
# Usage:  ./scripts/release-local.sh 0.2.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release-local.sh <version>  (e.g. 0.2.0)}"
TAG="v$VERSION"
APP_NAME="Prayer Times"
REPO="tareq1988/prayer-times-macos"
SPARKLE_VERSION="2.6.4"

echo "→ Releasing $TAG"

# 0. Ensure version in project.yml matches.
if ! grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml; then
  echo "✗ project.yml MARKETING_VERSION != $VERSION. Bump it first, commit, then re-run."
  exit 1
fi

# 1. Sparkle tools.
if [[ ! -x .tools/sparkle/bin/generate_appcast ]]; then
  echo "→ Fetching Sparkle tools…"
  mkdir -p .tools && curl -fsSL -o .tools/sparkle.tar.xz \
    "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
  mkdir -p .tools/sparkle && tar -xf .tools/sparkle.tar.xz -C .tools/sparkle
fi

# 2. Build universal, ad-hoc signed, Release.
echo "→ Building universal Release…"
xcodegen generate >/dev/null
rm -rf build && mkdir -p build/dist
xcodebuild -project PrayerTimes.xcodeproj -scheme PrayerTimes -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/dd \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES \
  build >/dev/null
echo "✓ Built ($(lipo -archs "build/dd/Build/Products/Release/$APP_NAME.app/Contents/MacOS/$APP_NAME"))"

# 3. Zip.
ZIP="build/dist/PrayerTimes-$VERSION.zip"
ditto -c -k --keepParent "build/dd/Build/Products/Release/$APP_NAME.app" "$ZIP"

# 4. Sign + appcast (private key from keychain), pointing at the release asset URL.
.tools/sparkle/bin/generate_appcast \
  --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
  build/dist >/dev/null
cp build/dist/appcast.xml docs/appcast.xml
echo "✓ Appcast updated"

# 5. Commit + push the appcast.
git add docs/appcast.xml
git commit -m "chore(release): appcast for $TAG" || echo "  (no appcast change)"
git push origin main

# 6. Publish the GitHub Release (creates the tag at current main).
gh release create "$TAG" "$ZIP" \
  --title "Prayer Times $TAG" \
  --generate-notes \
  --target main

echo "✓ Released: https://github.com/$REPO/releases/tag/$TAG"
