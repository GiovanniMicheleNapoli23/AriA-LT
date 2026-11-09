//
//  AriaTurnstileView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Captcha Cloudflare Turnstile, lo stesso del form di login della web: better-auth lo vuole per mandare
//  il magic link. `appearance: interaction-only`: di solito conia il token in silenzio, e il riquadro
//  compare solo se Turnstile chiede un tocco. La pagina è caricata con l'origine della web app
//  (baseURL), perché la chiave accetta solo i domini della web. Per un token nuovo: cambia `.id(...)`.
//

import SwiftUI
import WebKit

struct AriaTurnstileView: UIViewRepresentable {
    let siteKey: String
    let origin: URL
    let onEvent: (AriaTurnstileEvent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(origin: origin, onEvent: onEvent) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Niente cookie o cache che restino fra un login e l'altro.
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: Coordinator.handler)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(html, baseURL: origin)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.handler)
    }

    private var html: String {
        """
        <!doctype html>
        <html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;background:transparent;overflow:hidden}</style>
        <script>
        function send(type, value) {
          window.webkit.messageHandlers.\(Coordinator.handler).postMessage({ type: type, value: value || "" })
        }
        function ariaRender() {
          turnstile.render("#widget", {
            sitekey: "\(siteKey)",
            theme: "light",
            size: "flexible",
            appearance: "interaction-only",
            callback: function (token) { send("token", token) },
            "expired-callback": function () { send("expired") },
            "timeout-callback": function () { send("expired") },
            "error-callback": function () { send("error"); return true },
            "before-interactive-callback": function () { send("interactive") },
            "after-interactive-callback": function () { send("done") }
          })
        }
        </script>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=ariaRender"
                async defer onerror="send('error')"></script>
        </head><body><div id="widget"></div></body></html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let handler = "turnstile"
        let origin: URL
        var onEvent: (AriaTurnstileEvent) -> Void

        init(origin: URL, onEvent: @escaping (AriaTurnstileEvent) -> Void) {
            self.origin = origin
            self.onEvent = onEvent
        }

        /// La pagina principale resta quella caricata da `loadHTMLString`: un link o un redirect nel widget
        /// non la porta altrove. I riquadri interni (l'iframe di Cloudflare) caricano liberamente.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.targetFrame?.isMainFrame ?? true else { return .allow }
            let isInitialLoad = navigationAction.navigationType == .other
                && navigationAction.request.url?.host() == origin.host()
            return isInitialLoad ? .allow : .cancel
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            // Solo la nostra pagina, non un riquadro di altri, può mandare il token.
            guard message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.host == origin.host(),
                  let body = message.body as? [String: String] else { return }
            switch body["type"] {
            case "token":
                if let token = body["value"], !token.isEmpty { onEvent(.token(token)) } else { onEvent(.failed) }
            case "expired": onEvent(.expired)
            case "error": onEvent(.failed)
            case "interactive": onEvent(.needsInteraction(true))
            case "done": onEvent(.needsInteraction(false))
            default: break
            }
        }
    }
}
