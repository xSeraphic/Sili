#!/bin/bash
# Builds Libraries.tar.gz (the Wine engine Whisky downloads on first launch) from
# open-source upstream releases, plus WhiskyWineVersion.plist.
#
#   Wine : Gcenx/macOS_Wine_builds (wine-staging)  https://github.com/Gcenx/macOS_Wine_builds
#   DXMT : 3Shain/dxmt (DirectX 10/11 -> Metal)      https://github.com/3Shain/dxmt
#
# Usage: scripts/build-engine.sh [wine_version] [dxmt_version] [engine_semver]
# Then upload dist/Libraries.tar.gz and dist/WhiskyWineVersion.plist to the "engine" release.
set -euo pipefail

WINE_VERSION="${1:-11.18}"
DXMT_VERSION="${2:-v0.80}"
ENGINE_VERSION="${3:-3.0.0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
DIST="$ROOT/dist"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DIST"

echo "==> Downloading Wine Staging $WINE_VERSION"
curl -fL --progress-bar -o "$WORK/wine.tar.xz" \
  "https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-staging-${WINE_VERSION}-osx64.tar.xz"

echo "==> Downloading DXMT $DXMT_VERSION"
curl -fL --progress-bar -o "$WORK/dxmt.tar.gz" \
  "https://github.com/3Shain/dxmt/releases/download/${DXMT_VERSION}/dxmt-${DXMT_VERSION}-builtin.tar.gz"

echo "==> Assembling Libraries/"
tar -xJf "$WORK/wine.tar.xz" -C "$WORK"
tar -xzf "$WORK/dxmt.tar.gz" -C "$WORK"
mkdir -p "$WORK/Libraries"
mv "$WORK/Wine Staging.app/Contents/Resources/wine" "$WORK/Libraries/Wine"

# DXMT "builtin" build: drop its DLLs over Wine's own d3d11/dxgi builtins.
WINELIB="$WORK/Libraries/Wine/lib/wine"
for arch in x86_64-windows i386-windows x86_64-unix; do
  [ -d "$WORK/$DXMT_VERSION/$arch" ] && cp -f "$WORK/$DXMT_VERSION/$arch/"* "$WINELIB/$arch/"
done

cat > "$WORK/Libraries/WhiskyWineVersion.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>version</key>
	<dict>
		<key>major</key>
		<integer>${ENGINE_VERSION%%.*}</integer>
		<key>minor</key>
		<integer>$(echo "$ENGINE_VERSION" | cut -d. -f2)</integer>
		<key>patch</key>
		<integer>$(echo "$ENGINE_VERSION" | cut -d. -f3)</integer>
		<key>preRelease</key>
		<string></string>
		<key>build</key>
		<string>wine-staging-${WINE_VERSION}+dxmt-${DXMT_VERSION}</string>
	</dict>
</dict>
</plist>
PLIST

echo "==> Packing"
cp "$WORK/Libraries/WhiskyWineVersion.plist" "$DIST/WhiskyWineVersion.plist"
tar -czf "$DIST/Libraries.tar.gz" -C "$WORK" Libraries
ls -lh "$DIST"
