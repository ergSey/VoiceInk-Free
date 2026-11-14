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
#   4. UpdaterViewModel.swift   "Check for Updates" opens the VoiceInk-Free Releases page instead of Sparkle.
#   5. Fresh-install defaults   scripts/free/FreeDefaultsPreset.swift is copied into the app sources;
#                               VoiceInk.swift calls it at launch and when the main window appears;
#                               onboarding keeps the seeded Left Option shortcut instead of clearing it,
#                               downloads Parakeet Ultra instead of Parakeet V3 together with VoiceInk
#                               Refine (shown on the model step, Continue waits for both).
#
# Environment overrides:
#   FREE_FEED_URL       Sparkle feed, only used if the user turns automatic checks on
#                       (default: empty appcast in this repo).
#   FREE_RELEASES_URL   page opened by "Check for Updates" (default: Releases of this repo).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FREE_FEED_URL="${FREE_FEED_URL:-https://raw.githubusercontent.com/ergSey/VoiceInk-Free/main/appcast-free.xml}"
FREE_RELEASES_URL="${FREE_RELEASES_URL:-https://github.com/ergSey/VoiceInk-Free/releases}"
PLIST_BUDDY=/usr/libexec/PlistBuddy

INFO_PLIST="VoiceInk/Info.plist"
APP_DEFAULTS="VoiceInk/App/Configuration/AppDefaults.swift"
LOCAL_XCCONFIG="LocalBuild.xcconfig"
UPDATER_VM="VoiceInk/App/Updates/UpdaterViewModel.swift"
APP_ENTRY="VoiceInk/App/VoiceInk.swift"
ONBOARDING_STEPS="VoiceInk/Features/Onboarding/Models/OnboardingExperienceModels.swift"
ONBOARDING_COORDINATOR="VoiceInk/Features/Onboarding/State/OnboardingCoordinator.swift"
ONBOARDING_FLOW="VoiceInk/Features/Onboarding/State/OnboardingFlowController.swift"
ONBOARDING_SETUP_CARD="VoiceInk/Features/Onboarding/Components/OnboardingTranscriptionSetupCard.swift"
ONBOARDING_MODEL_SCREEN="VoiceInk/Features/Onboarding/Views/OnboardingModelScreen.swift"
PATCHED_FILES=("$INFO_PLIST" "$APP_DEFAULTS" "$LOCAL_XCCONFIG" "$UPDATER_VM" "$APP_ENTRY" "$ONBOARDING_STEPS"
    "$ONBOARDING_COORDINATOR" "$ONBOARDING_FLOW" "$ONBOARDING_SETUP_CARD" "$ONBOARDING_MODEL_SCREEN")
PRESET_SRC="scripts/free/FreeDefaultsPreset.swift"
PRESET_DST="VoiceInk/App/Configuration/FreeDefaultsPreset.swift"
PRESET_MARKER="VoiceInkFree.defaultsPresetPending"

