//
//  AriaTurnstileView.swift
//  AriaLite
//
//  Captcha Cloudflare Turnstile, lo stesso del form di login della web.
//  La pagina è caricata con l'origine della web app (baseURL), perché la chiave
//  accetta solo i domini della web. Per rigenerare il token: cambia `.id(...)`.
//

import SwiftUI
import WebKit

struct AriaTurnstileView: UIViewRepresentable {
    let siteKey: String
    let origin: URL
    /// Token pronto (valido 5', usabile una volta), oppure nil se scaduto o in errore.
    let onToken: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: Coordinator.handler)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(html, baseURL: origin)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onToken = onToken
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
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=ariaRender" async defer></script>
        </head><body><div id="widget"></div><script>
        function send(type, value) {
          window.webkit.messageHandlers.\(Coordinator.handler).postMessage({ type: type, value: value || "" })
        }
        function ariaRender() {
          turnstile.render("#widget", {
            sitekey: "\(siteKey)",
            theme: "auto",
            size: "flexible",
            callback: function (token) { send("token", token) },
            "expired-callback": function () { send("expired") },
            "error-callback": function () { send("error"); return true }
          })
        }
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        static let handler = "turnstile"
        var onToken: (String?) -> Void

        init(onToken: @escaping (String?) -> Void) {
            self.onToken = onToken
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: String] else { return }
            onToken(body["type"] == "token" ? body["value"] : nil)
        }
    }
}
