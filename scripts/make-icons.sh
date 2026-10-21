#!/bin/bash
# Renders Resources/sili-icon.png (1024x1024, transparent corners) into the macOS AppIcon set.
# Uses sips, which is built into macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Resources/sili-icon.png"
SET="$ROOT/Whisky/Assets.xcassets/AppIcon.appiconset"
render() { sips -s format png -z "$2" "$2" "$SRC" --out "$SET/$1" >/dev/null; }
render 16R64x1.png 16;    render 16@2x.png 32
render 32R64x1.png 32;    render 32@2x.png 64
render 128R128x1.png 128; render 128@2x.png 256
render 256R256x1.png 256; render 256@2x.png 512
render 512R512x1.png 512; render 512@2x.png 1024
echo "AppIcon updated"
