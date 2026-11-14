#!/usr/bin/env bash
# Build an unsigned (ad-hoc) Apple Silicon DMG of VoiceInk-Free.
#
#   scripts/free/build-dmg.sh
#
# Steps: whisper.xcframework -> patch sources -> `make local` (ad-hoc, arm64)
#        -> restore sources -> verify app -> create-dmg -> sha256.
#
# Output: $OUTPUT_DIR/VoiceInk-<version>-arm64.dmg and .dmg.sha256
#
# Environment overrides:
#   OUTPUT_DIR               where the DMG goes (default: <repo>/build/free)
#   LOCAL_DERIVED_DATA       xcodebuild derived data (default: <repo>/.local-build, as in the Makefile)
#   LOCAL_CODESIGN_IDENTITY  signing identity for make local (default: "-", ad-hoc)
#   FREE_FEED_URL            Sparkle feed URL, see patch.sh
#   DMG_SKIP_FINDER=1        skip Finder window styling (headless CI without Apple Events)
#
# Note: `make local` also copies the app to ~/Downloads/VoiceInk.app (upstream behaviour).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH="$REPO_ROOT/scripts/free/patch.sh"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/build/free}"
LOCAL_DERIVED_DATA="${LOCAL_DERIVED_DATA:-$REPO_ROOT/.local-build}"
LOCAL_CODESIGN_IDENTITY="${LOCAL_CODESIGN_IDENTITY:--}"
DMG_SKIP_FINDER="${DMG_SKIP_FINDER:-0}"

DMG_ASSET_DIR="$REPO_ROOT/release/dmg"
DMG_LAYOUT="$DMG_ASSET_DIR/layout.conf"
DMG_BACKGROUND="$DMG_ASSET_DIR/background.tiff"
DMG_VOLUME_ICON="$DMG_ASSET_DIR/volume-icon.icns"

log() { printf '\n==> %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

for cmd in make xcodebuild create-dmg hdiutil ditto lipo codesign shasum; do
    command -v "$cmd" >/dev/null 2>&1 || fail "$cmd is required"
done
for f in "$DMG_LAYOUT" "$DMG_BACKGROUND" "$DMG_VOLUME_ICON"; do
    [[ -f "$f" ]] || fail "DMG asset not found: $f"
done
# shellcheck source=../../release/dmg/layout.conf
source "$DMG_LAYOUT"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/voiceink-free.XXXXXX")"
BACKUP_DIR="$WORK_DIR/patch-backup"
cleanup() {
    "$PATCH" restore "$BACKUP_DIR" || true
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cd "$REPO_ROOT"

log "Building whisper.xcframework (skipped if already built)"
make whisper

log "Applying VoiceInk-Free patches"
"$PATCH" apply "$BACKUP_DIR"

log "Building VoiceInk (make local, identity '$LOCAL_CODESIGN_IDENTITY')"
make local \
    LOCAL_CODESIGN_IDENTITY="$LOCAL_CODESIGN_IDENTITY" \
    LOCAL_DERIVED_DATA="$LOCAL_DERIVED_DATA"

log "Restoring original sources"
"$PATCH" restore "$BACKUP_DIR"

APP_PATH="$LOCAL_DERIVED_DATA/Build/Products/Release/VoiceInk.app"
[[ -d "$APP_PATH" ]] || fail "built app not found: $APP_PATH"

log "Verifying app"
"$PATCH" verify "$APP_PATH"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")"
[[ -n "$VERSION" ]] || fail "cannot read app version"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
DMG_NAME="VoiceInk-$VERSION-arm64.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH" "$DMG_PATH.sha256"

DMG_SOURCE_DIR="$WORK_DIR/dmg-source"
mkdir -p "$DMG_SOURCE_DIR"
ditto "$APP_PATH" "$DMG_SOURCE_DIR/VoiceInk.app"

CREATE_DMG_EXTRA=()
if [[ "$DMG_SKIP_FINDER" == "1" ]]; then
    CREATE_DMG_EXTRA+=(--skip-jenkins)
fi

log "Building $DMG_NAME"
create-dmg \
    --volname "$DMG_VOLUME_NAME" \
    --volicon "$DMG_VOLUME_ICON" \
    --background "$DMG_BACKGROUND" \
    --window-pos "$DMG_WINDOW_X" "$DMG_WINDOW_Y" \
    --window-size "$DMG_WINDOW_WIDTH" "$DMG_WINDOW_HEIGHT" \
    --text-size "$DMG_TEXT_SIZE" \
    --icon-size "$DMG_ICON_SIZE" \
    --icon "VoiceInk.app" "$DMG_APP_X" "$DMG_APP_Y" \
    --hide-extension "VoiceInk.app" \
    --app-drop-link "$DMG_APPLICATIONS_X" "$DMG_APPLICATIONS_Y" \
    --filesystem APFS \
    --format ULFO \
    --no-internet-enable \
    ${CREATE_DMG_EXTRA[@]+"${CREATE_DMG_EXTRA[@]}"} \
    "$DMG_PATH" \
    "$DMG_SOURCE_DIR"

log "Verifying DMG"
hdiutil verify "$DMG_PATH"
MOUNT_DIR="$WORK_DIR/mount"
mkdir -p "$MOUNT_DIR"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$DMG_PATH" >/dev/null
"$PATCH" verify "$MOUNT_DIR/VoiceInk.app" || { hdiutil detach "$MOUNT_DIR" >/dev/null; exit 1; }
[[ -L "$MOUNT_DIR/Applications" ]] || { hdiutil detach "$MOUNT_DIR" >/dev/null; fail "Applications link missing"; }
hdiutil detach "$MOUNT_DIR" >/dev/null

(cd "$OUTPUT_DIR" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")

log "Done"
echo "DMG:    $DMG_PATH"
echo "SHA256: $(cut -d' ' -f1 "$DMG_PATH.sha256")"
