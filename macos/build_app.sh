#!/bin/bash
# Builds UNIBODY.app: a native macOS window around the local web UI.
# The app starts the Python server (127.0.0.1:8765) from this project folder
# and stops it again when the app quits.
#
# Usage: macos/build_app.sh [--standalone] [target directory]   (default: /Applications)
#
#   default       Linked build for development: uses this project folder and its
#                 data/ directory. Re-run after moving the project folder.
#   --standalone  Self-contained build for other people: the Python code and the
#                 web UI are copied into the app, user data goes to
#                 ~/Library/Application Support/UNIBODY. Used by macos/build_dmg.sh.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STANDALONE=0
if [ "${1:-}" = "--standalone" ]; then
	STANDALONE=1
	shift
fi
TARGET_DIR="${1:-/Applications}"
APP="$TARGET_DIR/UNIBODY.app"
SOURCE="$PROJECT_DIR/macos/UNIBODYApp/main.swift"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BUILD="$WORK/UNIBODY.app"
mkdir -p "$BUILD/Contents/MacOS" "$BUILD/Contents/Resources"

xcrun swiftc -O -swift-version 5 \
	-target "$(uname -m)-apple-macos13.0" \
	-framework Cocoa -framework WebKit \
	-o "$BUILD/Contents/MacOS/UNIBODY" "$SOURCE"

# App icon from the unofficial UNIBODY logo.
LOGO="$PROJECT_DIR/static/unibody-logo.png"
ICON_KEY=""
if [ -f "$LOGO" ]; then
	ICONSET="$WORK/UNIBODY.iconset"
	mkdir -p "$ICONSET"
	for size in 16 32 128 256; do
		/usr/bin/sips -z "$size" "$size" "$LOGO" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
		double=$((size * 2))
		/usr/bin/sips -z "$double" "$double" "$LOGO" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
	done
	/usr/bin/iconutil -c icns "$ICONSET" -o "$BUILD/Contents/Resources/UNIBODY.icns"
	ICON_KEY="UNIBODY"
fi

PLIST="$BUILD/Contents/Info.plist"
pb() { /usr/libexec/PlistBuddy -c "$1" "$PLIST" >/dev/null; }
pb "Add :CFBundleName string UNIBODY"
pb "Add :CFBundleDisplayName string UNIBODY"
pb "Add :CFBundleExecutable string UNIBODY"
pb "Add :CFBundleIdentifier string app.unibody.desktop"
pb "Add :CFBundlePackageType string APPL"
pb "Add :CFBundleShortVersionString string 1.0"
pb "Add :CFBundleVersion string 1"
pb "Add :CFBundleInfoDictionaryVersion string 6.0"
pb "Add :LSMinimumSystemVersion string 13.0"
pb "Add :LSApplicationCategoryType string public.app-category.education"
pb "Add :NSHighResolutionCapable bool true"
pb "Add :NSPrincipalClass string NSApplication"
pb "Add :NSHumanReadableCopyright string Inoffizielles Studierenden-Tool. Keine Verbindung zur CAU Kiel."
# Loopback only: no arbitrary loads (NET-01).
pb "Add :NSAppTransportSecurity dict"
pb "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true"
[ -n "$ICON_KEY" ] && pb "Add :CFBundleIconFile string $ICON_KEY"
if [ "$STANDALONE" = 1 ]; then
	SERVER_DIR="$BUILD/Contents/Resources/server"
	mkdir -p "$SERVER_DIR"
	for module in server.py lms_bot.py cau_materials.py cau_mail.py optimizer.py reminders.py; do
		cp "$PROJECT_DIR/$module" "$SERVER_DIR/"
	done
	/usr/bin/ditto "$PROJECT_DIR/static" "$SERVER_DIR/static"
	cp "$PROJECT_DIR/LICENSE" "$BUILD/Contents/Resources/LICENSE"
	find "$BUILD" -name ".DS_Store" -delete
else
	/usr/libexec/PlistBuddy -c "Add :UNIBODYProjectDir string $PROJECT_DIR" "$PLIST" >/dev/null
fi

# Ad-hoc signature (no Apple Developer ID): fine locally, but Gatekeeper
# asks other users to confirm the first launch.
/usr/bin/codesign --force --deep --sign - "$BUILD" >/dev/null 2>&1

rm -rf "$APP"
/usr/bin/ditto "$BUILD" "$APP"
touch "$APP"

if [ "$STANDALONE" = 1 ]; then
	echo "Built $APP (standalone)"
else
	echo "Built $APP (linked to $PROJECT_DIR)"
fi
