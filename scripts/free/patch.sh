#!/usr/bin/env bash
# VoiceInk-Free build patches.
#
# Applies the small set of changes that turn an upstream `make local` build into a
# VoiceInk-Free build, and restores the original files afterwards so the working
# tree (and future upstream merges) stay untouched.
#
#   scripts/free/patch.sh apply   <backup-dir>
#   scripts/free/patch.sh restore <backup-dir>
#   scripts/free/patch.sh verify  <VoiceInk.app>
#
# Patches:
#   1. VoiceInk/Info.plist      SUEnableAutomaticChecks = false, SUFeedURL -> empty VoiceInk-Free feed.
#   2. AppDefaults.swift        "Show Announcements" off by default.
#   3. LocalBuild.xcconfig      ARCHS = arm64 (Apple Silicon only).
#
# Environment overrides:
#   FREE_FEED_URL   Sparkle feed for manual "Check for Updates" (default: empty appcast in this repo).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FREE_FEED_URL="${FREE_FEED_URL:-https://raw.githubusercontent.com/ergSey/VoiceInk-Free/main/appcast-free.xml}"
PLIST_BUDDY=/usr/libexec/PlistBuddy

INFO_PLIST="VoiceInk/Info.plist"
APP_DEFAULTS="VoiceInk/App/Configuration/AppDefaults.swift"
LOCAL_XCCONFIG="LocalBuild.xcconfig"
PATCHED_FILES=("$INFO_PLIST" "$APP_DEFAULTS" "$LOCAL_XCCONFIG")

log() { printf '[patch] %s\n' "$*"; }
fail() { printf '[patch] error: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 2
}

backup() {
    local backup_dir="$1" f
    [[ ! -e "$backup_dir/.complete" ]] || fail "backup already exists in $backup_dir; run restore first"
    mkdir -p "$backup_dir"
    for f in "${PATCHED_FILES[@]}"; do
        [[ -f "$REPO_ROOT/$f" ]] || fail "missing $f (upstream layout changed?)"
        mkdir -p "$backup_dir/$(dirname "$f")"
        cp -p "$REPO_ROOT/$f" "$backup_dir/$f"
    done
    touch "$backup_dir/.complete"
}

apply_patches() {
    local backup_dir="$1"
    backup "$backup_dir"

    local plist="$REPO_ROOT/$INFO_PLIST"
    log "Info.plist: SUEnableAutomaticChecks=false, SUFeedURL=$FREE_FEED_URL"
    "$PLIST_BUDDY" -c "Set :SUEnableAutomaticChecks false" "$plist" 2>/dev/null \
        || "$PLIST_BUDDY" -c "Add :SUEnableAutomaticChecks bool false" "$plist"
    "$PLIST_BUDDY" -c "Set :SUFeedURL $FREE_FEED_URL" "$plist" 2>/dev/null \
        || "$PLIST_BUDDY" -c "Add :SUFeedURL string $FREE_FEED_URL" "$plist"

    local defaults="$REPO_ROOT/$APP_DEFAULTS"
    log "AppDefaults.swift: enableAnnouncements=false"
    grep -q '"enableAnnouncements": true,' "$defaults" \
        || fail "enableAnnouncements default not found in $APP_DEFAULTS (upstream changed?)"
    sed -i '' 's/"enableAnnouncements": true,/"enableAnnouncements": false,/' "$defaults"

    local xcconfig="$REPO_ROOT/$LOCAL_XCCONFIG"
    log "LocalBuild.xcconfig: ARCHS=arm64"
    printf '\n// VoiceInk-Free: Apple Silicon only\nARCHS = arm64\nONLY_ACTIVE_ARCH = NO\n' >> "$xcconfig"
}

restore_patches() {
    local backup_dir="$1" f
    [[ -e "$backup_dir/.complete" ]] || { log "nothing to restore in $backup_dir"; return 0; }
    for f in "${PATCHED_FILES[@]}"; do
        cp -p "$backup_dir/$f" "$REPO_ROOT/$f"
    done
    rm -rf "$backup_dir"
    log "original files restored"
}

verify_app() {
    local app="$1" plist value archs
    plist="$app/Contents/Info.plist"
    [[ -f "$plist" ]] || fail "no Info.plist in $app"

    value="$("$PLIST_BUDDY" -c "Print :SUEnableAutomaticChecks" "$plist")"
    [[ "$value" == "false" ]] || fail "SUEnableAutomaticChecks is '$value', expected false"

    value="$("$PLIST_BUDDY" -c "Print :SUFeedURL" "$plist")"
    [[ "$value" == "$FREE_FEED_URL" ]] || fail "SUFeedURL is '$value', expected $FREE_FEED_URL"

    archs="$(lipo -archs "$app/Contents/MacOS/VoiceInk")"
    [[ "$archs" == "arm64" ]] || fail "binary architectures are '$archs', expected arm64"

    codesign --verify --deep --strict "$app" || fail "code signature is invalid"
    log "verified: automatic checks off, feed $FREE_FEED_URL, arch $archs, signature valid"
}

[[ $# -eq 2 ]] || usage
case "$1" in
    apply) apply_patches "$2" ;;
    restore) restore_patches "$2" ;;
    verify) verify_app "$2" ;;
    *) usage ;;
esac
