import SafariServices
import SwiftUI
import WebKit

enum WebLoadState: Equatable {
    case loading
    case ready
    case failed(String)
}

/// Tracks only URLs explicitly requested by SwiftUI. Redirect destinations do
/// not replace this value: otherwise a state update after /exchange -> /os
/// would replay the already-consumed one-time exchange URL.
struct InitialNavigationState {
    private(set) var requestedURL: URL?

    mutating func shouldLoad(_ url: URL) -> Bool {
        guard requestedURL != url else { return false }
        requestedURL = url
        return true
    }
}

struct AppWebView: UIViewRepresentable {
    let initialURL: URL
    let allowedHost: String
    let reloadToken: UUID
    let onNavigation: (URL) -> Void
    let onStateChange: (WebLoadState) -> Void
    let onSignOut: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.applicationNameForUserAgent = "TheOne-iOS/1.0"
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.userContentController.add(context.coordinator, name: "theoneNative")
        configuration.userContentController.addUserScript(WKUserScript(
            source: Self.nativeBridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Brand.canvas)
        webView.scrollView.backgroundColor = UIColor(Brand.canvas)
        if context.coordinator.initialNavigation.shouldLoad(initialURL) {
            webView.load(URLRequest(url: initialURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 60))
        }
        context.coordinator.reloadToken = reloadToken
        return webView
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "theoneNative")
        webView.stopLoading()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.reloadToken != reloadToken {
            context.coordinator.reloadToken = reloadToken
            webView.reloadFromOrigin()
        }
        if context.coordinator.initialNavigation.shouldLoad(initialURL) {
            webView.load(URLRequest(url: initialURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 60))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: AppWebView
        var initialNavigation = InitialNavigationState()
        var reloadToken: UUID?

        init(parent: AppWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "theoneNative",
                  message.frameInfo.isMainFrame,
                  message.frameInfo.securityOrigin.host == parent.allowedHost,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            Task { @MainActor in
                switch type {
                case "signOut": parent.onSignOut()
                case "haptic": haptic(String(describing: body["style"] ?? "light"))
                case "share": share(body)
                default: break
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.onStateChange(.loading)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url {
                parent.onNavigation(url)
            }
            parent.onStateChange(.ready)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            parent.onStateChange(.failed(error.localizedDescription))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let internalNavigation = url.host == parent.allowedHost || url.scheme == "about" || url.scheme == "blob"
            if internalNavigation {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                Task { @MainActor in UIApplication.shared.open(url) }
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                Task { @MainActor in UIApplication.shared.open(url) }
            }
            return nil
        }

        @MainActor
        private func haptic(_ style: String) {
            switch style {
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "warning": UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case "error": UINotificationFeedbackGenerator().notificationOccurred(.error)
            case "selection": UISelectionFeedbackGenerator().selectionChanged()
            default: UIImpactFeedbackGenerator(style: style == "heavy" ? .heavy : .light).impactOccurred()
            }
        }

        @MainActor
        private func share(_ body: [String: Any]) {
            var items: [Any] = []
            if let text = body["text"] as? String, !text.isEmpty { items.append(text) }
            if let rawURL = body["url"] as? String,
               let url = URL(string: rawURL),
               ["https", "http"].contains(url.scheme?.lowercased() ?? "") { items.append(url) }
            guard !items.isEmpty,
                  let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                  let presenter = scene.windows.first(where: \.isKeyWindow)?.rootViewController
            else { return }
            let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
            if let popover = controller.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.maxY - 40, width: 1, height: 1)
            }
            presenter.present(controller, animated: true)
        }
    }

    private static let nativeBridgeScript = #"""
    (() => {
      // Available before React hydrates, so the web shell can select its
      // native one-column experience without mistaking mobile Safari for it.
      document.documentElement.dataset.nativePlatform = 'ios';
      const post = (payload) => window.webkit?.messageHandlers?.theoneNative?.postMessage(payload);
      Object.defineProperty(window, 'TheOneNative', {
        configurable: false,
        writable: false,
        value: Object.freeze({
          platform: 'ios',
          version: 1,
          share: (payload = {}) => post({ type: 'share', text: String(payload.text || ''), url: String(payload.url || '') }),
          haptic: (style = 'light') => post({ type: 'haptic', style: String(style) }),
          signOut: () => post({ type: 'signOut' })
        })
      });
      window.dispatchEvent(new CustomEvent('theone:native-ready', { detail: { platform: 'ios', version: 1 } }));
    })();
    """#
}
