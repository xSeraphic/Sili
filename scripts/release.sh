#!/bin/bash
# Publishes a Sili release: sets the version, builds and signs Sili.app,
# writes the Sparkle appcast, then tags, pushes and creates the GitHub release.
#
# Usage: scripts/release.sh 1.2.0
# Needs: Xcode, gh (signed in), Sparkle EdDSA key in the Keychain (account "sili"),
#        a CHANGELOG.md section "## [1.2.0] - YYYY-MM-DD".
set -euo pipefail

VERSION="${1:?Usage: scripts/release.sh MAJOR.MINOR.PATCH}"
REPO="xSeraphic/Sili"
KEY_ACCOUNT="sili"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/../Sili-release-build"
OUT="$ROOT/dist/release"
PBX="$ROOT/Whisky.xcodeproj/project.pbxproj"
cd "$ROOT"

die() { echo "error: $*" >&2; exit 1; }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 1.2.3"
[[ "$(git branch --show-current)" == "main" ]] || die "release from the main branch"
[[ -z "$(git status --porcelain)" ]] || die "working tree has uncommitted changes"
git rev-parse "v$VERSION" >/dev/null 2>&1 && die "tag v$VERSION already exists"

CURRENT="$(grep -m1 -o 'MARKETING_VERSION = [0-9.]*' "$PBX" | awk '{print $3}')"
if [[ "$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)" != "$VERSION" || "$CURRENT" == "$VERSION" ]]; then
  # Allow re-using the current number only for the very first release.
  git tag -l 'v*' | grep -q . && die "$VERSION is not newer than $CURRENT"
fi

# Release notes from CHANGELOG.md
NOTES="$(awk -v v="$VERSION" '
  $0 ~ "^## \\[" v "\\]" {f=1; next}
  f && /^## \[/ {exit}
  f {print}' CHANGELOG.md)"
[[ -n "${NOTES//[[:space:]]/}" ]] || die "add a '## [$VERSION] - date' section to CHANGELOG.md first"

# Bump the version and build number
BUILD_NO="$(grep -m1 -o 'CURRENT_PROJECT_VERSION = [0-9]*' "$PBX" | awk '{print $3}')"
BUILD_NO=$((BUILD_NO + 1))
sed -i '' -E "s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = $VERSION;/g; s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $BUILD_NO;/g" "$PBX"
echo "==> Sili $VERSION (build $BUILD_NO)"

# Build (ad-hoc signed; no paid Apple developer account needed)
xcodebuild -project Whisky.xcodeproj -scheme Whisky -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$BUILD" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  build -quiet
APP="$BUILD/Build/Products/Release/Sili.app"
[[ -d "$APP" ]] || die "build did not produce Sili.app"

# Package, write release notes, generate the signed appcast
rm -rf "$OUT" && mkdir -p "$OUT"
ZIP="$OUT/Sili-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
printf '%s\n' "$NOTES" | python3 -c '
import sys, html, re
out=[]; inlist=False
for line in sys.stdin.read().splitlines():
    s=line.strip()
    if not s: continue
    t=html.escape(s)
    t=re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t=re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"<a href=\"\2\">\1</a>", t)
    if s.startswith("### "):
        if inlist: out.append("</ul>"); inlist=False
        out.append("<h3>"+t[4:]+"</h3>")
    elif s.startswith("- "):
        if not inlist: out.append("<ul>"); inlist=True
        out.append("<li>"+t[2:]+"</li>")
    else:
        if inlist: out.append("</ul>"); inlist=False
        out.append("<p>"+t+"</p>")
if inlist: out.append("</ul>")
print("\n".join(out))' > "$OUT/Sili-$VERSION.html"

SPARKLE_BIN="$(find "$BUILD/SourcePackages/artifacts" -type d -path '*Sparkle/bin' | head -1)"
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || die "Sparkle tools not found under $BUILD"
"$SPARKLE_BIN/generate_appcast" --account "$KEY_ACCOUNT" --embed-release-notes \
  --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
  --link "https://github.com/$REPO" -o "$OUT/appcast.xml" "$OUT"

# Commit, tag, push, publish
git commit -q -am "Release v$VERSION"
git tag -a "v$VERSION" -m "Sili $VERSION"
git push -q origin main "v$VERSION"
printf '%s\n' "$NOTES" > "$OUT/notes.md"
gh release create "v$VERSION" "$ZIP" "$OUT/appcast.xml" --repo "$REPO" \
  --title "Sili $VERSION" --notes-file "$OUT/notes.md" --latest

echo "==> Released: https://github.com/$REPO/releases/tag/v$VERSION"
