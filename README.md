<!-- VoiceInk-Free: this block is maintained in this repository. The original VoiceInk README follows below it unchanged. -->

# VoiceInk-Free

**Free ready-to-use builds of [VoiceInk](https://github.com/Beingpax/VoiceInk) for Apple Silicon Macs.** Unofficial, not affiliated with the author. [Русская версия](README.ru.md)

**[⬇ Download the latest DMG](https://github.com/ergSey/VoiceInk-Free/releases/latest)**

> [!IMPORTANT]
> Don't build this repository yourself: download a ready-made DMG from [Releases](https://github.com/ergSey/VoiceInk-Free/releases). The code here is the original VoiceInk plus a small build script. To build from source or follow development, go to the original project: [Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk).

The author of VoiceInk sells the ready-made app for **$25** (one-time purchase for one Mac, see [tryvoiceink.com/pricing](https://tryvoiceink.com/pricing), November 2026). Here the same app is already built and free. If VoiceInk is useful to you, please **support the author by [buying a license](https://tryvoiceink.com/pricing)**: it funds the development of the app you are using.

VoiceInk can work entirely on local models. Speech recognition (whisper.cpp, Parakeet) and AI text cleanup (VoiceInk Refine on MLX, or Ollama) run on your Mac, so dictation is very fast and needs no internet connection. The app also supports cloud providers (OpenAI, Groq, Deepgram and others), but you don't need them.

## Install

1. Download `VoiceInk-<version>-arm64.dmg` from [Releases](https://github.com/ergSey/VoiceInk-Free/releases).
2. Open the DMG and drag VoiceInk to Applications.
3. The app is not notarized by Apple, so macOS blocks the first launch. Run once in Terminal:
   ```shell
   xattr -cr /Applications/VoiceInk.app
   ```
   or try to open the app, then go to System Settings → Privacy & Security and click **Open Anyway**.

Optional: check the download against the `.sha256` file from the same release:

```shell
shasum -a 256 -c VoiceInk-<version>-arm64.dmg.sha256
```

Requirements: Apple Silicon Mac, macOS 15.0 or later.

> [!NOTE]
> This build uses the same app ID as the official VoiceInk, so it shares settings and data with it. Don't install both: remove the official app first.

## Updates

The app doesn't update itself. **Check for Updates** (in Settings and in the menu bar) opens the [Releases](https://github.com/ergSey/VoiceInk-Free/releases) page of this repository. To get notified about new versions, click **Watch → Custom → Releases** at the top of this page.

## Changes from the original

The source code is the original. The changes are applied only at build time by [`scripts/free/patch.sh`](scripts/free/patch.sh):

- **Automatic update checks are off.** **Check for Updates** opens the Releases page of this repository. The Sparkle update feed points to an empty [`appcast-free.xml`](appcast-free.xml), so the app never offers to install the official paid build.
- **Announcements are off by default.** You can turn them on in Settings → General → Show Announcements.
- **No license needed.** The app is built with `LOCAL_BUILD`, the original's own flag for builds from source.
- **No iCloud sync for the dictionary** (also turned off by `LOCAL_BUILD`).
- **Apple Silicon (arm64) only.**
- **Ad-hoc signature, not notarized.** Gatekeeper needs `xattr -cr` or **Open Anyway** once, see [Install](#install).

## Issues and license

Report problems with installing these builds in [issues of this repository](https://github.com/ergSey/VoiceInk-Free/issues), not to the original author.

VoiceInk is © Pax (Beingpax) and contributors, licensed under [GPL-3.0](LICENSE). This repository keeps the original license and only adds build scripts.

---

## Original README

<div align="center">
  <img src="VoiceInk/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>VoiceInk</h1>
  <p>Voice to text app for macOS to transcribe what you say to text almost instantly</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2015.0%2B-brightgreen)
  [![GitHub release (latest by date)](https://img.shields.io/github/v/release/Beingpax/VoiceInk)](https://github.com/Beingpax/VoiceInk/releases)
  ![GitHub all releases](https://img.shields.io/github/downloads/Beingpax/VoiceInk/total)
  ![GitHub stars](https://img.shields.io/github/stars/Beingpax/VoiceInk?style=social)
  <p>
    <a href="https://tryvoiceink.com">Website</a> •
    <a href="https://www.youtube.com/@tryvoiceink">YouTube</a>
  </p>

  <a href="https://tryvoiceink.com">
    <img src="https://img.shields.io/badge/Download%20Now-Latest%20Version-blue?style=for-the-badge&logo=apple" alt="Download VoiceInk" width="250"/>
  </a>
</div>

---

VoiceInk is a native macOS application that transcribes what you say to text almost instantly. You can find all the information and download the app from [here](https://tryvoiceink.com). 

![VoiceInk Mac App](https://github.com/user-attachments/assets/12367379-83e7-48a6-b52c-4488a6a04bba)

After dedicating the past 5 months to developing this app, I've decided to open source it for the greater good. 

My goal is to make it **the most efficient and privacy-focused voice-to-text solution for macOS** that is a joy to use. While the source code is now open for experienced developers to build and contribute, purchasing a license helps support continued development and gives you access to automatic updates, priority support, and upcoming features.

## Features

- 🎙️ **Accurate Transcription**: Local AI models that transcribe your voice to text with 99% accuracy, almost instantly
- 🔒 **Privacy First**: 100% offline processing ensures your data never leaves your device
- ⚡ **Modes**: Intelligent app detection automatically applies your perfect pre-configured settings based on the app/ URL you're on
- 🧠 **Context Aware**: Smart AI that understands your screen content and adapts to the context
- 🎯 **Global Shortcuts**: Configurable keyboard or mouse shortcuts for quick recording and push-to-talk functionality
- 📝 **Personal Dictionary**: Train the AI to understand your unique terminology with custom words, industry terms, and smart text replacements
- 🔄 **Smart Modes**: Instantly switch between AI-powered modes optimized for different writing styles and contexts
- 🤖 **AI Assistant**: Built-in voice assistant mode for a quick chatGPT like conversational assistant

## Get Started

### Download
Get the latest version with a free trial from [tryvoiceink.com](https://tryvoiceink.com). Your purchase helps me work on VoiceInk full-time and continuously improve it with new features and updates.

#### Homebrew
Alternatively, you can install VoiceInk via `brew`:

```shell
brew install --cask voiceink
```

### Build from Source
As an open-source project, you can build VoiceInk yourself by following the instructions in [BUILDING.md](BUILDING.md). However, the compiled version includes additional benefits like automatic updates, priority support via Discord and email, and helps fund ongoing development.

## Requirements

- macOS 15.0 or later

## Documentation

- [Building from Source](BUILDING.md) - Detailed instructions for building the project
- [Contributing Guidelines](CONTRIBUTING.md) - How to contribute to VoiceInk
- [Code of Conduct](CODE_OF_CONDUCT.md) - Our community standards

## Contributing

This project is **not accepting pull requests** at this time. You're welcome to fork and modify VoiceInk for your own use.

You can still contribute by:
- Reporting bugs via [issues](https://github.com/Beingpax/VoiceInk/issues)
- Suggesting features or enhancements
- Improving documentation via issues

For more details, see our [Contributing Guidelines](CONTRIBUTING.md). For build instructions, see our [Building Guide](BUILDING.md).

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please:
1. Check the existing issues in the GitHub repository
2. Create a new issue if your problem isn't already reported
3. Provide as much detail as possible about your environment and the problem

## Acknowledgments

### Core Technology
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - High-performance inference of OpenAI's Whisper model
- [FluidAudio](https://github.com/FluidInference/FluidAudio) - Used for Parakeet model implementation
- [TranscribeCpp for Swift](https://github.com/Beingpax/Transcribe-cpp-swift) - SwiftPM distribution of [transcribe.cpp](https://github.com/handy-computer/transcribe.cpp), used for local GGUF transcription models
- [SenseVoice Small](https://huggingface.co/FunAudioLLM/SenseVoiceSmall) by FunAudioLLM / Alibaba - Multilingual model available under the [FunASR Model Open Source License Agreement](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE)

### Essential Dependencies
- [Sparkle](https://github.com/sparkle-project/Sparkle) - Keeping VoiceInk up to date
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - User-customizable keyboard shortcuts
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - Launch at login functionality
- [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter) - Media playback control during recording
- [Zip](https://github.com/marmelroy/Zip) - File compression and decompression utilities
- [Swift Atomics](https://github.com/apple/swift-atomics) - Low-level atomic operations for thread-safe concurrent programming


---

Made with ❤️ by Pax
