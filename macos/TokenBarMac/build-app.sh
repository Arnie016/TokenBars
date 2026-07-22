#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
OUTPUT_DIR=${1:-"$SCRIPT_DIR/dist"}
APP_PATH="$OUTPUT_DIR/TokenBar.app"
ARCHIVE_PATH="$OUTPUT_DIR/TokenBar-macOS.zip"
DERIVED_DATA=$(mktemp -d /tmp/tokenbar-mac-derived-data.XXXXXX)
ICON_SOURCE="$SCRIPT_DIR/Resources/TokenBarIcon.png"

cleanup() {
    rm -rf "$DERIVED_DATA"
}
trap cleanup EXIT

(
    cd "$SCRIPT_DIR"
    xcodebuild \
        -scheme TokenBarMac \
        -configuration Release \
        -destination "platform=macOS" \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        build
)

EXECUTABLE="$DERIVED_DATA/Build/Products/Release/TokenBarMac"
if [[ ! -x "$EXECUTABLE" ]]; then
    print -u2 "Expected executable was not produced: $EXECUTABLE"
    exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
install -m 755 "$EXECUTABLE" "$APP_PATH/Contents/MacOS/TokenBarMac"
codesign --remove-signature "$APP_PATH/Contents/MacOS/TokenBarMac"

if [[ -f "$ICON_SOURCE" ]]; then
    ICONSET="$DERIVED_DATA/TokenBar.iconset"
    mkdir -p "$ICONSET"
    sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o "$APP_PATH/Contents/Resources/TokenBar.icns"
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
plutil -create xml1 "$INFO_PLIST"
plutil -insert CFBundleDevelopmentRegion -string en "$INFO_PLIST"
plutil -insert CFBundleDisplayName -string TokenBar "$INFO_PLIST"
plutil -insert CFBundleExecutable -string TokenBarMac "$INFO_PLIST"
plutil -insert CFBundleIdentifier -string com.tokenbar.mac "$INFO_PLIST"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$INFO_PLIST"
plutil -insert CFBundleIconFile -string TokenBar.icns "$INFO_PLIST"
plutil -insert CFBundleName -string TokenBar "$INFO_PLIST"
plutil -insert CFBundlePackageType -string APPL "$INFO_PLIST"
plutil -insert CFBundleShortVersionString -string 0.1.1 "$INFO_PLIST"
plutil -insert CFBundleVersion -string 2 "$INFO_PLIST"
plutil -insert LSApplicationCategoryType -string public.app-category.productivity "$INFO_PLIST"
plutil -insert LSMinimumSystemVersion -string 14.0 "$INFO_PLIST"
plutil -insert NSHighResolutionCapable -bool true "$INFO_PLIST"

codesign --force --deep --sign - "$APP_PATH"

rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"

print "Built $APP_PATH"
print "Packaged $ARCHIVE_PATH"
