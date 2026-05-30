# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Inkies** is a macOS editor and live previewer for the Ink narrative scripting language. It integrates the `inklecate` compiler to provide real-time compilation and preview of Ink scripts, with multi-format export capabilities (ink, json, html).

- **Platform**: macOS 14.6+
- **Language**: Swift 6.0
- **Frameworks**: SwiftUI, SwiftData, WebKit
- **Dependencies**: WhatsNewKit, Sparkle (auto-updates)
- **Build System**: XcodeGen (generates Xcode project from `project.yml`)

## Development Commands

### Project Generation
The Xcode project is generated from `project.yml` using XcodeGen:
```bash
# Generate/regenerate the Xcode project
sh scripts/generate_project.sh
# or directly:
xcodegen
```

**Always regenerate the project after modifying `project.yml` or changing project structure.**

### Building
```bash
# Build for verification (no code signing)
xcodebuild -project inkies.xcodeproj -scheme inkies -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  build

# Build with Xcode GUI
# Open inkies.xcodeproj and press Cmd+B
```

**Verification requirement**: After any code changes, run a build to ensure no compilation errors before committing.

### Dependencies
```bash
# Resolve Swift Package Manager dependencies
xcodebuild -resolvePackageDependencies -scheme inkies -project inkies.xcodeproj
```

## Architecture

### Core Components

**Models/** - Domain models and data structures
- `Item.swift`: SwiftData model for Ink documents (stored in `~/Library/Application Support/inkies/`)
- `InkSnippets.swift`: Predefined Ink code examples
- `AppTheme.swift`: Theme enumeration (light/dark/system)
- `InkExportDocument.swift`: Export document types
- `InkIssue.swift`: Compilation error/warning representation

**Services/** - Business logic and external integrations
- `InkCompiler.swift`: Manages `inklecate` binary execution for Ink→JSON compilation
  - Uses actor-based `CompilationCache` for performance
  - Handles process spawning and output parsing
  - Extracts compilation errors/warnings into `InkIssue` objects
- `InkHighlighter.swift`: Syntax highlighting for Ink language

**Views/** - UI components
- `ContentView.swift`: Main three-pane layout (sidebar, editor, preview)
- `Editor/InkTextView.swift`: NSTextView-based Ink code editor
- `Editor/LineNumberRulerView.swift`: Line number gutter for editor
- `Preview/WebView.swift`: WKWebView wrapper for InkJS runtime preview

**Utilities/** - Helper functions
- `HTMLGenerator.swift`: Generates standalone HTML with embedded InkJS runtime
  - Loads bundled `ink.min.js` from `Resources/Scripts/`
  - Injects compiled JSON and creates interactive story player
- `Updater.swift`: Sparkle auto-update integration
- `Extensions.swift`: Swift standard library extensions

### Key Architectural Patterns

1. **Compilation Pipeline**: 
   - User types Ink code → `InkCompiler` spawns `inklecate` process → Parses JSON output → Updates preview WebView with InkJS runtime

2. **Data Persistence**: 
   - SwiftData stores `Item` objects in `~/Library/Application Support/inkies/inkies.sqlite`
   - Shared `ModelContainer` defined in `inkiesApp.swift`

3. **Preview Rendering**:
   - `HTMLGenerator` creates self-contained HTML with InkJS
   - WebView loads HTML and executes story interactively
   - Theme-aware styling (dark/light mode)

4. **Resource Bundling**:
   - `inklecate` binary copied to `Contents/MacOS/` (executable)
   - `ink_compiler.dll` and `ink-engine-runtime.dll` copied to `Contents/Resources/Compiler/`
   - `ink.min.js` copied to `Contents/Resources/Scripts/`
   - Example files in `Contents/Resources/Examples/`

## Localization

All user-facing strings **must** be defined in `inkies/Resources/Localizable.xcstrings`. Hardcoded strings are prohibited.

Supported languages:
- English (en)
- Chinese Simplified (zh-Hans)

When adding new UI text:
1. Add entries to `Localizable.xcstrings` with both English and Chinese translations
2. Use `String(localized:)` or `LocalizedStringKey` in SwiftUI
3. Maintain parity between languages (no missing translations)

## Release Process

### Version Management
- Version number: `project.yml` → `MARKETING_VERSION`
- Build number: `project.yml` → `CURRENT_PROJECT_VERSION`
- Changelog: `CHANGELOG.md` (bilingual format required)

### Changelog Format
```markdown
## [X.Y.Z] - YYYY-MM-DD

### English
- Feature/fix description in English

### Chinese
- 中文功能/修复描述
```

The release workflow extracts version from `CHANGELOG.md` and splits English/Chinese sections for Sparkle update notes.

### Critical Release Workflow Details

The GitHub Actions release workflow (`.github/workflows/release.yml`) has specific requirements:

1. **Version Extraction**: Uses `sed -n '/## \[/p' CHANGELOG.md | head -n 1` to parse version
2. **Sparkle Signing**: 
   - Private key must be cleaned with `tr -dc A-Za-z0-9+/=`
   - Requires `DYLD_FRAMEWORK_PATH` pointing to Sparkle tools
   - Uses stdin for key: `echo "$KEY" | generate_appcast --ed-key-file -`
3. **Code Signing Order**: 
   - Sign nested components first (inside-out): Sparkle.framework → inklecate → app bundle
   - Use `--entitlements inkies/inkies.entitlements` for inklecate (JIT entitlements required for CoreCLR)
4. **Multi-Architecture**: Builds Universal binary, then splits to x86_64 and arm64 DMGs

**Do not modify these critical workflow steps without explicit approval.**

## Swift 6 Concurrency

This project uses Swift 6.0 with strict concurrency:
- `SWIFT_VERSION: 6.0`
- `SWIFT_APPROACHABLE_CONCURRENCY: YES`
- `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`

Key patterns:
- `CompilationCache` is an `actor` for thread-safe caching
- Most UI code runs on `@MainActor`
- Use `Task { await ... }` for async operations

## Bundle Identifier Convention

Use `listentotherain.*` prefix for all bundle identifiers (not `com.steveshi.*`).

Current app bundle ID: `listentotherain.inkies`

## Development Workflow

1. Make code changes
2. If `project.yml` changed: run `xcodegen`
3. Build to verify: `xcodebuild ... build`
4. Test manually in Xcode (Cmd+R)
5. Clean up any temporary `.log` or `.txt` files
6. Commit changes

## External Dependencies

- **inklecate**: Ink compiler binary (install via `brew install inkle/inkle/inklecate` or bundle manually)
- **InkJS**: JavaScript runtime for Ink (bundled as `ink.min.js`)
- **WhatsNewKit**: "What's New" feature presentation
- **Sparkle**: Auto-update framework (2.x)
