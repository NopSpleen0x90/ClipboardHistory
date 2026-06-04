#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔨 Compilazione in corso..."
swift build -c release 2>&1

echo ""
echo "📦 Creazione .app bundle..."

APP="ClipboardHistory.app"
BINARY=".build/release/ClipboardHistory"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/ClipboardHistory"

# ── Icon ──────────────────────────────────────────────────────
if [ -f "AppIcon.icns" ]; then
  cp "AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClipboardHistory</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.clipboard-history</string>
    <key>CFBundleName</key>
    <string>Clipboard History</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Clipboard History necessita dell'accesso all'accessibilità per incollare automaticamente il testo.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Clipboard History usa eventi di sistema per simulare Cmd+V.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

chmod +x "$APP/Contents/MacOS/ClipboardHistory"

# ── Firma con entitlements (obbligatorio per sandbox / App Store) ──────────────
echo "🔏 Firma app con entitlements..."
if [ -f "ClipboardHistory.entitlements" ]; then
  # Firma con identità ad-hoc (-) per test locale; sostituire con "Developer ID Application: ..."
  # o "Apple Distribution: ..." per App Store.
  codesign --force --deep --sign - \
    --entitlements ClipboardHistory.entitlements \
    "$APP" 2>&1 && echo "   ✓ Firma applicata"
else
  echo "   ⚠️  ClipboardHistory.entitlements non trovato, firma saltata"
fi

echo ""
echo "✅ Build completata!"
echo ""
echo "▶️  Avvia adesso:"
echo "   open ClipboardHistory.app"
echo ""
echo "📌 Per aggiungerla agli elementi di login:"
echo "   cp -r ClipboardHistory.app /Applications/"
echo "   Poi: Impostazioni → Generali → Elementi login → +"
echo ""
echo "🔑 Al primo avvio:"
echo "   • Rimuovi quarantena se necessario: xattr -dr com.apple.quarantine ClipboardHistory.app"
echo "   • Concedi l'accesso Accessibilità in: Impostazioni → Privacy → Accessibilità"
echo ""
echo "⌨️  Shortcut: Cmd ⌘ + Shift ⇧ + V"
echo ""
echo "🍎 Per pubblicare su Mac App Store:"
echo "   1. Apri Package.swift con Xcode"
echo "   2. Target → Signing & Capabilities → imposta Team e Bundle ID"
echo "   3. Sostituisci la firma nel build.sh con il tuo certificato 'Apple Distribution:'"
echo "   4. Product → Archive → Distribute App → App Store Connect"
