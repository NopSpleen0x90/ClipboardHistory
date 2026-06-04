#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  create_dmg.sh — Crea un installer .dmg classico per macOS
#  Risultato: ClipboardHistory-1.0.dmg
# ─────────────────────────────────────────────────────────────

cd "$(dirname "$0")"

# ── Configurazione ────────────────────────────────────────────
APP_NAME="ClipboardHistory"
APP_BUNDLE="${APP_NAME}.app"
VOLUME_NAME="Clipboard History"
DMG_FINAL="ClipboardHistory-1.0.dmg"
DMG_TMP="tmp_${APP_NAME}.dmg"
STAGING="_dmg_staging"
BG_DIR="${STAGING}/.background"
BG_FILE="${BG_DIR}/background.png"

WINDOW_W=540
WINDOW_H=380
APP_X=150
APP_Y=185
LINK_X=390
LINK_Y=185
ICON_SIZE=100

# ── 1. Build app (se non già fatto) ──────────────────────────
if [ ! -d "${APP_BUNDLE}" ]; then
  echo "🔨 Build in corso..."
  bash build.sh
fi
echo "✅ App trovata: ${APP_BUNDLE}"

# ── 2. Staging area ───────────────────────────────────────────
echo ""
echo "📁 Preparazione contenuto DMG..."
rm -rf "${STAGING}"
mkdir -p "${BG_DIR}"
cp -r "${APP_BUNDLE}" "${STAGING}/${APP_BUNDLE}"
ln -s /Applications "${STAGING}/Applications"

# ── 3. Background image ───────────────────────────────────────
python3 make_background.py "${BG_FILE}"

# ── 4. DMG temporaneo read-write ─────────────────────────────
echo ""
echo "💿 Creazione DMG temporaneo..."
rm -f "${DMG_TMP}" "${DMG_FINAL}"

STAGING_SIZE=$(du -sm "${STAGING}" | awk '{print $1}')
DMG_SIZE=$(( STAGING_SIZE + 20 ))

hdiutil create \
  -srcfolder "${STAGING}" \
  -volname "${VOLUME_NAME}" \
  -fs HFS+ \
  -fsargs "-c c=16,a=16,b=16" \
  -format UDRW \
  -size "${DMG_SIZE}m" \
  "${DMG_TMP}" \
  -quiet

# ── 5. Monta ─────────────────────────────────────────────────
echo "📐 Configurazione finestra Finder..."

# hdiutil monta il volume in /Volumes/<nome_del_volume>
hdiutil attach "${DMG_TMP}" -readwrite -noverify -noautoopen -quiet

# Ricava il mount point reale (gestisce spazi nel nome)
MOUNT_DIR=$(hdiutil info | awk '/image-path/{found=0} /'"${DMG_TMP}"'/{found=1} found && /mount-point/{print $NF; exit}')
# Fallback affidabile se il parsing non trova il path
if [ -z "${MOUNT_DIR}" ] || [ ! -d "${MOUNT_DIR}" ]; then
  MOUNT_DIR="/Volumes/${VOLUME_NAME}"
fi
echo "   Montato in: ${MOUNT_DIR}"
sleep 2

# ── 6. Configura finestra Finder via AppleScript ─────────────
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "${VOLUME_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 150, $((200 + WINDOW_W)), $((150 + WINDOW_H))}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to ${ICON_SIZE}
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "${APP_BUNDLE}" of container window to {${APP_X}, ${APP_Y}}
    set position of item "Applications" of container window to {${LINK_X}, ${LINK_Y}}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
rm -f "${MOUNT_DIR}/.DS_Store" 2>/dev/null || true
sync

# ── 7. Smonta ────────────────────────────────────────────────
echo "⏏️  Smontaggio..."
hdiutil detach "${MOUNT_DIR}" -quiet 2>/dev/null \
  || hdiutil detach "${MOUNT_DIR}" -force -quiet 2>/dev/null \
  || true

# Aspetta che il volume sia davvero smontato (max 15s)
for i in $(seq 1 15); do
  if [ ! -d "${MOUNT_DIR}" ]; then
    echo "   Smontato dopo ${i}s."
    break
  fi
  sleep 1
done

# Se ancora montato, prova via diskutil
if [ -d "${MOUNT_DIR}" ]; then
  echo "⚠️  Volume ancora presente, provo force unmount..."
  diskutil unmount force "${MOUNT_DIR}" 2>/dev/null || true
  sleep 3
fi

# ── 8. Converti in DMG read-only compresso ───────────────────
echo "🗜  Compressione finale..."
if ! hdiutil convert "${DMG_TMP}" \
     -format UDZO \
     -imagekey zlib-level=9 \
     -o "${DMG_FINAL}"; then
  echo "❌ Errore nella conversione. Controlla che il DMG temp esista:"
  ls -lh "${DMG_TMP}" 2>/dev/null || echo "   (file non trovato)"
  exit 1
fi

rm -f "${DMG_TMP}"
rm -rf "${STAGING}"

echo ""
echo "────────────────────────────────────────────────"
echo "✅  ${DMG_FINAL}  ($(du -sh "${DMG_FINAL}" | awk '{print $1}'))"
echo "────────────────────────────────────────────────"
echo ""
echo "▶️  Apri subito:"
echo "   open ${DMG_FINAL}"
echo ""
echo "📤  Per distribuire: invia il file .dmg all'utente."
echo "    L'utente lo apre, trascina l'app in Applications e avvia."
