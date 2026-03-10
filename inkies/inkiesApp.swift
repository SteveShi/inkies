//
//  inkiesApp.swift
//  inkies
//
//  Created by 石屿 on 2026/1/12.
//

import SwiftData
import SwiftUI
import WhatsNewKit

@main
struct inkiesApp: App {
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        
        // Define explicit storage path: ~/Library/Application Support/inkies/
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let storeFolderURL = appSupportURL.appendingPathComponent("inkies", isDirectory: true)

        // Ensure the directory exists
        try? fileManager.createDirectory(at: storeFolderURL, withIntermediateDirectories: true)

        let storeURL = storeFolderURL.appendingPathComponent("inkies.sqlite")

        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext // Add context for manual save if needed

    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .preferredColorScheme(appTheme.colorScheme)
                .environment(\.whatsNew, WhatsNewEnvironment(
                    whatsNewCollection: [
                        WhatsNew(
                            version: "0.7.3",
                            title: WhatsNew.Title(
                                text: WhatsNew.Text(String(localized: "What's New in Inkies"))),
                            features: [
                                .init(
                                    image: .init(systemName: "sidebar.left"),
                                    title: WhatsNew.Text(String(localized: "Refined 3-Column Layout")),
                                    subtitle: WhatsNew.Text(String(localized: "A beautiful native macOS layout with side-by-side editor, preview, and sidebar."))
                                ),
                                .init(
                                    image: .init(systemName: "arrow.uturn.backward"),
                                    title: WhatsNew.Text(String(localized: "Fixed Undo Logic")),
                                    subtitle: WhatsNew.Text(String(localized: "The Undo button now correctly reverts your choices while preserving the story log."))
                                ),
                                .init(
                                    image: .init(systemName: "menubar.rectangle"),
                                    title: WhatsNew.Text(String(localized: "Native Separators")),
                                    subtitle: WhatsNew.Text(String(localized: "Fixed missing titlebar separators and improved overall window visual hierarchy."))
                                )
                            ],
                            primaryAction: .init(title: WhatsNew.Text(String(localized: "Continue")))
                        ),
                        WhatsNew(
                            version: "0.7.2",
                            title: WhatsNew.Title(text: WhatsNew.Text(String(localized: "Version 0.7.2"))),
                            features: [
                                .init(
                                    image: .init(systemName: "text.format"),
                                    title: WhatsNew.Text(String(localized: "HTML Formatting")),
                                    subtitle: WhatsNew.Text(String(localized: "Support for italicized and bold text in the story preview using standard HTML tags."))
                                ),
                                .init(
                                    image: .init(systemName: "window.badge.clock"),
                                    title: WhatsNew.Text(String(localized: "Window State Recovery")),
                                    subtitle: WhatsNew.Text(String(localized: "The application now remembers its window size and position across launches."))
                                )
                            ],
                            primaryAction: .init(title: WhatsNew.Text(String(localized: "Continue")))
                        ),
                        WhatsNew(
                            version: "0.7.0",
                            title: WhatsNew.Title(text: WhatsNew.Text(String(localized: "Version 0.7.0"))),
                            features: [
                                .init(
                                    image: .init(systemName: "checkmark.seal"),
                                    title: WhatsNew.Text(String(localized: "Syntax Checking")),
                                    subtitle: WhatsNew.Text(String(localized: "Real-time Ink syntax validation with visual error and warning markers."))
                                ),
                                .init(
                                    image: .init(systemName: "text.justify.left"),
                                    title: WhatsNew.Text(String(localized: "Refined Ruler")),
                                    subtitle: WhatsNew.Text(String(localized: "Clean, minimalist line number display for improved focus and readability."))
                                ),
                                .init(
                                    image: .init(systemName: "hammer.fill"),
                                    title: WhatsNew.Text(String(localized: "Stability Fixes")),
                                    subtitle: WhatsNew.Text(String(localized: "Resolved rendering issues and improved document deletion behavior."))
                                )
                            ],
                            primaryAction: .init(title: WhatsNew.Text(String(localized: "Continue")))
                        )
                    ]
                ))
                .whatsNewSheet()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(inkiesApp.sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background || newPhase == .inactive {
                do {
                    // Note: We use the sharedModelContainer's mainContext specifically
                    try inkiesApp.sharedModelContainer.mainContext.save()
                } catch {
                }
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "New Ink File")) {
                    NotificationCenter.default.post(
                        name: Notification.Name("AddItem"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button(String(localized: "Save Project")) {
                    NotificationCenter.default.post(
                        name: Notification.Name("SaveProject"), object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button(String(localized: "Close")) {
                    if let window = NSApplication.shared.keyWindow {
                        window.close()
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button(String(localized: "Search")) {
                    NotificationCenter.default.post(
                        name: Notification.Name("SearchItems"), object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Picker(String(localized: "Theme"), selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.localizedName).tag(theme)
                    }
                }
            }

            CommandGroup(replacing: .importExport) {
                Section {
                    Button(String(localized: "Export Ink (.ink)")) {
                        NotificationCenter.default.post(
                            name: Notification.Name("ExportInk"), object: nil)
                    }
                    .keyboardShortcut("e", modifiers: .command)

                    Button(String(localized: "Export JSON (.json)")) {
                        NotificationCenter.default.post(
                            name: Notification.Name("ExportJSON"), object: nil)
                    }
                    .keyboardShortcut("j", modifiers: .command)

                    Button(String(localized: "Export Web (.html)")) {
                        NotificationCenter.default.post(
                            name: Notification.Name("ExportWeb"), object: nil)
                    }
                    .keyboardShortcut("b", modifiers: .command)  // 'b' for Build/Browser
                }
            }

            // MARK: - Story Menu
            CommandMenu(String(localized: "Story")) {
                Button(String(localized: "Go to anything...")) {
                    NotificationCenter.default.post(
                        name: Notification.Name("GotoAnything"), object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Button(String(localized: "Next Issue")) {
                    NotificationCenter.default.post(
                        name: Notification.Name("NextIssue"), object: nil)
                }
                .keyboardShortcut(".", modifiers: .command)

                Button(String(localized: "Add watch expression...")) {
                    NotificationCenter.default.post(
                        name: Notification.Name("AddWatchExpression"), object: nil)
                }

                Divider()

                Toggle(String(localized: "Tags visible"), isOn: .constant(true))

                Divider()

                Button(String(localized: "Word count and more")) {
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowWordCount"), object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }

            // MARK: - Ink Menu
            CommandMenu("Ink") {
                ForEach(InkSnippets.allCategories.indices, id: \.self) { index in
                    let category = InkSnippets.allCategories[index]
                    Menu(category.localizedName) {
                        ForEach(category.snippets.indices, id: \.self) { snippetIndex in
                            let snippet = category.snippets[snippetIndex]
                            Button(snippet.localizedName) {
                                NotificationCenter.default.post(
                                    name: Notification.Name("InsertSnippet"),
                                    object: snippet.ink)
                            }
                        }
                    }
                }
            }

            CommandGroup(replacing: .help) {
                Button(String(localized: "What's New in Inkies")) {
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowWhatsNew"), object: nil)
                }
            }
        }
    }
}

extension inkiesApp {
    @MainActor
    private func handleIncomingURL(_ url: URL) {
        // ... (rest of logic)
        let context = inkiesApp.sharedModelContainer.mainContext

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let filename = url.deletingPathExtension().lastPathComponent
            let content = try String(contentsOf: url, encoding: .utf8)

            // Create new item
            let newItem = Item(timestamp: Date(), title: filename, content: content)
            context.insert(newItem)
            // Try to force save
            try? context.save()
        } catch {
            print("Import error: \(error.localizedDescription)")
        }
    }
}
