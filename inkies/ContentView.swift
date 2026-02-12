import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WebKit
import WhatsNewKit

// MARK: - Localization Helper (Moved to Localization.swift)

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
                version: "0.6.0",
                title: WhatsNew.Title(
                    text: WhatsNew.Text(String(localized: "What's New in Inkies"))),
                features: [
                    .init(
                        image: .init(systemName: "highlighter"),
                        title: WhatsNew.Text(String(localized: "Real-time Highlighting")),
                        subtitle: WhatsNew.Text(
                            String(
                                localized:
                                    "Native syntax highlighting for Ink script while you type."))
                    ),
                    .init(
                        image: .init(systemName: "arrow.uturn.backward.circle"),
                        title: WhatsNew.Text(String(localized: "Preview Controls")),
                        subtitle: WhatsNew.Text(
                            String(
                                localized:
                                    "Undo choices and restart your story directly from the toolbar."
                            ))
                    ),
                    .init(
                        image: .init(systemName: "gauge.with.needle"),
                        title: WhatsNew.Text(String(localized: "Performance Boost")),
                        subtitle: WhatsNew.Text(
                            String(
                                localized:
                                    "Flicker-free incremental updates and faster compilation."))
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

    private var navigationSplitView: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
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
        } detail: {
            detailView
        }
        .toolbar {
            mainToolbar
        }
        .toolbarBackground(.visible, for: .windowToolbar)
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

    // MARK: - Subviews

    @ViewBuilder
    private var detailView: some View {
        if let item = selection {
            EditorView(item: item)
                .id(item.id)  // Force recreation when item changes
                .onReceive(
                    NotificationCenter.default.publisher(for: Notification.Name("ExportInk"))
                ) { _ in
                    prepareExportInk(item)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: Notification.Name("ExportJSON"))
                ) { _ in
                    Task { await prepareExportJson(item) }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: Notification.Name("ExportWeb"))
                ) { _ in
                    Task { await prepareExportWeb(item) }
                }
        } else {
            Text(String(localized: "Select a document"))
                .foregroundColor(.secondary)
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
                                prepareExportInk(selection!)
                            }
                            Button(String(localized: "Export JSON (.json)")) {
                                Task { await prepareExportJson(selection!) }
                            }
                            Button(String(localized: "Export Web (.html)")) {
                                Task { await prepareExportWeb(selection!) }
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
                modelContext.delete(items[index])
            }
            try? modelContext.save()
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

struct EditorView: View {
    @Bindable var item: Item
    @State private var previewContent: String = ""
    @State private var lastCompiledContent: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    var body: some View {
        HStack(spacing: 0) {
            InkTextView(text: $item.content)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            WebView(content: $previewContent, lastCompiledContent: $lastCompiledContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    appTheme == .dark ? Color(red: 0.118, green: 0.118, blue: 0.118) : .white)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: undoStory) {
                    Label(String(localized: "Undo"), systemImage: "arrow.uturn.backward")
                }
                .help(String(localized: "Return to previous branch"))

                Button(action: restartStory) {
                    Label(String(localized: "Restart"), systemImage: "arrow.counterclockwise")
                }
                .help(String(localized: "Restart story"))
            }
        }
        .onChange(of: item.content) { oldValue, newValue in
            debounceTask?.cancel()

            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                previewContent = ""
                lastCompiledContent = ""
                return
            }

            if trimmed.hasPrefix("{") {
                previewContent = newValue
                lastCompiledContent = newValue
                return
            }

            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 250 * 1_000_000)  // 250ms debounce
                if !Task.isCancelled {
                    await compileContent(newValue)
                }
            }
        }
        .onAppear {
            print("INKIES DEBUG: EditorView appeared for item: \(item.title)")
            // Initial compilation on appear
            let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("{") {
                Task { await compileContent(item.content) }
            } else if trimmed.hasPrefix("{") {
                previewContent = item.content
                lastCompiledContent = item.content
            } else {
                previewContent = ""
                lastCompiledContent = ""
            }
        }
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func restartStory() {
        WebView.currentWebView?.evaluateJavaScript("window.restartStory()")
    }

    private func undoStory() {
        WebView.currentWebView?.evaluateJavaScript("window.undoStory()")
    }

    private func compileContent(_ content: String) {
        Task {
            do {
                let json = try await InkCompiler.shared.compile(content)
                if !Task.isCancelled {
                    await MainActor.run {
                        if WebView.isReadyForIncrementalUpdate {
                            WebView.currentWebView?.evaluateJavaScript(
                                "window.updateStory(\"\(json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\")"
                            ) { result, error in
                                if let error = error {
                                    print("INKIES DEBUG: JS updateStory error: \(error)")
                                    self.previewContent = json
                                }
                            }
                        } else {
                            self.previewContent = json
                        }
                        self.lastCompiledContent = content
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.previewContent = "COMPILER_ERROR: \(error.localizedDescription)"
                        self.lastCompiledContent = content
                    }
                }
            }
        }
    }
}

