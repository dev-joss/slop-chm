import SwiftUI
import WebKit
import CHMKit

/// A wrapper holding the WKWebView so it can be shared between SwiftUI and imperative code.
@MainActor @Observable
final class WebViewStore {
    var webView: WKWebView?
    private var schemeHandler: CHMURLSchemeHandler?

    func setup(chmFile: CHMFile) {
        guard webView == nil else { return }
        let config = WKWebViewConfiguration()
        let handler = CHMURLSchemeHandler(chmFile: chmFile)
        config.setURLSchemeHandler(handler, forURLScheme: "chm-internal")
        schemeHandler = handler

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        webView = wv
    }

    func navigate(to path: String) {
        guard let webView else { return }
        var components = URLComponents()
        components.scheme = "chm-internal"
        components.host = "content"
        // Split off #fragment if present
        if let hashIndex = path.firstIndex(of: "#") {
            components.path = String(path[path.startIndex..<hashIndex])
            components.fragment = String(path[path.index(after: hashIndex)...])
        } else {
            components.path = path
        }
        guard let url = components.url else { return }
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

/// NSViewRepresentable that displays the WKWebView from WebViewStore.
struct WebContentView: NSViewRepresentable {
    let webViewStore: WebViewStore

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        if let webView = webViewStore.webView {
            webView.frame = container.bounds
            webView.autoresizingMask = [.width, .height]
            container.addSubview(webView)
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure web view is in the container
        if let webView = webViewStore.webView, webView.superview !== nsView {
            nsView.subviews.forEach { $0.removeFromSuperview() }
            webView.frame = nsView.bounds
            webView.autoresizingMask = [.width, .height]
            nsView.addSubview(webView)
        }
    }
}
