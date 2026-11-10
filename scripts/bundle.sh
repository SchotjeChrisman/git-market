#!/usr/bin/env bash
# Builds a universal GitMarket.app into ./build. Run on macOS.
set -euo pipefail

app_name="GitMarket"
bundle_identifier="dev.gitmarket.GitMarket"
version="${GITMARKET_VERSION:-0.1.0}"
minimum_macos="13.0"

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$root_dir/build"
bundle_dir="$output_dir/$app_name.app"

cd "$root_dir"
swift build -c release --arch arm64 --arch x86_64
binary_path="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$app_name"

rm -rf "$bundle_dir"
mkdir -p "$bundle_dir/Contents/MacOS"
cp "$binary_path" "$bundle_dir/Contents/MacOS/$app_name"

cat > "$bundle_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$app_name</string>
    <key>CFBundleIdentifier</key><string>$bundle_identifier</string>
    <key>CFBundleName</key><string>Git Market</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$version</string>
    <key>LSMinimumSystemVersion</key><string>$minimum_macos</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$bundle_dir"
ditto -c -k --keepParent "$bundle_dir" "$output_dir/$app_name.zip"
echo "Built $output_dir/$app_name.zip"