#if os(macOS)
    struct InkTextView: NSViewRepresentable {
        @Binding var text: String
        @AppStorage("appTheme") private var appTheme: AppTheme = .light

        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.autoresizingMask = [.width, .height]

            let textView = NSTextView()
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
            textView.delegate = context.coordinator
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

            // Background and coloring
            textView.backgroundColor =
                appTheme == .dark
                ? NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0) : .textBackgroundColor
            textView.insertionPointColor = appTheme == .dark ? .white : .black

            scrollView.documentView = textView
            return scrollView
        }

        func updateNSView(_ nsView: NSScrollView, context: Context) {
            guard let textView = nsView.documentView as? NSTextView else { return }

            if textView.string != text {
                let attributedString = InkHighlighter.highlight(text, theme: appTheme)
                textView.textStorage?.setAttributedString(attributedString)
            }

            // Update theme-based colors if changed
            textView.backgroundColor =
                appTheme == .dark
                ? NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0) : .textBackgroundColor
            textView.insertionPointColor = appTheme == .dark ? .white : .black
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, NSTextViewDelegate {
            var parent: InkTextView

            init(_ parent: InkTextView) {
                self.parent = parent
            }

            func textDidChange(_ notification: Notification) {
                guard let textView = notification.object as? NSTextView else { return }
                let newText = textView.string

                // Update the binding
                if parent.text != newText {
                    parent.text = newText
                }

                // Re-apply highlighting
                let attributedString = InkHighlighter.highlight(newText, theme: parent.appTheme)

                // Preserve cursor position
                let selectedRange = textView.selectedRange()
                textView.textStorage?.setAttributedString(attributedString)
                textView.setSelectedRange(selectedRange)
            }
        }
    }

    struct WebView: NSViewRepresentable {
        @Binding var content: String
        @Binding var lastCompiledContent: String

        static var currentWebView: WKWebView?
        static var isReadyForIncrementalUpdate: Bool = false

        func makeNSView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator

            // Enable developer tools for Safari debugging
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

            // Add message handler for communication
            webView.configuration.userContentController.add(
                context.coordinator, name: "inkiesBridge")
            
            Self.currentWebView = webView
            return webView
        }

        @AppStorage("appTheme") private var appTheme: AppTheme = .light

        func updateNSView(_ nsView: WKWebView, context: Context) {
            if context.coordinator.lastContent != content {
                let html = generateHTML(
                    for: content, theme: appTheme, enableIncrementalUpdate: true)
                nsView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
                context.coordinator.lastContent = content
                context.coordinator.isFirstLoad = false
            }
            Self.currentWebView = nsView
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
            var parent: WebView
            var lastContent: String = ""
            var isFirstLoad: Bool = true
            var isReadyForIncrementalUpdate: Bool = false

            init(_ parent: WebView) {
                self.parent = parent
            }

            func userContentController(
                _ userContentController: WKUserContentController,
                didReceive message: WKScriptMessage
            ) {
                if message.name == "inkiesBridge" {
                    if let body = message.body as? [String: Any],
                        let action = body["action"] as? String
                    {
                        if action == "ready" {
                            self.isFirstLoad = false
                            WebView.isReadyForIncrementalUpdate = true
                        }
                    }
                }
            }
        }
    }
