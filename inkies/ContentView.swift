import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WebKit
import WhatsNewKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    // WhatsNew State
    @State private var manualWhatsNew: WhatsNew?

    private var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    @State private var selection: Item?
    @State private var showingRenameAlert = false
    @State private var itemToRename: Item?
    @State private var renameTitle = ""
    @State private var searchText = ""
    @State private var isSearchMode = false
    @FocusState private var isSearchFieldFocused: Bool

    // Export States
    @State private var showingExport = false
    @State private var exportType: UTType = .ink
    @State private var exportDocument: InkExportDocument?
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""
    @State private var isExporting = false

    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @State private var showingWordCount = false
    @State private var showingWatchExpression = false
    @State private var watchExpression = ""
    @State private var tagsVisible = true
    @State private var wordCountStats: (words: Int, characters: Int, lines: Int, knots: Int) = (
        0, 0, 0, 0
    )

    var body: some View {
        navigationSplitView
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AddItem"))) {
                _ in
                addItem()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SaveProject")))
        {
            _ in
            try? modelContext.save()
        }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SearchItems")))
        {
            _ in
            withAnimation {
                isSearchMode = true
                isSearchFieldFocused = true
            }
        }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GotoAnything")))
        {
            _ in
            withAnimation {
                isSearchMode = true
                isSearchFieldFocused = true
            }
        }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NextIssue"))) {
                _ in
                if let item = selection {
                    Task { await refreshPreview(for: item) }
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: Notification.Name("AddWatchExpression"))
            ) { _ in
                showingWatchExpression = true
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToggleTags"))) {
                _ in
                tagsVisible.toggle()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: Notification.Name("ShowWordCount"))
            ) {
                _ in
                if let item = selection {
                    wordCountStats = calculateStats(for: item.content)
                    showingWordCount = true
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: Notification.Name("InsertSnippet"))
            ) {
                notification in
                if let snippet = notification.object as? String, let item = selection {
                    item.content += snippet
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowWhatsNew")))
        {
            _ in
            manualWhatsNew = WhatsNew(
                version: "0.7.0",
                title: WhatsNew.Title(
                    text: WhatsNew.Text(String(localized: "What's New in Inkies"))),
                features: [
                    .init(
                        image: .init(systemName: "exclamationmark.triangle"),
                        title: WhatsNew.Text(String(localized: "Syntax Checking")),
                        subtitle: WhatsNew.Text(
                            String(
                                localized:
                                    "Real-time Ink syntax validation with visual error and warning markers."))
                    ),
                    .init(
                        image: .init(systemName: "list.number"),
                        title: WhatsNew.Text(String(localized: "Refined Ruler")),
                        subtitle: WhatsNew.Text(
                            String(
                                localized:
                                    "Clean, minimalist line number display for improved focus and readability."
                            ))
                    ),
                    .init(
                        image: .init(systemName: "checkmark.circle"),
                        title: WhatsNew.Text(String(localized: "Stability Fixes")),
                        subtitle: WhatsNew.Text(
                            String(
                                localized:
                                    "Resolved rendering issues and improved document deletion behavior."))
                    )
                ],
                primaryAction: .init(
                    title: WhatsNew.Text(String(localized: "Continue"))
                )
            )
        }
            .sheet(item: $manualWhatsNew) { whatsNew in
                WhatsNewView(whatsNew: whatsNew)
            }
            .fileExporter(
                isPresented: $showingExport,
                document: exportDocument,
                contentType: exportType,
                defaultFilename: {
                    switch exportType {
                    case .ink: return "Story"
                    case .json: return "story"
                    case .html: return "index"
                    default: return "file"
                    }
                }()
            ) { result in
                handleExportResult(result)
            }
            .alert(String(localized: "Export Failed"), isPresented: $showingExportError) {
                Button(String(localized: "OK")) {}
            } message: {
                Text(exportErrorMessage)
            }
            .alert(String(localized: "Document Statistics"), isPresented: $showingWordCount) {
                Button(String(localized: "OK")) {}
            } message: {
                Text(
                    """
                    \(String(localized: "Words")): \(wordCountStats.words)
                    \(String(localized: "Characters")): \(wordCountStats.characters)
                    \(String(localized: "Lines")): \(wordCountStats.lines)
                    \(String(localized: "Knots")): \(wordCountStats.knots)
                    """)
            }
            .alert(String(localized: "Add Watch Expression"), isPresented: $showingWatchExpression)
        {
            TextField(String(localized: "Enter variable name to watch"), text: $watchExpression)
            Button(String(localized: "OK")) {
                    // In full implementation, this would add to a watch list
                    watchExpression = ""
                }
            Button(String(localized: "Cancel"), role: .cancel) {
                    watchExpression = ""
                }
            }
    }

    // MARK: - Editor State
    @State private var previewContent: String = ""
    @State private var lastCompiledContent: String = ""
    @State private var inkIssues: [InkIssue] = []
    @State private var debounceTask: Task<Void, Never>?
    @State private var compilationTask: Task<Void, Never>?
    @StateObject private var webViewHandler = WebViewActionHandler()

    private var navigationSplitView: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebarView
                .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 250)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: addItem) {
                            Label(String(localized: "Add Item"), systemImage: "plus")
                        }
                    }
                }
                .alert(String(localized: "Rename Document"), isPresented: $showingRenameAlert) {
                    TextField(String(localized: "New Title"), text: $renameTitle)
                    Button(String(localized: "Rename")) {
                        if let item = itemToRename {
                            item.title = renameTitle
                            try? modelContext.save()
                        }
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                }
        } content: {
            Group {
                if let selection {
                    editorColumnView(for: selection)
                } else {
                    Text(String(localized: "Select a document"))
                        .foregroundColor(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: .infinity)
        } detail: {
            Group {
                if selection != nil {
                    previewColumnView
                } else {
                    Color.clear
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: .infinity)
            .toolbar {
                // Placing toolbar in detail makes macOS draw the separator between Editor and Preview
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { webViewHandler.undo() }) {
                        Label(String(localized: "Undo"), systemImage: "arrow.uturn.backward")
                    }
                    .help(String(localized: "Return to previous branch"))
                    .disabled(selection == nil)
                    
                    Button(action: { webViewHandler.restart() }) {
                        Label(String(localized: "Restart"), systemImage: "arrow.counterclockwise")
                    }
                    .help(String(localized: "Restart story"))
                    .disabled(selection == nil)
                }
                
                mainToolbar
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { oldValue, newValue in
            // Handle document switch
            debounceTask?.cancel()
            compilationTask?.cancel()
            if let newItem = newValue {
                compileContent(newItem.content)
            } else {
                previewContent = ""
                lastCompiledContent = ""
                inkIssues = []
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var sidebarView: some View {
        List(selection: $selection) {
            ForEach(filteredItems) { item in
                NavigationLink(value: item) {
                    Text(item.title.isEmpty ? String(localized: "Untitled") : item.title)
                }
                .contextMenu {
                    Button(String(localized: "Rename")) {
                        itemToRename = item
                        renameTitle = item.title
                        showingRenameAlert = true
                    }
                    Button(String(localized: "Delete"), role: .destructive) {
                        if selection?.id == item.id {
                            selection = nil
                        }
                        modelContext.delete(item)
                    }
                    Divider()
                    Menu(String(localized: "Export...")) {
                        Button(String(localized: "Export Ink (.ink)")) { prepareExportInk(item) }
                        Button(String(localized: "Export JSON (.json)")) {
                            Task { await prepareExportJson(item) }
                        }
                        Button(String(localized: "Export Web (.html)")) {
                            Task { await prepareExportWeb(item) }
                        }
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
    }



    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 8) {
                if isSearchMode {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(String(localized: "Search"), text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($isSearchFieldFocused)
                            .frame(width: 200)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.unemphasizedSelectedTextBackgroundColor).opacity(0.1))
                    .cornerRadius(8)

                    Button(String(localized: "Cancel")) {
                        withAnimation {
                            isSearchMode = false
                            searchText = ""
                        }
                    }
                } else {
                    if selection != nil {
                        Menu {
                            Button(String(localized: "Export Ink (.ink)")) {
                                if let item = selection { prepareExportInk(item) }
                            }
                            Button(String(localized: "Export JSON (.json)")) {
                                if let item = selection { Task { await prepareExportJson(item) } }
                            }
                            Button(String(localized: "Export Web (.html)")) {
                                if let item = selection { Task { await prepareExportWeb(item) } }
                            }
                        } label: {
                            Label(
                                String(localized: "Export..."), systemImage: "square.and.arrow.up")
                        }
                    }

                    Button(action: {
                        withAnimation {
                            isSearchMode = true
                            isSearchFieldFocused = true
                        }
                    }) {
                        Label(String(localized: "Search"), systemImage: "magnifyingglass")
                    }
                }
            }
        }
    }

    // MARK: - Export Logic

    private func prepareExportInk(_ item: Item) {
        exportType = .ink
        exportDocument = InkExportDocument(content: item.content, utType: .ink)
        showingExport = true
    }

    private func prepareExportJson(_ item: Item) async {
        isExporting = true
        do {
            let json = try await InkCompiler.shared.compile(item.content)
            exportType = .json
            exportDocument = InkExportDocument(content: json, utType: .json)
            showingExport = true
        } catch {
            print("Export Failed: \(error.localizedDescription)")
            exportErrorMessage =
                "\(String(localized: "Compiler Error: inklecate might be missing."))\n\(error.localizedDescription)"
            showingExportError = true
        }
        isExporting = false
    }

    private func prepareExportWeb(_ item: Item) async {
        isExporting = true
        do {
            let json = try await InkCompiler.shared.compile(item.content)
            // Generate full HTML
            let html = generateHTML(for: json, theme: appTheme)
            exportType = .html
            exportDocument = InkExportDocument(content: html, utType: .html)
            showingExport = true
        } catch {
            print("Web Export Failed: \(error.localizedDescription)")
            exportErrorMessage =
                "\(String(localized: "Compiler Error: inklecate might be missing."))\n\(error.localizedDescription)"
            showingExportError = true
        }
        isExporting = false
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Saved to \(url)")
        case .failure(let error):
            print("Export failed: \(error.localizedDescription)")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(
                timestamp: Date(), title: String(localized: "New Document"), content: "")
            modelContext.insert(newItem)
            selection = newItem
            try? modelContext.save()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = items[index]
                if selection?.id == item.id {
                    selection = nil
                }
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }

    // MARK: - Column Views

    @ViewBuilder
    private func editorColumnView(for item: Item) -> some View {
        @Bindable var bindableItem = item
        InkTextView(text: $bindableItem.content, issues: inkIssues)
            // Critical for NSViewRepresentable inside NavigationSplitView column
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Use layoutPriority to prevent 0-height collapse
            .layoutPriority(1)
            .navigationTitle(item.title.isEmpty ? String(localized: "Untitled") : item.title)
    }

    @ViewBuilder
    private var previewColumnView: some View {
        WebView(content: $previewContent, 
                lastCompiledContent: $lastCompiledContent,
                actionHandler: webViewHandler)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .background(
                appTheme == .dark ? Color(red: 0.118, green: 0.118, blue: 0.118) : .white)
            .navigationTitle(String(localized: "Preview"))
    }

    private func compileContent(_ content: String) {
        compilationTask?.cancel()
        compilationTask = Task {
            do {
                let json = try await InkCompiler.shared.compile(content)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.previewContent = json
                        if webViewHandler.isReady {
                            webViewHandler.update(json: json)
                        }
                        self.lastCompiledContent = content
                    }
                }
            } catch {
                if !Task.isCancelled {
                    let issues = await InkCompiler.shared.analyzeIssues(content)
                    await MainActor.run {
                        self.previewContent = "COMPILER_ERROR: \(error.localizedDescription)"
                        self.lastCompiledContent = content
                        self.inkIssues = issues
                    }
                }
            }
            
            if !Task.isCancelled {
                let issues = await InkCompiler.shared.analyzeIssues(content)
                await MainActor.run {
                    self.inkIssues = issues
                }
            }
        }
    }

    // MARK: - Story Menu Helper Functions

    private func calculateStats(for content: String) -> (
        words: Int, characters: Int, lines: Int, knots: Int
    ) {
        let characters = content.count
        let lines = content.components(separatedBy: .newlines).count

        // Word count (excluding Ink syntax)
        let cleanedContent =
            content
            .replacingOccurrences(of: "===", with: " ")
            .replacingOccurrences(of: "->", with: " ")
            .replacingOccurrences(of: "~", with: " ")
            .replacingOccurrences(of: "*", with: " ")
            .replacingOccurrences(of: "+", with: " ")
        let words = cleanedContent.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count

        // Count knots (=== knotName ===)
        let knotPattern = try? NSRegularExpression(pattern: "===\\s*\\w+\\s*===", options: [])
        let knotMatches =
            knotPattern?.numberOfMatches(
                in: content,
                options: [],
                range: NSRange(content.startIndex..., in: content)
            ) ?? 0

        return (words, characters, lines, knotMatches)
    }

    private func refreshPreview(for item: Item) async {
        // This triggers a recompilation by slightly modifying and restoring content
        // In a full implementation, this would navigate to the next compiler error
        _ = try? await InkCompiler.shared.compile(item.content)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
