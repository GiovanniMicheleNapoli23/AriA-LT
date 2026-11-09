//
//  AdminConnectorConsentFlow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il consenso di un connettore, in un posto solo per la pagina del catalogo e quella del connettore.
//  Per Composio il consenso finisce sulla pagina web /connectors/composio/verify, che si chiude con la
//  sessione della web: il telefono non ce l'ha, quindi l'app intercetta quell'URL e chiude da sé con
//  composio/complete. Per gli altri (Notion, Odoo, OAuth aziendale) il ritorno lo gestisce il backend:
//  si apre il browser e al ritorno si ricarica. Le chiamate all'ambiente SwiftUI restano nella vista.
//

import AuthenticationServices
import Foundation

@MainActor
struct AdminConnectorConsentFlow {
    /// La sessione web della vista (`webAuthenticationSession`): l'URL da aprire, l'host e il percorso su cui finisce.
    typealias Authenticate = @MainActor (_ url: URL, _ host: String, _ path: String) async throws -> URL
    /// L'apertura nel browser (`openURL`).
    typealias Open = @MainActor (URL) -> Void

    /// Come è andato il consenso, per chi lo ha chiesto.
    enum Outcome {
        /// Composio chiuso dall'app: si ricarica e si mostra l'avviso.
        case connected(notice: String)
        /// L'utente ha chiuso la finestra: niente errore, ma si ricarica una volta (la web può aver chiuso lei).
        case cancelled
        /// Aperto nel browser: l'avviso dice di tornare, e al ritorno nell'app si ricarica.
        case browser(notice: String)
        /// `nil`: niente da dire.
        case failed(String?)
    }

    /// La pagina web su cui Composio rimanda dopo il consenso.
    static let verifyPath = "/connectors/composio/verify"

    let backend: AriaBackend

    /// Le dieci card one-click di Composio (toolkits.py del backend): il loro URL è fisso e il server lo salva
    /// comunque, ma una riga senza `mcp_url` resta riconoscibile dal provider.
    static let composioProviders: Set<String> = [
        "gmail-personal", "calendar-personal", "drive-personal", "teams", "outlook",
        "dynamics-crm", "salesforce-crm", "slack-chat", "asana", "hubspot-crm",
    ]

    static func isComposio(provider: String, mcpUrl: String?) -> Bool {
        composioProviders.contains(provider) || isComposio(mcpUrl)
    }

    /// Il server MCP è di Composio (https, composio.dev o un suo sottodominio).
    static func isComposio(_ mcpUrl: String?) -> Bool {
        guard let url = mcpUrl.flatMap({ URL(string: $0) }), url.scheme == "https",
              let host = url.host()?.lowercased() else { return false }
        return host == "composio.dev" || host.hasSuffix(".composio.dev")
    }

    /// Esegue il consenso sull'URL che il server ha dato. `composio`: lo chiude l'app; `fallbackName` è il nome
    /// da dire se Composio non manda l'account. `companyId` è quella dello start: Composio rifiuta una chiusura
    /// sotto un'altra azienda, anche se nel frattempo è cambiata quella attiva.
    func run(authorizeURL: String, companyId: String, composio: Bool, fallbackName: String,
             authenticate: Authenticate, open: Open) async -> Outcome {
        // Solo https con un host: `hasPrefix("http")` lasciava passare http in chiaro e schemi come `httpx:`.
        AriaAuthTrace.step("connector.consent", "composio=\(composio) authorize=\(URL(string: authorizeURL)?.host() ?? "?")")
        guard let url = URL(string: authorizeURL), url.scheme?.lowercased() == "https",
              url.host()?.isEmpty == false else {
            return .failed(AriaError.decoding("authorize_url").localizedDescription)
        }
        // Senza host della web non c'è un ritorno da intercettare: si va dal browser.
        guard composio, let host = backend.webURL.host() else { return browser(url, open) }
        let callback: URL
        do {
            callback = try await authenticate(url, host, Self.verifyPath)
        } catch {
            AriaAuthTrace.step("connector.session.error", String(describing: error))
            if Self.isCancellation(error) { return .cancelled }
            // Il ritorno https non parte finché la web non pubblica l'AASA (o la sessione non si apre):
            // si ripiega sul browser, dove la pagina web chiude con la sessione di chi la ha.
            return browser(url, open)
        }
        return await complete(callback: callback, companyId: companyId, fallbackName: fallbackName)
    }

    private func browser(_ url: URL, _ open: Open) -> Outcome {
        AriaAuthTrace.step("connector.browser", url.host() ?? "?")
        open(url)
        return .browser(notice: String(localized: "Finish signing in in the browser, then come back here. It works only if you're signed in to Aria on the web in that browser."))
    }

    /// Annullato da chi guarda. iOS manda lo stesso `canceledLogin` quando l'app non risulta associata al dominio
    /// del ritorno (webcredentials non ancora verificato): quello non è un annullamento, si va dal browser.
    static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        guard (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin else { return false }
        let reason = (error as NSError).localizedFailureReason ?? ""
        return !reason.contains("webcredentials")
    }

    /// composio/complete con il `session_uri` dell'URL di ritorno. Il `session_uri` è monouso e di chi ha
    /// iniziato: non si registra né si salva da nessuna parte.
    private func complete(callback: URL, companyId: String, fallbackName: String) async -> Outcome {
        let sessionURI = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "session_uri" }?.value
        guard let sessionURI, !sessionURI.isEmpty else {
            return .failed(String(localized: "Couldn't finish the sign-in. Start again."))
        }
        do {
            let done = try await backend.api.call(
                AdminMarketplaceAPI.completeComposio(companyId: companyId, AdminComposioCompleteRequest(sessionUri: sessionURI)))
            if let email = done.accountEmail {
                return .connected(notice: String(localized: "Connected as \(email)"))
            }
            let name = done.displayName ?? fallbackName
            return .connected(notice: String(localized: "\(name) connected"))
        } catch {
            // 410 `consent_expired`, 409 `not_your_consent`/`not_confirmed`, 502 `gateway_rejected`: il messaggio
            // del server dice cosa fare (di solito collegare di nuovo).
            return .failed(AdminMarketplaceFailure.message(for: error, backend: backend))
        }
    }
}