#else
    struct WebView: UIViewRepresentable {
        @Binding var content: String
        @Binding var lastCompiledContent: String

        static var currentWebView: WKWebView?
        static var isReadyForIncrementalUpdate: Bool = false

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator

            // Add message handler for communication
            webView.configuration.userContentController.add(
                context.coordinator, name: "inkiesBridge")
            
            Self.currentWebView = webView
            return webView
        }

        @AppStorage("appTheme") private var appTheme: AppTheme = .light

        func updateUIView(_ uiView: WKWebView, context: Context) {
            if context.coordinator.lastContent != content {
                let html = generateHTML(
                    for: content, theme: appTheme, enableIncrementalUpdate: true)
                uiView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
                context.coordinator.lastContent = content
                context.coordinator.isFirstLoad = false
            }
            Self.currentWebView = uiView
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
            var parent: WebView
            var lastContent: String = ""
            var isFirstLoad: Bool = true
            var isReadyForIncrementalUpdate: Bool = false

            init(_ parent: WebView) {
                self.parent = parent
            }

            func userContentController(
                _ userContentController: WKUserContentController,
                didReceive message: WKScriptMessage
            ) {
                if message.name == "inkiesBridge" {
                    if let body = message.body as? [String: Any],
                        let action = body["action"] as? String
                    {
                        if action == "ready" {
                            self.isFirstLoad = false
                            WebView.isReadyForIncrementalUpdate = true
                        }
                    }
                }
            }
        }
    }
#endif

// Helper to find the InkJS library
private func getInkScript() -> String {
    if let path = Bundle.main.path(forResource: "ink.min", ofType: "js") {
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("INKIES DEBUG: local ink.min.js loaded successfully (\(content.count) bytes)")
            return
                "<script>/* InkJS included from Bundle (\(content.count) bytes) */\n\(content)</script>"
        } else {
            print("INKIES DEBUG: ERROR - local ink.min.js found but failed to read")
            return
                "<script>console.error('INKIES DEBUG: local ink.min.js found but failed to read');</script>"
        }
    }
    // Fallback to CDN if local file not found (User needs to add it to bundle)
    print("INKIES DEBUG: WARNING - local ink.min.js NOT found in bundle, using CDN fallback")
    return
        #"<script src="https://unpkg.com/inkjs/dist/ink.js"></script><script>console.warn('INKIES DEBUG: local ink.min.js NOT found in bundle, using CDN');</script>"#
}

