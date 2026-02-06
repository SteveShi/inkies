# Inkies 🖋️

**Inkies** is a powerful, lightweight macOS editor and live previewer for the **Ink** narrative scripting language (by [inkle](https://www.inklestudios.com/)). It’s designed to provide a sleek, modern, and localized experience for writers and game developers.

![App Icon](inkies/Assets.xcassets/AppIcon.appiconset/mac_512@2x.png)

## ✨ Features

- **Live Previewing**: See your story come to life in real-time as you type.
- **On-the-fly Compilation**: Integrated with the `inklecate` compiler to transform raw Ink code into playable JSON instantly.
- **Native macOS Experience**: Built with SwiftUI, providing a fast, responsive, and familiar interface.
- **Multi-format Export**:
  - Raw Ink Source (`.ink`)
  - Compiled JSON (`.json`)
  - Standalone Web Page (`.html`)
- **File Association**: Seamlessly open and import `.ink` files directly from Finder.
- **Localization**: Full support for **English** and **Chinese (Simplified)**.
- **Rich Debugging**: Built-in debug console within the preview pane for tracking InkJS execution.

## 🚀 Getting Started

### Prerequisites

1. **Mac OS**: Optimized for macOS Big Sur and later.
2. **Inklecate Compiler**: Inkies requires the `inklecate` binary to compile scripts. 
   - You can install it via Homebrew: `brew install inkle/inkle/inklecate`
   - *Alternative*: Drag the `inklecate` binary directly into the Xcode project bundle.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/steve/inkies.git
   ```
2. Generate the Xcode project:
   ```bash
   sh scripts/generate_project.sh
   ```
3. Open `inkies.xcodeproj` in Xcode.
4. Build and Run (**Cmd + R**).


## 🛠️ Built With

- **SwiftUI & SwiftData**: Modern Apple frameworks for UI and persistence.
- **InkJS**: The JavaScript port of the Ink runtime for the web preview.
- **WebKit**: For rendering the interactive story preview.

## 🌏 Localization

Current supported languages:
- 🇺🇸 English
- 🇨🇳 Chinese (Simplified)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Thanks to [inkle](https://github.com/inkle) for creating the incredible Ink language.
- Thanks to the [inkjs](https://github.com/y-less/inkjs) maintainers for the runtime.
