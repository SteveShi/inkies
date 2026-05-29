# Changelog

All notable changes to this project will be documented in this file.

## [1.0.3] - 2026-05-30

### Fixed
- **Compiler Exec Format Error**: Resolved the `Exec format error` (POSIX error 8, `ENOEXEC`) on Apple Silicon by copying the `inklecate` compiler and DLL dependencies to the standard macOS `Contents/MacOS/` bundle directory and programmatically stripping Gatekeeper quarantine attributes.

---

### Chinese
### 修复
- **编译器执行格式错误**: 修复了 Apple Silicon 平台下的“执行格式错误”（Exec format error），通过将 `inklecate` 编译器及 DLL 依赖迁移至标准 `Contents/MacOS/` 目录，并在运行时自动清除系统 Quarantine 检疫标记以防止被 Gatekeeper 拦截。

## [1.0.2] - 2026-05-23

### Fixed
- **Compiler Stability**: Resolved a pipe-buffer deadlock in the Ink compilation pipeline that could hang large story compilations.
- **Compilation Cache**: Replaced full-text base64 keys with SHA-256 digests to roughly halve cache memory usage.

### Changed
- **Syntax Highlighter**: Rewrote the rule engine — comments and strings are now applied last so embedded `->`, `"..."` and `#` no longer get mis-colored. Added support for stitches (`= name`), tunnel returns (`->->`), text interpolation `{...}`, glue `<>`, choice labels `(name)` and additional keywords (`INCLUDE`, `EXTERNAL`, `END`, `DONE`, `START`, `true`, `false`, `not`, `and`, `or`, `mod`, `ref`, `return`).
- **Editor Performance**: Pre-compiled all highlighter regexes as static constants; debounced re-highlighting on text change (150 ms) for smoother large-document editing.
- **Line Number Ruler**: Cached newline offsets and switched to binary search for the starting line number, removing the per-frame O(N) scan during scroll.

### Added
- **Syntax Smoke Test**: Bundled `Examples/syntax_smoke_test.ink` covering every supported Ink syntax element for visual regression checks.

---

### Chinese
### 修复
- **编译器稳定性**: 修复 Ink 编译流程中管道缓冲区死锁问题,避免大型剧本编译时挂起。
- **编译缓存**: 将基于全文 base64 的缓存键替换为 SHA-256 摘要,缓存内存占用约减半。

### 变更
- **语法高亮**: 重写规则引擎——注释与字符串现在最后应用,内部的 `->`、`"..."`、`#` 不再被错误着色。新增对 stitch(`= name`)、tunnel 返回(`->->`)、文本插值 `{...}`、glue `<>`、选项标签 `(name)` 以及更多关键字(`INCLUDE`、`EXTERNAL`、`END`、`DONE`、`START`、`true`、`false`、`not`、`and`、`or`、`mod`、`ref`、`return`)的支持。
- **编辑器性能**: 所有高亮正则预编译为静态常量;文本变更后的重新高亮加入 150 ms 防抖,大文档编辑更流畅。
- **行号标尺**: 缓存换行符偏移并改为二分查找起始行号,移除滚动时每帧 O(N) 扫描。

### 新功能
- **语法回归样例**: 内置 `Examples/syntax_smoke_test.ink`,覆盖所有受支持的 Ink 语法元素,便于人眼回归。

## [1.0.1] - 2026-05-05

### Changed
- **Compiler Update**: Updated the internal `inklecate` compiler to the latest version for improved stability and performance.
- **Git LFS Integration**: Migrated large binary assets to Git LFS to optimize repository performance.

---

### Chinese
### 变更
- **编译器更新**: 将内置的 `inklecate` 编译器更新至最新版本，提升了稳定性和性能。
- **Git LFS 集成**: 将大型二进制资产迁移至 Git LFS 管理，优化了代码仓库性能。

## [1.0.0] - 2026-03-29

### Added
- **Sparkle Support**: Integrated Sparkle for automated, secure in-app updates.
- **Version 1.0**: Officially reaching the stable release milestone.
- **Improved UX**: Added "Check for Updates..." to the application menu and updated the onboarding experience.

---

### Chinese
### 新功能
- **Sparkle 支持**: 集成了 Sparkle 框架，支持安全且自动的应用内更新。
- **1.0 版本**: 正式达到稳定发布里程碑。
- **用户体验优化**: 在应用菜单中增加了“检查更新...”选项，并更新了新版本特性展示。

## [0.7.3] - 2026-03-10

### 🛠 macOS UI & Logic Restoration
- **Native 3-Column Layout**: Fully restored the macOS three-column architecture (Sidebar | Editor | Preview).
- **Titlebar Separators**: Fixed an issue where titlebar separators would disappear by correctly positioning toolbars and removing conflicting modifiers.
- **Improved Button Layout**: Consolidated all primary actions (Undo, Restart, Search, Export) to the right-most preview column for a cleaner user experience.
- **Undo Logic Fix**: Resolved a critical bug where the "Undo" action in the preview functioned identical to "Restart". It now correctly re-renders the previous story state.
- **Symmetric Layout**: Balanced the default width of the editor and preview columns.