private func generateHTML(
    for inkContext: String, theme: AppTheme, enableIncrementalUpdate: Bool = false
) -> String {
    let safeContent = inkContext.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "")

    let inkScriptTag = getInkScript()

    let textColor = theme == .dark ? "#ccc" : "#333"
    let bgColor = theme == .dark ? "#1e1e1e" : "#fdfdfd"
    let linkColor = theme == .dark ? "#64b5f6" : "#007aff"

    return """
        <!doctype html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Ink Preview</title>
            \(inkScriptTag)
            <style>
                body { 
                    font-family: "Georgia", serif; 
                    padding: 40px 10%; 
                    line-height: 1.8; 
                    color: \(textColor);
                    max-width: 800px;
                    margin: 0 auto;
                    background-color: \(bgColor);
                }
                a { color: \(linkColor); }
                .choice { 
                    cursor: pointer; 
                    color: #007aff; 
                    margin: 15px auto; 
                    padding: 8px 16px; 
                    border: 1px solid rgba(0, 122, 255, 0.3); 
                    border-radius: 4px; 
                    transition: all 0.2s; 
                    display: block;
                    width: fit-content;
                    text-align: center;
                    font-style: italic;
                }
                .choice:hover { 
                    background: rgba(0, 122, 255, 0.05); 
                    border-color: #007aff;
                }
                p { margin-bottom: 1.5em; text-align: justify; }
                pre { background: #f4f4f4; padding: 15px; border-radius: 4px; overflow-x: auto; color: #333; font-family: monospace; }
                em.end {
                    display: block;
                    text-align: center;
                    margin-top: 40px;
                    color: #999;
                    font-variant: small-caps;
                }
            </style>
        </head>
        <body>
            <div id="story"></div>

            <script>
                (function() {
                    var storyContent = "\(safeContent)";
                    var story = null;
                    var storyContainer = document.getElementById('story');
                    var history = [];
                    
                    function log(msg) {
                        console.log(msg);
                    }

                    window.onerror = function(msg, url, line) {
                        var errorMsg = "JS Error: " + msg + " (Line " + line + ")";
                        log(errorMsg);
                        
                        if (window.webkit && window.webkit.messageHandlers.inkiesBridge) {
                            window.webkit.messageHandlers.inkiesBridge.postMessage({
                                action: "error",
                                message: errorMsg
                            });
                        }
                        return false;
                    };
                    
                    // Console logging is standard now

                    function clearStory() {
                        storyContainer.innerHTML = '';
                    }

                    function renderParagraph(text) {
                        var p = document.createElement('p');
                        p.innerText = text;
                        storyContainer.appendChild(p);
                    }

                    function renderChoices(choices) {
                        choices.forEach(function(choice) {
                            var choiceDiv = document.createElement('div');
                            choiceDiv.classList.add('choice');
                            choiceDiv.innerText = choice.text;
                            choiceDiv.onclick = function() {
                                // Save state before making choice
                                if (story) history.push(story.state.toJson());
                                
                                story.ChooseChoiceIndex(choice.index);
                                var existingChoices = storyContainer.querySelectorAll('.choice');
                                existingChoices.forEach(c => c.remove());
                                continueStory();
                            };
                            storyContainer.appendChild(choiceDiv);
                        });
                    }

                    function renderEnd() {
                        var endP = document.createElement('p');
                        endP.innerHTML = "<em class='end'>--- End of Story ---</em>";
                        storyContainer.appendChild(endP);
                    }

                    function continueStory() {
                        while(story && story.canContinue) {
                            var paragraph = story.Continue();
                            renderParagraph(paragraph);
                        }
                        
                        if (story && story.currentChoices.length > 0) {
                            renderChoices(story.currentChoices);
                        } else {
                            renderEnd();
                        }
                    }

                    function updateStory(json) {
                        log("Updating story incrementally...");
                        loadStory(json);
                    }
                    window.updateStory = updateStory;

                    window.restartStory = function() {
                        log("Restarting story...");
                        loadStory(storyContent);
                    };

                    window.undoStory = function() {
                        if (history.length > 0) {
                            log("Undoing last choice...");
                            var prevState = history.pop();
                            story.state.LoadJson(prevState);
                            clearStory();
                            continueStory();
                        } else {
                            log("Nothing to undo.");
                        }
                    };

                    function loadStory(input) {
                        try {
                            const storyData = (typeof input === 'string') ? JSON.parse(input) : input;
                            story = new inkjs.Story(storyData);
                            history = []; // Clear history on new load
                            clearStory();
                            continueStory();
                        } catch (e) {
                            log("Error loading story: " + e);
                        }
                    }

                    function showError(errorMsg) {
                        clearStory();
                        storyContainer.innerHTML = `
                            <div style="background:#fee; color:#c00; padding:15px; border-left:4px solid #c00; border-radius:4px;">
                                <strong>Compilation Failed:</strong><br/>
                                <pre style="background:none; padding:0; margin-top:8px; white-space:pre-wrap;">${errorMsg}</pre>
                            </div>
                        `;
                    }

                    function showEmpty() {
                        clearStory();
                        storyContainer.innerHTML = "<p><em>Start writing...</em></p>";
                    }

                    try {
                        if (typeof inkjs === 'undefined') {
                            log("CRITICAL: inkjs library is missing! Please make sure 'ink.min.js' is added to the Xcode Target, or you have internet connection.");
                        }

                        if (storyContent.trim().length === 0) {
                            showEmpty();
                        } else if (storyContent.trim().startsWith('{')) {
                            loadStory(storyContent);
                        } else if (storyContent.startsWith('COMPILER_ERROR:')) {
                            var errorMsg = storyContent.substring('COMPILER_ERROR:'.length);
                            showError(errorMsg);
                        } else {
                            storyContainer.innerHTML = `
                                <p><strong>Raw Ink Code Detected</strong></p>
                                <p>Compiling...</p>
                            `;
                        }
                        
                        // Notify native side that JS is ready for incremental updates
                        if (window.webkit && window.webkit.messageHandlers.inkiesBridge) {
                            window.webkit.messageHandlers.inkiesBridge.postMessage({
                                action: "ready"
                            });
                        }
                        
                    } catch(e) {
                        log("Setup Error: " + e.message);
                    }
                })();
            </script>
        </body>
        </html>
        """
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

