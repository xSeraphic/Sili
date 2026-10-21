#!/bin/bash
# Renders Resources/sili-icon.svg into the macOS AppIcon set. Needs librsvg: brew install librsvg
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/Resources/sili-icon.svg"
SET="$ROOT/Whisky/Assets.xcassets/AppIcon.appiconset"
render() { rsvg-convert -w "$2" -h "$2" "$SVG" -o "$SET/$1"; }
render 16R64x1.png 16;   render 16@2x.png 32
render 32R64x1.png 32;   render 32@2x.png 64
render 128R128x1.png 128; render 128@2x.png 256
render 256R256x1.png 256; render 256@2x.png 512
render 512R512x1.png 512; render 512@2x.png 1024
echo "AppIcon updated"
