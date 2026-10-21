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
ENGINE_VERSION="${3:-3.1.0}"

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

# Ship both Direct3D 10/11 implementations; the app switches between them (Settings > Graphics).
#   Libraries/WineD3D - Wine's own d3d11/dxgi/d3d10core
#   Libraries/DXMT    - DXMT's versions (Direct3D to Metal) - installed by default
# winemetal.dll/.so are only used by DXMT's DLLs, so they always live in Wine's lib folder.
WINELIB="$WORK/Libraries/Wine/lib/wine"
for arch in x86_64-windows i386-windows; do
  mkdir -p "$WORK/Libraries/WineD3D/$arch" "$WORK/Libraries/DXMT/$arch"
  for dll in d3d11.dll dxgi.dll d3d10core.dll; do
    cp "$WINELIB/$arch/$dll" "$WORK/Libraries/WineD3D/$arch/$dll"
    cp "$WORK/$DXMT_VERSION/$arch/$dll" "$WORK/Libraries/DXMT/$arch/$dll"
  done
  cp "$WORK/$DXMT_VERSION/$arch/winemetal.dll" "$WINELIB/$arch/"
  cp "$WORK/Libraries/DXMT/$arch/"*.dll "$WINELIB/$arch/"   # DXMT active by default
done
cp "$WORK/$DXMT_VERSION/x86_64-unix/winemetal.so" "$WINELIB/x86_64-unix/"

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
