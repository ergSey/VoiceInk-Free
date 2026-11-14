import Carbon.HIToolbox
import Foundation
import SwiftUI

// VoiceInk-Free: default setup for fresh installs.
// Copied into VoiceInk/App/Configuration/ by scripts/free/patch.sh at build time; not part of upstream.
//
// - Primary recording shortcut: Left Option, seeded before onboarding (onboarding can still change it).
// - Cancel recording: Escape, the built-in default (left unset on purpose).
// - Onboarding downloads Parakeet Ultra (instead of Parakeet V3) together with VoiceInk Refine V1,
//   shows both downloads on its model step and continues once both are done, so a fresh install
//   needs exactly these two models.
// - Once, after onboarding finishes: Dictation, Enhancement and Email modes with local models only
//   (Parakeet Ultra transcription, VoiceInk Refine V1 enhancement), Russian for Dictation and
//   Enhancement, auto-detect for Email, Enhancement as the default mode.
//
// Existing installs (any onboarding or mode data already stored) are never touched.
enum FreeDefaultsPreset {
    static let pendingKey = "VoiceInkFree.defaultsPresetPending"

    private static let dictationId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private static let enhancementId = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    private static let emailId = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!

    static let transcriptionModelName = "parakeet-ultra"

    private static let freshInstallMarkers = [
        OnboardingSettings.completedV2Key,
        OnboardingSettings.preparedV2Key,
        "hasCompletedOnboarding",
        "modeConfigurationsV2",
        "powerModeConfigurationsV2",
    ]

    /// Call right after `AppDefaults.registerDefaults()`, before `OnboardingV2Migration.prepareIfNeeded()`.
    static func prepareFreshInstall(defaults: UserDefaults = .standard) {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let stored = defaults.persistentDomain(forName: bundleId) ?? [:]
        guard freshInstallMarkers.allSatisfy({ stored[$0] == nil }) else { return }

        defaults.set(true, forKey: pendingKey)

        let primaryKey = ShortcutAction.primaryRecording.userDefaultsKey
        let leftOption = Shortcut.modifierOnly(keyCode: UInt16(kVK_Option), modifierFlags: [.option])
        if stored[primaryKey] == nil, let data = try? JSONEncoder().encode(leftOption) {
            defaults.set(data, forKey: primaryKey)
        }
    }

    /// Whether this is a fresh VoiceInk-Free install whose onboarding should also fetch VoiceInk Refine.
    static var isFreshInstallOnboarding: Bool {
        UserDefaults.standard.bool(forKey: pendingKey)
    }

    /// Call when onboarding starts its transcription model download: VoiceInk Refine downloads alongside.
    @MainActor
    static func startRefineDownload() {
        guard isFreshInstallOnboarding else { return }
        VoiceInkRefineService.shared.startDownload()
    }

    /// Call when the main window appears. Does nothing until onboarding is complete, then runs once.
    @MainActor
    static func applyModesIfPending(enhancementService: AIEnhancementService, defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: pendingKey),
            defaults.bool(forKey: OnboardingSettings.completedV2Key)
        else { return }
        defaults.removeObject(forKey: pendingKey)

        let kinds: [StarterModeKind] = [.clean, .enhance, .email]
        let seeded = StarterModePromptSeeder.ensurePrompts(for: kinds, in: enhancementService.customPrompts)
        if seeded.didChange {
            enhancementService.customPrompts = seeded.prompts
        }

        StarterModeFactory.install(
            kinds: kinds,
            provider: .voiceInkRefine,
            modelName: VoiceInkRefineService.modelName,
            transcriptionModelName: transcriptionModelName,
            isRealtimeTranscriptionEnabled: true,
            selectedLanguage: "ru"
        )

        let manager = ModeManager.shared
        let updated = manager.configurations.map { config -> ModeConfig in
            var config = config
            switch config.id {
            case enhancementId:
                config.useClipboardContext = true
            case emailId:
                config.selectedLanguage = "auto"
            default:
                break
            }
            return config
        }
        manager.replaceConfigurations(updated)

        for id in [dictationId, enhancementId, emailId] {
            ShortcutStore.removeShortcutStorage(for: .mode(id))
        }

        manager.setAsDefault(configId: enhancementId)
        manager.setActiveConfiguration(manager.getConfiguration(with: enhancementId))
    }
}

/// VoiceInk-Free: VoiceInk Refine download card for the onboarding model step (fresh installs only).
struct FreeRefineDownloadCard: View {
    @ObservedObject private var refine = VoiceInkRefineService.shared

    var body: some View {
        if FreeDefaultsPreset.isFreshInstallOnboarding {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppTheme.Accent.primary)
                            .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: VoiceInkRefineService.modelName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppTheme.Text.primary)

                            Text(verbatim: "Local AI enhancement for the Enhancement and Email modes.")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Text.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    statusControl
                        .fixedSize()
                }

                if let note {
                    Text(verbatim: note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                }

                if refine.isDownloading {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(verbatim: "Downloading \(VoiceInkRefineService.downloadSizeDescription)...")
                                .lineLimit(1)
                            Spacer()
                            Text(refine.downloadProgress, format: .percent.precision(.fractionLength(0)))
                                .fontDesign(.monospaced)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)

                        ProgressView(value: refine.downloadProgress)
                            .progressViewStyle(.linear)
                            .tint(AppTheme.Accent.primary)
                    }
                }
            }
            .padding(18)
            .background(AppMaterialCardBackground(cornerRadius: 12))
        }
    }

    private var note: String? {
        if let unavailable = refine.unavailableDescription {
            return unavailable
        }
        if let error = refine.downloadError {
            return error
        }
        return nil
    }

    @ViewBuilder
    private var statusControl: some View {
        if refine.availability != .available {
            EmptyView()
        } else if refine.isDownloaded {
            Text(verbatim: "Downloaded")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.Text.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(AppTheme.Surface.controlActive))
        } else {
            Button {
                if refine.isDownloading {
                    refine.cancelDownload()
                } else {
                    refine.startDownload()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(verbatim: refine.isDownloading ? "Cancel" : "Download Model")
                    Image(systemName: refine.isDownloading ? "xmark.circle" : "arrow.down.circle")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(
                    refine.isDownloading ? AppTheme.Action.destructiveForeground : AppTheme.Action.primaryForeground
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(refine.isDownloading ? AppTheme.Action.destructiveFill : AppTheme.Action.primaryFill)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