log() { printf '[patch] %s\n' "$*"; }
fail() { printf '[patch] error: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
    [[ ! -e "$REPO_ROOT/$PRESET_DST" ]] || fail "$PRESET_DST already exists (upstream added it?)"
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

    local updater="$REPO_ROOT/$UPDATER_VM"
    log "UpdaterViewModel.swift: Check for Updates opens $FREE_RELEASES_URL"
    grep -q '^        updaterController.checkForUpdates(nil)$' "$updater" \
        || fail "manual update check call not found in $UPDATER_VM (upstream changed?)"
    grep -q '^import SwiftUI$' "$updater" \
        || fail "import SwiftUI not found in $UPDATER_VM (upstream changed?)"
    sed -i '' \
        -e 's/^import SwiftUI$/import AppKit\
import SwiftUI/' \
        -e "s|^        updaterController.checkForUpdates(nil)\$|        NSWorkspace.shared.open(URL(string: \"$FREE_RELEASES_URL\")!) // VoiceInk-Free|" \
        "$updater"

    log "fresh-install defaults: modes with local models, Left Option to record, Escape to cancel"
    cp "$REPO_ROOT/$PRESET_SRC" "$REPO_ROOT/$PRESET_DST"
    local entry="$REPO_ROOT/$APP_ENTRY"
    [[ "$(grep -c '^        AppDefaults.registerDefaults()$' "$entry")" == 1 ]] \
        || fail "AppDefaults.registerDefaults() call not found once in $APP_ENTRY (upstream changed?)"
    [[ "$(grep -c '^                            if enableAnnouncements {$' "$entry")" == 1 ]] \
        || fail "main window onAppear anchor not found once in $APP_ENTRY (upstream changed?)"
    sed -i '' \
        -e 's/^        AppDefaults.registerDefaults()$/&\
        FreeDefaultsPreset.prepareFreshInstall() \/\/ VoiceInk-Free/' \
        -e 's/^                            if enableAnnouncements {$/                            FreeDefaultsPreset.applyModesIfPending(enhancementService: enhancementService) \/\/ VoiceInk-Free\
&/' \
        "$entry"
    local steps="$REPO_ROOT/$ONBOARDING_STEPS"
    [[ "$(grep -c '^                clearsOnIntro: true$' "$steps")" == 1 ]] \
        || fail "dictation step clearsOnIntro not found once in $ONBOARDING_STEPS (upstream changed?)"
    sed -i '' 's/^                clearsOnIntro: true$/                clearsOnIntro: false \/\/ VoiceInk-Free: keep the seeded shortcut/' "$steps"

    local coordinator="$REPO_ROOT/$ONBOARDING_COORDINATOR"
    [[ "$(grep -c '^            .first { $0.name == "parakeet-tdt-0.6b-v3" }$' "$coordinator")" == 1 ]] \
        || fail "onboarding transcription model not found once in $ONBOARDING_COORDINATOR (upstream changed?)"
    sed -i '' 's/^            .first { $0.name == "parakeet-tdt-0.6b-v3" }$/            .first { $0.name == FreeDefaultsPreset.transcriptionModelName } \/\/ VoiceInk-Free/' "$coordinator"

    local flow="$REPO_ROOT/$ONBOARDING_FLOW"
    [[ "$(grep -c '^        modelManager.startDownload(model)$' "$flow")" == 1 ]] \
        || fail "onboarding model download call not found once in $ONBOARDING_FLOW (upstream changed?)"
    [[ "$(grep -c '^    func downloadTranscriptionModel($' "$flow")" == 1 ]] \
        || fail "downloadTranscriptionModel not found once in $ONBOARDING_FLOW (upstream changed?)"
    # Hook at the start of the function body, so it also runs when the model is already on disk.
    awk '
        /^    func downloadTranscriptionModel\($/ { in_fn = 1 }
        { print }
        in_fn && /^    \) \{$/ {
            print "        FreeDefaultsPreset.startRefineDownload() // VoiceInk-Free"
            in_fn = 0; hooked = 1
        }
        END { if (!hooked) exit 1 }
    ' "$flow" > "$flow.free" || fail "could not hook downloadTranscriptionModel in $ONBOARDING_FLOW"
    mv "$flow.free" "$flow"

    local setup_card="$REPO_ROOT/$ONBOARDING_SETUP_CARD"
    [[ "$(grep -c '^            TranscriptionModelDownloadCard($' "$setup_card")" == 1 ]] \
        || fail "TranscriptionModelDownloadCard not found once in $ONBOARDING_SETUP_CARD (upstream changed?)"
    awk '
        /^            TranscriptionModelDownloadCard\($/ { in_card = 1 }
        { print }
        in_card && /^            \)$/ {
            print "            FreeRefineDownloadCard() // VoiceInk-Free"
            in_card = 0; hooked = 1
        }
        END { if (!hooked) exit 1 }
    ' "$setup_card" > "$setup_card.free" || fail "could not add the Refine card to $ONBOARDING_SETUP_CARD"
    mv "$setup_card.free" "$setup_card"

    local model_screen="$REPO_ROOT/$ONBOARDING_MODEL_SCREEN"
    [[ "$(grep -c '^struct OnboardingModelScreen: View {$' "$model_screen")" == 1 ]] \
        || fail "OnboardingModelScreen declaration not found once in $ONBOARDING_MODEL_SCREEN (upstream changed?)"
    [[ "$(grep -c '^                isPrimaryEnabled: isSetupReady && !(setupKind == .local && isLocalDownloading),$' "$model_screen")" == 1 ]] \
        || fail "Continue condition not found once in $ONBOARDING_MODEL_SCREEN (upstream changed?)"
    sed -i '' \
        -e 's/^struct OnboardingModelScreen: View {$/&\
    @ObservedObject var freeRefine = VoiceInkRefineService.shared \/\/ VoiceInk-Free/' \
        -e 's/^                isPrimaryEnabled: isSetupReady \&\& !(setupKind == .local \&\& isLocalDownloading),$/                isPrimaryEnabled: isSetupReady \&\& !(setupKind == .local \&\& isLocalDownloading) \&\& !freeRefine.isDownloading, \/\/ VoiceInk-Free/' \
        "$model_screen"
    grep -q 'freeRefine.isDownloading' "$model_screen" || fail "could not patch Continue in $ONBOARDING_MODEL_SCREEN"
}

restore_patches() {
    local backup_dir="$1" f
    [[ -e "$backup_dir/.complete" ]] || { log "nothing to restore in $backup_dir"; return 0; }
    for f in "${PATCHED_FILES[@]}"; do
        cp -p "$backup_dir/$f" "$REPO_ROOT/$f"
    done
    rm -f "$REPO_ROOT/$PRESET_DST"
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

    grep -aqF "$FREE_RELEASES_URL" "$app/Contents/MacOS/VoiceInk" \
        || fail "Releases URL not found in the binary, Check for Updates patch missing"

    grep -aqF "$PRESET_MARKER" "$app/Contents/MacOS/VoiceInk" \
        || fail "fresh-install defaults not found in the binary, preset patch missing"

    archs="$(lipo -archs "$app/Contents/MacOS/VoiceInk")"
    [[ "$archs" == "arm64" ]] || fail "binary architectures are '$archs', expected arm64"

    codesign --verify --deep --strict "$app" || fail "code signature is invalid"
    log "verified: automatic checks off, feed $FREE_FEED_URL, Check for Updates -> $FREE_RELEASES_URL, fresh-install defaults, arch $archs, signature valid"
}

[[ $# -eq 2 ]] || usage
case "$1" in
    apply) apply_patches "$2" ;;
    restore) restore_patches "$2" ;;
    verify) verify_app "$2" ;;
    *) usage ;;
esac