// MARK: - UTType Extensions
extension UTType {
    nonisolated static let ink = UTType(exportedAs: "com.inkle.ink")
    nonisolated static let inkJson = UTType(exportedAs: "com.inkle.ink-json")
    nonisolated static let inkJs = UTType(exportedAs: "com.inkle.ink-js")
}

// MARK: - Unified Export Document
struct InkExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.ink, .json, .html, .plainText] }

    var content: String
    var utType: UTType

    init(content: String, utType: UTType) {
        self.content = content
        self.utType = utType
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
            let text = String(data: data, encoding: .utf8)
        {
            content = text
        } else {
            content = ""
        }
        utType = .plainText
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Compilation Cache
actor CompilationCache {
    static let shared = CompilationCache()

    private var cache: [String: CacheEntry] = [:]
    private let maxCacheSize = 50
    private var accessOrder: [String] = []

    struct CacheEntry {
        let inkCode: String
        let compiledResult: String
        let timestamp: Date
        let hash: String
    }

    func getCachedResult(for inkCode: String) -> String? {
        let codeHash = hashString(inkCode)

        if let entry = cache[codeHash], entry.inkCode == inkCode {
            updateAccessOrder(for: codeHash)
            return entry.compiledResult
        }
        return nil
    }

    func cacheResult(inkCode: String, compiledResult: String) {
        let codeHash = hashString(inkCode)

        if cache.count >= maxCacheSize {
            removeOldestEntry()
        }

        let entry = CacheEntry(
            inkCode: inkCode,
            compiledResult: compiledResult,
            timestamp: Date(),
            hash: codeHash
        )

        cache[codeHash] = entry
        updateAccessOrder(for: codeHash)
    }

    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    private func hashString(_ string: String) -> String {
        let data = Data(string.utf8)
        return data.base64EncodedString()
    }

    private func updateAccessOrder(for hash: String) {
        accessOrder.removeAll { $0 == hash }
        accessOrder.append(hash)
    }

    private func removeOldestEntry() {
        guard !accessOrder.isEmpty else { return }
        let oldestHash = accessOrder.removeFirst()
        cache.removeValue(forKey: oldestHash)
    }
}

// MARK: - Ink Compiler Class
actor InkCompiler {
    static let shared = InkCompiler()
    private var currentProcess: Process?
    private var hasCheckedResources = false

    // Potential paths for inklecate
    private let possiblePaths = [
        "/opt/homebrew/bin/inklecate",
        "/usr/local/bin/inklecate",
    ]

    private var isCompiling = false
    private var pendingCompilation: Task<String, Error>?

    func findInklecate() -> String? {
        // 1. Check App Bundle Resources (Standard for bundled resources)
        if let bundledPath = Bundle.main.path(forResource: "inklecate", ofType: nil) {
            print("INKIES DEBUG: Found inklecate in Resources: \(bundledPath)")
            return bundledPath
        }

        // 2. Check App Bundle Contents/MacOS (Backup location)
        if let execPath = Bundle.main.executablePath {
            let binDir = URL(fileURLWithPath: execPath).deletingLastPathComponent()
            let bundleBin = binDir.appendingPathComponent("inklecate").path
            if FileManager.default.fileExists(atPath: bundleBin) {
                print("INKIES DEBUG: Found inklecate in Contents/MacOS: \(bundleBin)")
                return bundleBin
            }
        }

        // 3. Check System Paths
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("INKIES DEBUG: Found inklecate in system path: \(path)")
                return path
            }
        }

        print("INKIES DEBUG: ERROR - inklecate NOT found anywhere")
        return nil
    }

    func compile(_ inkCode: String) async throws -> String {
        // Check cache first
        if let cachedResult = await CompilationCache.shared.getCachedResult(for: inkCode) {
            return cachedResult
        }

        // Cancel any pending compilation
        pendingCompilation?.cancel()

        // Create new compilation task
        let compilationTask = Task<String, Error> {
            return try await performCompilation(inkCode)
        }

        pendingCompilation = compilationTask

        do {
            let result = try await compilationTask.value
            // Cache the successful result
            await CompilationCache.shared.cacheResult(inkCode: inkCode, compiledResult: result)
            return result
        } catch {
            throw error
        }
    }

    private func performCompilation(_ inkCode: String) async throws -> String {
        // 0. Build diagnostics (only once)
        let fm = FileManager.default
        if !hasCheckedResources {
            hasCheckedResources = true
            let dlls = ["ink_compiler.dll", "ink-engine-runtime.dll"]
            print("INKIES DEBUG: --- Compiler Diagnostics ---")
            if let resPath = Bundle.main.resourcePath {
                let resURL = URL(fileURLWithPath: resPath)
                for dll in dlls {
                    let exists = fm.fileExists(atPath: resURL.appendingPathComponent(dll).path)
                    print("INKIES DEBUG: \(dll) exists in Resources: \(exists)")
                }
                let inklecateExists = fm.fileExists(
                    atPath: resURL.appendingPathComponent("inklecate").path)
                print("INKIES DEBUG: inklecate exists: \(inklecateExists)")
                if inklecateExists {
                    let isExec = fm.isExecutableFile(
                        atPath: resURL.appendingPathComponent("inklecate").path)
                    print("INKIES DEBUG: inklecate is executable: \(isExec)")
                }
            }
        }

        // Interrupt any existing process
        if let existing = currentProcess, existing.isRunning {
            existing.terminate()
            print("INKIES DEBUG: Terminated previous compilation process")
        }

        guard let compilerPath = findInklecate() else {
            print("INKIES DEBUG: ERROR - compiler path not found")
            throw NSError(
                domain: "InkCompiler", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "inklecate compiler not found in bundle."])
        }

        // 1. Prepare temporary files
        let tempDir = fm.temporaryDirectory
        let tempInkFile = tempDir.appendingPathComponent("temp.ink")
        let tempJsonFile = tempDir.appendingPathComponent("temp.json")

        do {
            try inkCode.write(to: tempInkFile, atomically: true, encoding: .utf8)
        } catch {
            throw NSError(
                domain: "InkCompiler", code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to write temp file: \(error.localizedDescription)"
                ])
        }

        // 2. Run inklecate process
        let process = Process()
        let compilerURL = URL(fileURLWithPath: compilerPath)
        process.executableURL = compilerURL
        process.arguments = ["-o", tempJsonFile.path, tempInkFile.path]

        // Set working directory to where inklecate is, so it finds DLLs
        process.currentDirectoryURL = compilerURL.deletingLastPathComponent()

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        print("INKIES DEBUG: Starting compilation: \(compilerPath)")

        self.currentProcess = process

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    if process.terminationStatus == 0 {
                        do {
                            let jsonData = try Data(contentsOf: tempJsonFile)
                            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                            continuation.resume(returning: jsonString)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorString =
                            String(data: errorData, encoding: .utf8) ?? "Unknown Error"
                        continuation.resume(
                            throwing: NSError(
                                domain: "InkCompiler", code: Int(process.terminationStatus),
                                userInfo: [NSLocalizedDescriptionKey: errorString]))
                    }

                    // Cleanup temp files
                    try? FileManager.default.removeItem(at: tempInkFile)
                    try? FileManager.default.removeItem(at: tempJsonFile)
                }

                do {
                    try process.run()
                } catch {
                    print(
                        "INKIES DEBUG: ERROR - failed to run process: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
                print("INKIES DEBUG: Compiling task canceled, terminated process")
            }
        }
    }
}
