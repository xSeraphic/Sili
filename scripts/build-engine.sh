#!/bin/bash
# Packages Sili Engine (Libraries.tar.gz + WhiskyWineVersion.plist) from a CrossOver-source Wine build.
#
# Engine 4.x is Wine built from CodeWeavers' open-source CrossOver code (LGPL), plus DXMT, DXVK and
# MoltenVK, using the build scripts from https://github.com/willburnsucla/steam-wine (LGPL-2.1+):
#
#   git clone https://github.com/willburnsucla/steam-wine ~/Developer/steam-wine
#   brew install bison flex pkgconf mingw-w64 meson ninja cmake autoconf glslang
#   xcodebuild -downloadComponent MetalToolchain
#   ~/Developer/steam-wine/scripts/build-all.sh          # ~20 min on an M4 Max, ~10 GB
#
# Then: scripts/build-engine.sh [engine_version]  ->  dist/Libraries.tar.gz, dist/WhiskyWineVersion.plist
# Upload both to the "engine-4" GitHub release.
#
# Engine 3.x (Gcenx wine-staging + DXMT) is in git history if ever needed.
set -euo pipefail

ENGINE_VERSION="${1:-4.0.0}"
SW="${STEAM_WINE:-$HOME/Developer/steam-wine}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
L="$WORK/Libraries"
W="$L/Wine"

[ -x "$SW/dist/bin/wine" ] || { echo "error: build steam-wine first ($SW/scripts/build-all.sh)" >&2; exit 1; }
WINE_DESC="$("$SW/dist/bin/wine" --version 2>/dev/null || echo wine)"
mkdir -p "$W" "$DIST"

echo "==> Copying Wine ($WINE_DESC)"
cp -R "$SW/dist/bin" "$SW/dist/lib" "$SW/dist/share" "$W/"
# Build-only tools and import libraries aren't needed at runtime.
( cd "$W/bin" && rm -f function_grep.pl widl winebuild winecpp winedump wineg++ winegcc winemaker wmc wrc )
find "$W/lib/wine" -name '*.a' -delete
WINELIB="$W/lib/wine"

echo "==> Direct3D sets (WineD3D and DXMT; DXMT active)"
ORIG="$WINELIB/wined3d-originals"   # left by steam-wine's install-dxmt.sh when DXMT was switched on
for arch in x86_64-windows i386-windows; do
  dxmt_src="$SW/dist/dxmt/$arch"; [ "$arch" = i386-windows ] && dxmt_src="$SW/dist/dxmt/i386/i386-windows"
  mkdir -p "$L/WineD3D/$arch" "$L/DXMT/$arch"
  for dll in d3d11 dxgi d3d10core; do
    if [ -f "$ORIG/$arch/$dll.dll" ]; then cp "$ORIG/$arch/$dll.dll" "$L/WineD3D/$arch/"
    else cp "$WINELIB/$arch/$dll.dll" "$L/WineD3D/$arch/"; fi
    cp "$dxmt_src/$dll.dll" "$L/DXMT/$arch/"
    cp "$dxmt_src/$dll.dll" "$WINELIB/$arch/"
  done
  cp "$dxmt_src/winemetal.dll" "$WINELIB/$arch/"
done
cp "$SW/dist/dxmt/x86_64-unix/winemetal.so" "$WINELIB/x86_64-unix/"
rm -rf "$ORIG"

echo "==> DXVK (per-bottle option in Bottle Configuration)"
mkdir -p "$L/DXVK"
cp -R "$SW/dist/dxvk/x64" "$SW/dist/dxvk/x32" "$L/DXVK/"

echo "==> Bundling dylibs and making the engine relocatable"
DEPS="$SW/deps/lib"
for lib in "$DEPS"/*.dylib; do
  [ -L "$lib" ] && continue                        # copy real files; recreate soname links below
  cp "$lib" "$W/lib/"
done
for link in "$DEPS"/*.dylib; do
  [ -L "$link" ] || continue
  ( cd "$W/lib" && ln -sf "$(basename "$(readlink "$link")")" "$(basename "$link")" )
done
fix_refs() {   # rewrite absolute deps paths to @rpath/<name>
  local f="$1"
  { otool -L "$f" | awk 'NR>1{print $1}' | grep "^$DEPS/" || true; } | while read -r ref; do
    install_name_tool -change "$ref" "@rpath/$(basename "$ref")" "$f" 2>/dev/null
  done
  { otool -l "$f" | awk '/LC_RPATH/{getline; getline; print $2}' | grep "^$SW" || true; } | while read -r rp; do
    install_name_tool -delete_rpath "$rp" "$f" 2>/dev/null
  done
}
for lib in "$W"/lib/*.dylib; do
  [ -L "$lib" ] && continue
  install_name_tool -id "@rpath/$(basename "$lib")" "$lib" 2>/dev/null
  fix_refs "$lib"
  install_name_tool -add_rpath "@loader_path/" "$lib" 2>/dev/null || true
done
for so in "$WINELIB"/x86_64-unix/*.so "$W"/bin/wine "$W"/bin/wineserver; do
  fix_refs "$so"
  otool -l "$so" | grep -q '@loader_path/../../' || install_name_tool -add_rpath "@loader_path/../../" "$so" 2>/dev/null || true
done
if grep -rlq "$SW" "$WINELIB/x86_64-unix" "$W/lib"/*.dylib 2>/dev/null; then
  echo "warning: some files still mention $SW (usually just strings in build info)"
fi

echo "==> Re-signing (install_name_tool invalidates signatures)"
find "$W" -type f \( -name '*.dylib' -o -name '*.so' \) -exec codesign --force --sign - {} \; 2>/dev/null
codesign --force --sign - "$W/bin/wine" "$W/bin/wineserver" 2>/dev/null || true

echo "==> Tools"
mkdir -p "$L/Tools"
cp "$ROOT/tools/steamwebhelper-wrapper.exe" "$L/Tools/"

cat > "$L/WhiskyWineVersion.plist" <<PLIST
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
		<string>crossover-source ${WINE_DESC} + dxmt + dxvk + moltenvk</string>
	</dict>
</dict>
</plist>
PLIST

echo "==> Packing"
cp "$L/WhiskyWineVersion.plist" "$DIST/WhiskyWineVersion.plist"
tar -czf "$DIST/Libraries.tar.gz" -C "$WORK" Libraries
ls -lh "$DIST/Libraries.tar.gz" "$DIST/WhiskyWineVersion.plist"
