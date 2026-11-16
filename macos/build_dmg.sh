#!/bin/bash
# Builds dist/UNIBODY.dmg: a self-contained UNIBODY.app plus an
# "Applications" shortcut for drag-and-drop installation.
#
# Usage: macos/build_dmg.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$PROJECT_DIR/dist"
DMG="$DIST/UNIBODY.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

"$PROJECT_DIR/macos/build_app.sh" --standalone "$STAGE"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/LIESMICH.txt" <<'TXT'
UNIBODY – inoffizielles Studierenden-Tool
Keine Verbindung zur Christian-Albrechts-Universität zu Kiel, OpenOlat oder Moodle.

Installation
1. UNIBODY auf den Ordner "Applications" ziehen.
2. UNIBODY aus dem Programme-Ordner öffnen.

Erster Start
Die App ist nicht von Apple beglaubigt. macOS blockiert deshalb den ersten Start.
Öffne danach Systemeinstellungen > Datenschutz & Sicherheit und klicke bei
"UNIBODY" auf "Dennoch öffnen". Das ist nur einmal nötig.

Voraussetzung
Python 3.9 oder neuer. Falls es fehlt, zeigt die App einen Hinweis.
Installation: python.org oder im Terminal "xcode-select --install".

Deine Daten
Alles bleibt lokal auf deinem Mac:
~/Library/Application Support/UNIBODY
(in der App: Darstellung > Datenordner im Finder zeigen)
TXT

mkdir -p "$DIST"
rm -f "$DMG"
/usr/bin/hdiutil create -volname "UNIBODY" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "Built $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
