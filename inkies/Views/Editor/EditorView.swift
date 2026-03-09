import SwiftUI
import WebKit

struct EditorView: View {
    @Bindable var item: Item
    @State private var previewContent: String = ""
    @State private var lastCompiledContent: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var compilationTask: Task<Void, Never>?
    @StateObject private var webViewHandler = WebViewActionHandler()
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @State private var inkIssues: [InkIssue] = []

    var body: some View {
        HStack(spacing: 0) {
            InkTextView(text: $item.content, issues: inkIssues)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            WebView(content: $previewContent, 
                    lastCompiledContent: $lastCompiledContent,
                    actionHandler: webViewHandler)
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
            compilationTask?.cancel()

            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                debounceTask?.cancel()
                compilationTask?.cancel()
                previewContent = ""
                lastCompiledContent = ""
                // Use the handler to force clear if it's already running
                if webViewHandler.isReady {
                    webViewHandler.update(json: "")
                }
                return
            }

            if trimmed.hasPrefix("{") {
                previewContent = newValue
                lastCompiledContent = newValue
                return
            }

            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 100 * 1_000_000)  // 100ms debounce
                if !Task.isCancelled {
                    compileContent(newValue)
                }
            }
        }
        .onAppear {
            print("INKIES DEBUG: EditorView appeared for item: \(item.title)")
            // Initial compilation on appear
            let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("{") {
                compileContent(item.content)
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
        webViewHandler.restart()
    }

    private func undoStory() {
        webViewHandler.undo()
    }

    private func compileContent(_ content: String) {
        compilationTask?.cancel()
        compilationTask = Task {
            do {
                let json = try await InkCompiler.shared.compile(content)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.previewContent = json // Always update state
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
            
            // If success, we also want to clear or update issues (though analyzeIssues is called in catch)
            // Actually, analyzeIssues should be called in both cases if we want warnings too.
            if !Task.isCancelled {
                let issues = await InkCompiler.shared.analyzeIssues(content)
                await MainActor.run {
                    self.inkIssues = issues
                }
            }
        }
    }
}
