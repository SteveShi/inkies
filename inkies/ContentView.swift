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
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AddItem"))) { _ in
                addItem()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SaveProject"))) {
                _ in
                try? modelContext.save()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SearchItems"))) {
                _ in
                withAnimation {
                    isSearchMode = true
                    isSearchFieldFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GotoAnything"))) {
                _ in
                withAnimation {
                    isSearchMode = true
                    isSearchFieldFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NextIssue"))) { _ in
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
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowWordCount"))) {
                _ in
                if let item = selection {
                    wordCountStats = calculateStats(for: item.content)
                    showingWordCount = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("InsertSnippet"))) {
                notification in
                if let snippet = notification.object as? String, let item = selection {
                    item.content += snippet
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowWhatsNew"))) {
                _ in
                manualWhatsNew = WhatsNew(
                    version: "0.5.0",
                    title: "What's New in Inkies",
                    features: [
                        .init(
                            image: .init(systemName: "square.and.arrow.up"),
                            title: "Export Options",
                            subtitle: "Export your stories to JSON or Web (HTML)."
                        ),
                        .init(
                            image: .init(systemName: "pencil"),
                            title: "Syntax Highlighting",
                            subtitle: "Improved editor experience."
                        ),
                    ]
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
            .alert(L10n.exportFailed, isPresented: $showingExportError) {
                Button("OK") {}
            } message: {
                Text(exportErrorMessage)
            }
            .alert(L10n.wordCountTitle, isPresented: $showingWordCount) {
                Button(L10n.ok) {}
            } message: {
                Text(
                    """
                    \(L10n.words): \(wordCountStats.words)
                    \(L10n.characters): \(wordCountStats.characters)
                    \(L10n.lines): \(wordCountStats.lines)
                    \(L10n.knots): \(wordCountStats.knots)
                    """)
            }
            .alert(L10n.watchExpressionTitle, isPresented: $showingWatchExpression) {
                TextField(L10n.watchExpressionPrompt, text: $watchExpression)
                Button(L10n.ok) {
                    // In full implementation, this would add to a watch list
                    watchExpression = ""
                }
                Button(L10n.cancel, role: .cancel) {
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
                            Label(L10n.addItem, systemImage: "plus")
                        }
                    }
                }
                .alert(L10n.renameTitle, isPresented: $showingRenameAlert) {
                    TextField(L10n.newTitle, text: $renameTitle)
                    Button(L10n.rename) {
                        if let item = itemToRename {
                            item.title = renameTitle
                        }
                    }
                    Button(L10n.cancel, role: .cancel) {}
                }
        } detail: {
            detailView
        }
        .toolbar {
            mainToolbar
        }
    }


    // MARK: - Subviews

    @ViewBuilder
    private var sidebarView: some View {
        List(selection: $selection) {
            ForEach(filteredItems) { item in
                NavigationLink(value: item) {
                    Text(item.title.isEmpty ? L10n.untitled : item.title)
                }
                .contextMenu {
                    Button(L10n.rename) {
                        itemToRename = item
                        renameTitle = item.title
                        showingRenameAlert = true
                    }
                    Button(L10n.delete, role: .destructive) {
                        modelContext.delete(item)
                    }
                    Divider()
                    Menu(L10n.exportMenu) {
                        Button(L10n.exportInk) { prepareExportInk(item) }
                        Button(L10n.exportJson) { Task { await prepareExportJson(item) } }
                        Button(L10n.exportWeb) { Task { await prepareExportWeb(item) } }
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
            Text(L10n.selectDoc)
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
                        TextField(L10n.search, text: $searchText)
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

                    Button(L10n.cancel) {
                        withAnimation {
                            isSearchMode = false
                            searchText = ""
                        }
                    }
                } else {
                    if selection != nil {
                        Menu {
                            Button(L10n.exportInk) { prepareExportInk(selection!) }
                            Button(L10n.exportJson) {
                                Task { await prepareExportJson(selection!) }
                            }
                            Button(L10n.exportWeb) {
                                Task { await prepareExportWeb(selection!) }
                            }
                        } label: {
                            Label(L10n.exportMenu, systemImage: "square.and.arrow.up")
                        }
                    }

                    Button(action: {
                        withAnimation {
                            isSearchMode = true
                            isSearchFieldFocused = true
                        }
                    }) {
                        Label(L10n.search, systemImage: "magnifyingglass")
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
            exportErrorMessage = "\(L10n.compilerError)\n\(error.localizedDescription)"
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
            exportErrorMessage = "\(L10n.compilerError)\n\(error.localizedDescription)"
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
            let newItem = Item(timestamp: Date(), title: L10n.newDocument, content: "")
            modelContext.insert(newItem)
            selection = newItem
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
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

struct EditorView: View {
    @Bindable var item: Item
    @State private var previewContent: String = ""
    @State private var lastCompiledContent: String = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            TextEditor(text: $item.content)
                .font(.custom("Menlo", size: 14))
                .scrollContentBackground(.hidden)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            WebView(content: $previewContent, lastCompiledContent: $lastCompiledContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
        }
        .padding(.top)
        .onChange(of: item.content) { oldValue, newValue in
            handleContentChange(newValue)
        }
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func handleContentChange(_ content: String) {
        debounceTask?.cancel()

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            previewContent = ""
            lastCompiledContent = ""
            return
        }
        
        if trimmed.hasPrefix("{") {
            previewContent = content
            lastCompiledContent = content
            return
        }

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 400 * 1_000_000)
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                compileContent(content)
            }
        }
    }

    private func compileContent(_ content: String) {
        Task {
            do {
                let json = try await InkCompiler.shared.compile(content)
                if !Task.isCancelled {
                    await MainActor.run {
                        previewContent = json
                        lastCompiledContent = content
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        previewContent = "COMPILER_ERROR: \(error.localizedDescription)"
                        lastCompiledContent = content
                    }
                }
            }
        }
    }
}

#if os(macOS)
    struct WebView: NSViewRepresentable {
        @Binding var content: String
        @Binding var lastCompiledContent: String

        func makeNSView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator

            // Enable developer tools for Safari debugging
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
            
            // Add message handler for communication
            webView.configuration.userContentController.add(context.coordinator, name: "inkiesBridge")
            
            return webView
        }

        @AppStorage("appTheme") private var appTheme: AppTheme = .light

        func updateNSView(_ nsView: WKWebView, context: Context) {
            if context.coordinator.lastContent != content {
                let html = generateHTML(for: content, theme: appTheme, enableIncrementalUpdate: true)
                nsView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
                context.coordinator.lastContent = content
                context.coordinator.isFirstLoad = false
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
            var parent: WebView
            var lastContent: String = ""
            var isFirstLoad: Bool = true

            init(_ parent: WebView) {
                self.parent = parent
            }

            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                if message.name == "inkiesBridge" {
                    if let body = message.body as? [String: Any],
                       let action = body["action"] as? String {
                        if action == "ready" {
                            self.isFirstLoad = false
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

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator
            
            // Add message handler for communication
            webView.configuration.userContentController.add(context.coordinator, name: "inkiesBridge")
            
            return webView
        }

        @AppStorage("appTheme") private var appTheme: AppTheme = .light

        func updateUIView(_ uiView: WKWebView, context: Context) {
            if context.coordinator.lastContent != content {
                let html = generateHTML(for: content, theme: appTheme, enableIncrementalUpdate: true)
                uiView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
                context.coordinator.lastContent = content
                context.coordinator.isFirstLoad = false
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
            var parent: WebView
            var lastContent: String = ""
            var isFirstLoad: Bool = true

            init(_ parent: WebView) {
                self.parent = parent
            }

            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                if message.name == "inkiesBridge" {
                    if let body = message.body as? [String: Any],
                       let action = body["action"] as? String {
                        if action == "ready" {
                            self.isFirstLoad = false
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
            return
                "<script>/* InkJS included from Bundle (\(content.count) bytes) */\n\(content)</script>"
        } else {
            return
                "<script>console.error('INKIES DEBUG: local ink.min.js found but failed to read');</script>"
        }
    }
    // Fallback to CDN if local file not found (User needs to add it to bundle)
    return
        #"<script src="https://unpkg.com/inkjs/dist/ink.js"></script><script>console.warn('INKIES DEBUG: local ink.min.js NOT found in bundle, using CDN');</script>"#
}

private func generateHTML(for inkContext: String, theme: AppTheme, enableIncrementalUpdate: Bool = false) -> String {
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
                #debug {
                    margin-top: 40px;
                    padding: 10px;
                    background: #fff3cd;
                    color: #856404;
                    border: 1px solid #ffeeba;
                    border-radius: 4px;
                    font-size: 0.85em;
                    font-family: monospace;
                }
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
            
            <div id="debug" style="display:none;">
                <strong>Debug Console:</strong>
                <div id="debug-log"></div>
            </div>

            <script>
                (function() {
                    var storyContent = "\(safeContent)";
                    var story = null;
                    var storyContainer = document.getElementById('story');
                    
                    function log(msg) {
                        var d = document.getElementById('debug');
                        d.style.display = 'block';
                        var l = document.getElementById('debug-log');
                        l.innerHTML += "<div>" + msg + "</div>";
                        console.log(msg);
                    }

                    window.onerror = function(msg, url, line) {
                        log("JS Error: " + msg + " (Line " + line + ")");
                        return false;
                    };

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

                    function loadStory(jsonContent) {
                        try {
                            clearStory();
                            story = new inkjs.Story(jsonContent);
                            continueStory();
                        } catch(jsonErr) {
                            log("JSON Parse/Run Error: " + jsonErr.message);
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
                            var jsonContent = JSON.parse(storyContent);
                            loadStory(jsonContent);
                        } else if (storyContent.startsWith('COMPILER_ERROR:')) {
                            var errorMsg = storyContent.substring('COMPILER_ERROR:'.length);
                            showError(errorMsg);
                        } else {
                            storyContainer.innerHTML = `
                                <p><strong>Raw Ink Code Detected</strong></p>
                                <p>Compiling...</p>
                            `;
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

    // Potential paths for inklecate
    private let possiblePaths = [
        "/opt/homebrew/bin/inklecate",
        "/usr/local/bin/inklecate",
    ]
    
    private var isCompiling = false
    private var pendingCompilation: Task<String, Error>?

    func findInklecate() -> String? {
        // 1. Check App Bundle (Preferred for standalone)
        if let bundledPath = Bundle.main.path(forResource: "inklecate", ofType: nil) {
            return bundledPath
        }

        // 2. Check System Paths
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
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
        guard let compilerPath = findInklecate() else {
            throw NSError(
                domain: "InkCompiler", code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "inklecate compiler not found. Please install manually or drag into Xcode."
                ])
        }

        // 1. Write temp file
        let tempDir = FileManager.default.temporaryDirectory
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
        process.executableURL = URL(fileURLWithPath: compilerPath)
        process.arguments = ["-o", tempJsonFile.path, tempInkFile.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    do {
                        let jsonData = try String(contentsOf: tempJsonFile, encoding: .utf8)
                        continuation.resume(returning: jsonData)
                    } catch {
                        continuation.resume(
                            throwing: NSError(
                                domain: "InkCompiler", code: 502,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Compiler finished but JSON output unreadable."
                                ]))
                    }
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Unknown compiler error"
                    continuation.resume(
                        throwing: NSError(
                            domain: "InkCompiler", code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: output]))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