## [0.7.2] - 2026-03-10

### 🆕 New Features
- **HTML Formatting Support**: The story preview now correctly renders standard HTML tags like `<i>` and `<b>` for italicized and bold text.

### 🛠 Refined UI & Fixes
- **Project Structure**: Resolved a spec validation error where `InkIcon.png` was missing by updating the reference to `InkIcon.icns`.

## [0.7.1] - 2026-03-10

### 🛠 Refined UI & Experience
- **Window State Recovery**: The application now remembers its window size and position across launches.
- **Improved Preview Navigation**: Disabled auto-scroll to the bottom in the rendering window during content editing to prevent interference with reading/editing.

## [0.7.0] - 2026-03-09

### 🆕 New Features
- **Ink Syntax Checking**: Integrated real-time syntax validation. Errors and warnings are now visually marked with red and yellow indicators in the line number ruler.
- **Improved Line Number Ruler**: Refined the ruler with a clean, minimalist design as per user feedback, providing better spacing and readability.

### 🛠 Stability & Refined UI
- **Enhanced Rendering**: Fixed a critical issue where the editor text would sometimes disappear due to background rendering interference.
- **Empty State Logic**: Improved navigation behavior to properly clear the editor and selection when all documents are deleted.
- **Project Structure**: Resolved file scope issues and regenerated the Xcode project to ensure all new models (like `InkIssue`) are correctly included.

## [0.6.2] - 2026-02-12

### 🐞 Bug Fixes
- **Persistence**: Fixed data loss after application inactive period by implementing explicit saves and lifecycle-based triggers.
- **Storage Unification**: Moved data storage to `~/Library/Application Support/inkies/` to support non-paid developer accounts and avoid sandbox issues.
- **Cleanup**: Removed remaining debug logs and refined project configuration.

## [0.6.1] - 2026-02-11

### 🐞 Bug Fixes
- **UI Glitches**: Fixed toolbar background disappearing on resize and preview content persistence issues.
- **Localization**: Added missing Chinese translations for "Continue" button and "What's New" content.

## [0.6.0] - 2026-02-11

### 🆕 New Features
- **Real-time Syntax Highlighting**: Added a professional native editor with live highlighting for Ink keywords, choices, tags, and logic.
- **Preview Controls**: Relocated "Undo" and "Restart" functionality to the main toolbar for easier story navigation and testing.
- **What's New Gallery**: Updated the onboarding experience to showcase the latest features.

### 🚀 Performance & UI
- **Flicker-free Rendering**: Implemented a native bridge for incremental WebView updates, ensuring the story state persists during editing.
- **Improved Responsiveness**: Reduced compilation latency and optimized the background build process.
- **Clean Interface**: Removed the debug console and unified the background colors for a premium appearance.

## [0.5.1] - 2026-02-11

### 🚀 Performance Optimizations
- **Faster Rendering**: Implemented compilation caching and optimized WebView updates to significantly improve preview rendering speed.
- **Debounce Optimization**: Reduced debounce time from 600ms to 400ms for more responsive editing experience.

### 🛠 Infrastructure Improvements
- **Included Compiler**: Integrated `inklecate` compiler directly into the app bundle, eliminating the need for users to manually install it.
- **Build System Enhancement**: Updated project configuration to properly include required resources in the application bundle.

### 📦 Repository Cleanup
- **Improved .gitignore**: Updated to exclude unnecessary files and folders, including IDE-specific files, temporary files, and Windows-specific DLLs.

## [0.5.0] - 2026-01-18

### 🚀 Performance & Infrastructure
- **Swift 6.2 Update**: Upgraded the project to Swift 6.2 to leverage the latest language features and performance improvements.
- **Concurrency Safety**: Refactored `InkCompiler` into an `actor` to ensure strict concurrency safety in line with Swift 6 standards.
- **Dependency Optimization**: Evaluated JSON parsing libraries and optimized for performance by maintaining lightweight native string handling.

### 🆕 New Features
- **What's New Gallery**: Integrated `WhatsNewKit` to provide a visually rich overview of new features when users open the app after an update.

## [0.4.0]

### 🎨 Simplified Theme System
- **Cleaner Menu**: The theme selection has been moved up one level for faster access. "Theme" is now a direct picker in the menu bar.
- **Focused Options**: We've removed the "Follow System" option to provide a more predictable manual control over the app's appearance. Choose between **Light Mode** and **Dark Mode**.

### 🛠 Stability and Fixes
- **Build Success**: Resolved critical compilation errors that were affecting the project build pipeline.
- **Improved Reliability**: Fixed issues with HTML generation during web export to ensure consistent output across different themes.

## [0.3.0]

### 🎨 Theme Customization
- **Theme Switching**: Introduced the choice between Follow System, Light Mode, and Dark Mode.
- **Dynamic Preview**: The game preview (WebView) adapts its styling to match the selected theme.

### 🚀 CI/CD Automation
- **Automated Releases**: Basic GitHub Actions setup for Universal App builds and DMG packaging.
