# Contributing directly to Inkies

First off, thanks for taking the time to contribute! 🎉

Inkies is a modern, native macOS editor for Ink stories, built with SwiftUI and SwiftData. We welcome contributions from the community to help make it even better.

## Project Structure & Technology Stack

- **Language**: Swift 6.2
- **UI Framework**: SwiftUI (macOS 14.6+)
- **Data Persistence**: SwiftData
- **Project Generation**: [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- **External Dependencies**: Managed via Swift Package Manager (e.g., WhatsNewKit)
- **Localization**: String Catalogs (`.xcstrings`)

**Note**: We do not commit the `.xcodeproj` file to the repository. It is generated locally using `project.yml`.

## Getting Started

### Prerequisites

1.  **Xcode 16+**: Ensure you have the latest stable version of Xcode installed.
2.  **Homebrew**: Required to install XcodeGen.

### Installation & Setup

1.  **Install XcodeGen**:
    ```bash
    brew install xcodegen
    ```

2.  **Clone the Repository**:
    ```bash
    git clone https://github.com/lpgneg19/inkies.git
    cd inkies
    ```

3.  **Generate the Project**:
    Run the generation script to create the `.xcodeproj` file and configure local paths:
    ```bash
    ./scripts/generate_project.sh
    ```
    > If you encounter permission issues, run `chmod +x scripts/generate_project.sh`.

4.  **Open the Project**:
    Open `inkies.xcodeproj` in Xcode.

## Development Workflow

1.  **Create a Branch**:
    Create a new branch for your feature or bug fix:
    ```bash
    git checkout -b feature/amazing-feature
    # or
    git checkout -b fix/critical-bug
    ```

2.  **Coding Standards**:
    - **SwiftLint**: We follow standard Swift linting rules.
    - **Localization**: Always use `String(localized: "...")` for user-facing strings. Do not hardcode strings.
    - **Architecture**:
      - Use `SwiftData` for model persistence.
      - Keep business logic decoupled from `View` code where possible.
      - Use `@Observable` macros for state management in models.

3.  **Modifying Project Settings**:
    If you need to add files or change build settings, **edit `project.yml`**, not the Xcode project settings directly. The `.xcodeproj` is transient and will be overwritten.

## Localization

We use Apple's **String Catalogs** (`.xcstrings`) for localization.
- **Adding new strings**: Use `String(localized: "Key")` in your SwiftUI views. Xcode will automatically discover these when building.
- **Translating**: Open `inkies/Localizable.xcstrings` in Xcode to add translations (e.g., Simplified Chinese).

## Reporting Bugs

Please use the GitHub Issues tab to report bugs. Include:
- A clear description of the issue.
- Steps to reproduce.
- Screenshots if applicable.
- Your macOS and Xcode versions.

## Submitting a Pull Request

1.  Push your branch to your fork.
2.  Open a Pull Request against the `main` branch.
3.  Provide a clear description of what your changes do.
4.  Ensure the project builds and runs without errors.

## License

By contributing, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
