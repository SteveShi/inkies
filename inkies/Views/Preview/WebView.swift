import SwiftUI
import WebKit
import Combine

class WebViewActionHandler: ObservableObject {
    var webView: WKWebView?
    var isReady = false
    
    func restart() {
        webView?.evaluateJavaScript("window.restartStory()")
    }
    
    func undo() {
        webView?.evaluateJavaScript("window.undoStory()")
    }
    
    func update(json: String) {
        let escaped = json.replacingOccurrences(of: "\\", with: "\\\\")
                         .replacingOccurrences(of: "\"", with: "\\\"")
                         .replacingOccurrences(of: "\n", with: "\\n")
                         .replacingOccurrences(of: "\r", with: "")
        webView?.evaluateJavaScript("window.updateStory(\"\(escaped)\")")
    }
}

#if os(macOS)
struct WebView: NSViewRepresentable {
    @Binding var content: String
    @ObservedObject var actionHandler: WebViewActionHandler

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Enable developer tools for Safari debugging
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Add message handler for communication
        webView.configuration.userContentController.add(
            context.coordinator, name: "inkiesBridge")
        
        actionHandler.webView = webView
        return webView
    }

    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.lastContent != content {
            let html = generateHTML(for: content, theme: appTheme)
            nsView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
            context.coordinator.lastContent = content
        }
        actionHandler.webView = nsView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        var lastContent: String = ""

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
                        parent.actionHandler.isReady = true
                    }
                }
            }
        }
    }
}
#else
struct WebView: UIViewRepresentable {
    @Binding var content: String
    @ObservedObject var actionHandler: WebViewActionHandler

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Add message handler for communication
        webView.configuration.userContentController.add(
            context.coordinator, name: "inkiesBridge")
        
        actionHandler.webView = webView
        return webView
    }

    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.lastContent != content {
            let html = generateHTML(for: content, theme: appTheme)
            uiView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
            context.coordinator.lastContent = content
        }
        actionHandler.webView = uiView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        var lastContent: String = ""

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
                        parent.actionHandler.isReady = true
                    }
                }
            }
        }
    }
}
#endif
