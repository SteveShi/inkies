# Changelog

All notable changes to this project will be documented in this file.

## 0.7.3 (2026-03-10)

### 🛠 macOS UI & Logic Restoration
- **Native 3-Column Layout**: Fully restored the macOS three-column architecture (Sidebar | Editor | Preview).
- **Titlebar Separators**: Fixed an issue where titlebar separators would disappear by correctly positioning toolbars and removing conflicting modifiers.
- **Improved Button Layout**: Consolidated all primary actions (Undo, Restart, Search, Export) to the right-most preview column for a cleaner user experience.
- **Undo Logic Fix**: Resolved a critical bug where the "Undo" action in the preview functioned identical to "Restart". It now correctly re-renders the previous story state.
- **Symmetric Layout**: Balanced the default width of the editor and preview columns.

## 0.7.2 (2026-03-10)

### 🆕 New Features
- **HTML Formatting Support**: The story preview now correctly renders standard HTML tags like `<i>` and `<b>` for italicized and bold text.

### 🛠 Refined UI & Fixes
- **Project Structure**: Resolved a spec validation error where `InkIcon.png` was missing by updating the reference to `InkIcon.icns`.

## 0.7.1 (2026-03-10)

### 🛠 Refined UI & Experience
- **Window State Recovery**: The application now remembers its window size and position across launches.
- **Improved Preview Navigation**: Disabled auto-scroll to the bottom in the rendering window during content editing to prevent interference with reading/editing.

## 0.7.0 (2026-03-09)

### 🆕 New Features
- **Ink Syntax Checking**: Integrated real-time syntax validation. Errors and warnings are now visually marked with red and yellow indicators in the line number ruler.
- **Improved Line Number Ruler**: Refined the ruler with a clean, minimalist design as per user feedback, providing better spacing and readability.

### 🛠 Stability & Refined UI
- **Enhanced Rendering**: Fixed a critical issue where the editor text would sometimes disappear due to background rendering interference.
- **Empty State Logic**: Improved navigation behavior to properly clear the editor and selection when all documents are deleted.
- **Project Structure**: Resolved file scope issues and regenerated the Xcode project to ensure all new models (like `InkIssue`) are correctly included.

## 0.6.2 (2026-02-12)

### 🐞 Bug Fixes
- **Persistence**: Fixed data loss after application inactive period by implementing explicit saves and lifecycle-based triggers.
- **Storage Unification**: Moved data storage to `~/Library/Application Support/inkies/` to support non-paid developer accounts and avoid sandbox issues.
- **Cleanup**: Removed remaining debug logs and refined project configuration.

## 0.6.1 (2026-02-11)

### 🐞 Bug Fixes
- **UI Glitches**: Fixed toolbar background disappearing on resize and preview content persistence issues.
- **Localization**: Added missing Chinese translations for "Continue" button and "What's New" content.

## 0.6.0 (2026-02-11)

### 🆕 New Features
- **Real-time Syntax Highlighting**: Added a professional native editor with live highlighting for Ink keywords, choices, tags, and logic.
- **Preview Controls**: Relocated "Undo" and "Restart" functionality to the main toolbar for easier story navigation and testing.
- **What's New Gallery**: Updated the onboarding experience to showcase the latest features.

### 🚀 Performance & UI
- **Flicker-free Rendering**: Implemented a native bridge for incremental WebView updates, ensuring the story state persists during editing.
- **Improved Responsiveness**: Reduced compilation latency and optimized the background build process.
- **Clean Interface**: Removed the debug console and unified the background colors for a premium appearance.

## 0.5.1 (2026-02-11)

### 🚀 Performance Optimizations
- **Faster Rendering**: Implemented compilation caching and optimized WebView updates to significantly improve preview rendering speed.
- **Debounce Optimization**: Reduced debounce time from 600ms to 400ms for more responsive editing experience.

### 🛠 Infrastructure Improvements
- **Included Compiler**: Integrated `inklecate` compiler directly into the app bundle, eliminating the need for users to manually install it.
- **Build System Enhancement**: Updated project configuration to properly include required resources in the application bundle.

### 📦 Repository Cleanup
- **Improved .gitignore**: Updated to exclude unnecessary files and folders, including IDE-specific files, temporary files, and Windows-specific DLLs.

## 0.5.0 (2026-01-18)

### 🚀 Performance & Infrastructure
- **Swift 6.2 Update**: Upgraded the project to Swift 6.2 to leverage the latest language features and performance improvements.
- **Concurrency Safety**: Refactored `InkCompiler` into an `actor` to ensure strict concurrency safety in line with Swift 6 standards.
- **Dependency Optimization**: Evaluated JSON parsing libraries and optimized for performance by maintaining lightweight native string handling.

### 🆕 New Features
- **What's New Gallery**: Integrated `WhatsNewKit` to provide a visually rich overview of new features when users open the app after an update.

## 0.4.0

### 🎨 Simplified Theme System
- **Cleaner Menu**: The theme selection has been moved up one level for faster access. "Theme" is now a direct picker in the menu bar.
- **Focused Options**: We've removed the "Follow System" option to provide a more predictable manual control over the app's appearance. Choose between **Light Mode** and **Dark Mode**.

### 🛠 Stability and Fixes
- **Build Success**: Resolved critical compilation errors that were affecting the project build pipeline.
- **Improved Reliability**: Fixed issues with HTML generation during web export to ensure consistent output across different themes.

## 0.3.0

### 🎨 Theme Customization
- **Theme Switching**: Introduced the choice between Follow System, Light Mode, and Dark Mode.
- **Dynamic Preview**: The game preview (WebView) adapts its styling to match the selected theme.

### 🚀 CI/CD Automation
- **Automated Releases**: Basic GitHub Actions setup for Universal App builds and DMG packaging.
