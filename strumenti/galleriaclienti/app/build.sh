#!/bin/zsh
# Compila "Galleria Clienti.app" e la installa in /Applications.
# Da rilanciare solo se cambi GalleriaClienti.swift o sposti la cartella del progetto.
set -e
QUI="${0:A:h}"
GENERA="${QUI:h}/genera.py"
APP="/Applications/Galleria Clienti.app"
TMP=$(mktemp -d)

swiftc -O -parse-as-library -o "$TMP/GalleriaClienti" "$QUI/GalleriaClienti.swift"

swift "$QUI/icona.swift" "$TMP/icona.png"
mkdir "$TMP/AppIcon.iconset"
for n in 16 32 128 256 512; do
  sips -z $n $n "$TMP/icona.png" --out "$TMP/AppIcon.iconset/icon_${n}x${n}.png" >/dev/null
  sips -z $((n*2)) $((n*2)) "$TMP/icona.png" --out "$TMP/AppIcon.iconset/icon_${n}x${n}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$TMP/AppIcon.icns"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$TMP/GalleriaClienti" "$APP/Contents/MacOS/"
mv "$TMP/AppIcon.icns" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Galleria Clienti</string>
  <key>CFBundleDisplayName</key><string>Galleria Clienti</string>
  <key>CFBundleIdentifier</key><string>it.mattiabuoli.galleriaclienti</string>
  <key>CFBundleExecutable</key><string>GalleriaClienti</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>3.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>GeneraPath</key><string>$GENERA</string>
  <key>CFBundleDocumentTypes</key><array><dict>
    <key>CFBundleTypeRole</key><string>Viewer</string>
    <key>LSItemContentTypes</key><array><string>public.folder</string></array>
  </dict></array>
</dict></plist>
PLIST
codesign --force --deep -s - "$APP"
rm -rf "$TMP"
echo "Installata: $APP"
