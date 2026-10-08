//
//  AriaAuth.swift
//  AriaLite
//
//  Accesso in due passi, su due host distinti:
//
//  • Host di accesso (solo autenticazione):
//      POST /api/auth/sign-in/username  {"username", "password"} → l'header `set-auth-token`
//           è la sessione, valida 7 giorni.
//      GET  /api/aria/token             Bearer <sessione> → {"token": "<JWT>"}, valido 15'.
//      POST /api/auth/sign-out          Bearer <sessione>.
//    Nient'altro esiste su quell'host: ogni altra rotta risponde 404.
//  • Host API (api.ariaplt.com): tutti i dati, con Bearer <JWT> e Company-Id (AriaAPIClient).
//
//  Accesso alternativo, come la web app (magic link, better-auth): l'app chiede il link via email
//  (POST /api/auth/sign-in/magic-link sulla web, con captcha Turnstile), l'utente incolla il link,
//  l'app lo apre e tiene il cookie di sessione della web (7 gg) nel Keychain; con quel cookie
//  GET /api/aria/token sulla web dà il JWT, esattamente come il browser. È un utente della web,
//  non un utente mobile: niente host dei lavori, resta tutto su api.ariaplt.com.
//
//  Mai cookie verso l'host di accesso: solo l'header Authorization. (I cookie della web si gestiscono
//  a mano, mai in un cookie storage condiviso.) Il JWT resta in memoria
//  e si rinnova 13' dopo il conio (orologio monotono: l'ora del telefono può essere sbagliata),
//  un rinnovo alla volta. 401 sul rinnovo = sessione finita, si rifà il login.
//
//  L'host di accesso è un tunnel temporaneo: quando è spento risponde la pagina d'errore
//  di ngrok, che non va scambiata per credenziali sbagliate.
//
//  Link dell'app (design note "Signing in to the Aria mobile app with an email link"):
//      POST /api/mobile/auth/start     {email, codeChallenge, locale} → email con
//           https://app.ariaplt.com/m/sign-in?token=…, che iOS apre nell'app (Universal Link).
//      POST /api/mobile/auth/exchange  {token, codeVerifier} → {sessionToken, user}: sessione della web
//           come Bearer (plugin `bearer` di better-auth), niente cookie.
//    Il `code_verifier` resta nel Keychain di questo telefono: un link inoltrato o aperto altrove non vale.
//    Finché la web non ha queste rotte si ripiega sul link della web, da incollare. (Vercel risponde
//    alle rotte che non esistono con la pagina "not found" di Next e lo stato 200, non 404.)
//
//  La sessione salvata (7 gg) è protetta da Face ID nel Keychain: all'avvio `unlock` la legge una volta
//  e da lì resta in memoria; nessuna altra lettura chiede Face ID.
//
//  In DEBUG si può anche incollare un access token preso dalla web (GET /api/aria/token).
//

import CryptoKit
import Foundation
import LocalAuthentication

/// L'utente mobile restituito dal login con username (`user` della risposta).
/// `email` non c'è apposta: per gli utenti mobili è un segnaposto da non mostrare.
nonisolated struct AriaMobileAccount: Codable, Sendable, Equatable {
    let id: String
    let name: String
    /// Login completo, `{slug azienda}.{parte locale}` (es. `acme.mario.rossi`).
    let username: String
    let displayUsername: String?
}

/// L'utente della web che ha fatto il login con il magic link (`user` di GET /api/auth/get-session).
nonisolated struct AriaWebAccount: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let email: String
}

/// Un link di accesso riconosciuto, toccato nell'email o incollato.
nonisolated enum AriaSignInLink: Sendable, Equatable {
    /// Link della web (`/api/auth/magic-link/verify?token=…`): si apre come il browser, il cookie arriva sul 302.
    case web(URL)
    /// Link dell'app (`/m/sign-in?token=…`, o `aria://sign-in?token=…` dal pulsante della pagina web):
    /// il token si scambia insieme al verifier di questo telefono.
    case app(token: String)
}

/// Che link ha mandato il server: decide cosa dire all'utente mentre aspetta l'email.
nonisolated enum AriaLinkDelivery: String, Sendable {
    /// Link dell'app: basta toccarlo nell'email su questo telefono.
    case app
    /// Link della web: la web non ha ancora le rotte dell'app, il link si incolla.
    case web
}

actor AriaAuth {
    private nonisolated enum Keys {
        /// Token di sessione (`set-auth-token`), mandato come Bearer all'host di accesso.
        static let session = "aria.mobile_session"
        static let devAccess = "aria.dev_access_token"
        /// Cookie di sessione better-auth del login con magic link, salvato come "nome=valore".
        static let webSession = "aria.web_session"
        /// Token di sessione della web dallo scambio del link dell'app, mandato come Bearer alla web.
        static let linkSession = "aria.link_session"
        /// `code_verifier` dell'ultimo link chiesto da questo telefono (si scambia insieme al token).
        static let linkVerifier = "aria.link_verifier"
        /// Le sessioni di 7 giorni: quelle che Face ID protegge.
        static let sessions = [session, webSession, linkSession]
    }

    /// La sessione aperta: letta dal Keychain una volta, poi tenuta in memoria.
    private nonisolated enum Credential: Sendable {
        /// Utente mobile (username): Bearer verso l'host di accesso.
        case mobile(String)
        /// Utente della web, link incollato: cookie better-auth verso la web.
        case webCookie(String)
        /// Utente della web, link aperto nell'app: Bearer verso la web.
        case webBearer(String)

        var key: String {
            switch self {
            case .mobile: Keys.session
            case .webCookie: Keys.webSession
            case .webBearer: Keys.linkSession
            }
        }

        var value: String {
            switch self {
            case .mobile(let value), .webCookie(let value), .webBearer(let value): value
            }
        }

        /// Stessa sessione con un valore nuovo (il server la riemette quando la proroga).
        func renewed(_ value: String) -> Credential {
            switch self {
            case .mobile: .mobile(value)
            case .webCookie: .webCookie(value)
            case .webBearer: .webBearer(value)
            }
        }
    }

    private nonisolated struct ExchangeResponse: Decodable, Sendable {
        let sessionToken: String
        let user: AriaWebAccount?
    }

    private nonisolated struct TokenResponse: Decodable, Sendable {
        let token: String
    }

    private nonisolated struct UsernameSignInResponse: Decodable, Sendable {
        let user: AriaMobileAccount
    }

    /// `callbackURL` dei link chiesti dall'app: il file apple-app-site-association della web riconosce
    /// da qui (`*aria-ios*`) i link da aprire nell'app, così quelli chiesti dal sito restano a Safari.
    /// Aperto in un browser (es. sul computer) porta alla home della web, come "/".
    private static let appCallbackPath = "/?from=aria-ios"

    /// L'host ne conia uno ogni 15': si rinnova un po' prima.
    private static let mintedTokenLifetime: Duration = .seconds(13 * 60)

    private let config: AriaConfig
    private let session: URLSession
    private var credential: Credential?
    private var accessToken: String?
    private var validUntil = ContinuousClock.now
    private var refreshTask: Task<String, any Error>?

    init(config: AriaConfig) {
        self.config = config
        // Niente cookie verso l'host di accesso: vale solo l'header Authorization.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        session = URLSession(configuration: configuration)
    }

    /// Controlli sul Keychain che non leggono il valore: non chiedono mai Face ID.
    nonisolated var hasStoredSession: Bool {
        hasStoredLogin || AriaKeychain.exists(Keys.devAccess)
    }

    /// Una sessione di 7 giorni salvata (non il token di sviluppo): all'avvio va aperta con Face ID.
    nonisolated var hasStoredLogin: Bool {
        Keys.sessions.contains(where: AriaKeychain.exists)
    }

    /// Sessione di un utente mobile: una sola azienda, disabilitabile dall'admin a sessione aperta.
    nonisolated var isMobileSession: Bool {
        AriaKeychain.exists(Keys.session)
    }

    // MARK: Face ID

    /// Face ID (o il codice del telefono), poi la sessione dal Keychain in memoria.
    /// `false`: non c'è più nessuna sessione salvata. Annullare lancia un LAError.
    func unlock(reason: String) async throws -> Bool {
        let context = try await AriaBiometrics.authenticate(reason: reason)
        if credential != nil { return true }
        guard let found = loadCredential(context: context) else { return false }
        // Una sessione salvata prima di Face ID era in chiaro: da ora è protetta.
        store(found)
        AriaAuthTrace.step("unlock.ok", "")
        return true
    }

    // MARK: Login

    /// Passo 1. `username` è il login completo (`acme.mario.rossi`); il server lo mette in minuscolo.
    /// `rememberMe` non si manda: `false` accorcerebbe la sessione a un giorno.
    func signIn(username: String, password: String) async throws -> AriaMobileAccount {
        var req = request("api/auth/sign-in/username", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["username": username, "password": password])
        AriaAuthTrace.step("sign-in.request",
                           "\(req.url?.absoluteString ?? "-") username=\(username) password=\(password.count) caratteri")

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            // Rete, DNS, TLS: la richiesta non è mai arrivata al server.
            AriaAuthTrace.failure("sign-in.network", error)
            throw error
        }
        AriaAuthTrace.response("sign-in.response", response, data)
        do { try Self.checkSignIn(response, data) }
        catch {
            AriaAuthTrace.failure("sign-in.rejected", error)
            throw error
        }

        // Il `token` del body è la forma non firmata: vale solo l'header.
        guard let token = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "set-auth-token"),
              !token.isEmpty else {
            AriaAuthTrace.step("sign-in.noSession", "manca l'header set-auth-token")
            throw AriaError.stream(String(localized: "Sign-in did not return a session. Try again."))
        }
        let account: AriaMobileAccount
        do { account = try JSONDecoder().decode(UsernameSignInResponse.self, from: data).user }
        catch {
            AriaAuthTrace.failure("sign-in.decode", error)
            throw AriaError.decoding("sign-in: \(error)")
        }
        AriaAuthTrace.step("sign-in.ok", "username=\(account.username) id=\(account.id)")

        store(.mobile(token))
        resetAccessToken()
        _ = try await refresh()
        return account
    }

    // MARK: Magic link (web)

    /// Chiede il link dell'app, legato a questo telefono dal verifier. Se la web non ha ancora
    /// la rotta chiede il link della web, come il form della web.
    func sendMagicLink(email: String, captcha: String, locale: String) async throws -> AriaLinkDelivery {
        let verifier = Self.randomVerifier()
        // Prima della richiesta: iOS può chiudere l'app mentre l'utente è in Mail.
        AriaKeychain.set(verifier, for: Keys.linkVerifier)
        var req = webRequest("api/mobile/auth/start", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Al posto di App Attest per ora lo stesso captcha Turnstile della web: la rotta lo può
        // verificare con siteverify, come fa il plugin captcha.
        req.setValue(captcha, forHTTPHeaderField: "x-captcha-response")
        req.httpBody = try JSONEncoder().encode([
            "email": email, "codeChallenge": Self.challenge(for: verifier), "locale": locale,
        ])
        AriaAuthTrace.step("link.start", req.url?.absoluteString ?? "-")
        let (data, response) = try await session.data(for: req)
        AriaAuthTrace.response("link.start.response", response, data)
        guard !Self.isMissingRoute(response) else {
            // Nessuna rotta, quindi il captcha non è stato usato: vale ancora per il link della web.
            AriaKeychain.delete(Keys.linkVerifier)
            try await sendWebMagicLink(email: email, captcha: captcha, locale: locale)
            return .web
        }
        try Self.checkMagicLink(response, data)
        return .app
    }

    /// Come il form della web: better-auth manda l'email col link (valido 10', usabile una volta).
    private func sendWebMagicLink(email: String, captcha: String, locale: String) async throws {
        var req = webRequest("api/auth/sign-in/magic-link", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(captcha, forHTTPHeaderField: "x-captcha-response")
        req.setValue(locale, forHTTPHeaderField: "x-aria-locale")
        req.httpBody = try JSONEncoder().encode(["email": email, "callbackURL": Self.appCallbackPath])
        let (data, response) = try await session.data(for: req)
        try Self.checkMagicLink(response, data)
    }

    /// Estrae il link di accesso da un testo incollato. Solo link della nostra web app.
    nonisolated func magicLink(in text: String) -> AriaSignInLink? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.matches(in: text, range: range).lazy
            .compactMap(\.url)
            .compactMap(signInLink(from:))
            .first
    }

    /// Il link di accesso in un URL aperto dal sistema (Universal Link o schema `aria://`) o incollato.
    nonisolated func signInLink(from url: URL) -> AriaSignInLink? {
        let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "token" }?.value
        guard let token, !token.isEmpty else { return nil }
        if url.scheme == "aria" { return url.host() == "sign-in" ? .app(token: token) : nil }
        guard url.host() == config.webBaseURL.host() else { return nil }
        if url.path() == "/m/sign-in" { return .app(token: token) }
        if url.path().hasSuffix("/magic-link/verify") { return .web(url) }
        return nil
    }

    /// Completa l'accesso. Restituisce l'utente quando il server lo manda già (scambio del link dell'app).
    func completeSignIn(with link: AriaSignInLink) async throws -> AriaWebAccount? {
        switch link {
        case .web(let url):
            try await openWebLink(url)
            return nil
        case .app(let token):
            return try await exchange(token: token)
        }
    }

    /// Scambia il token del link dell'app col verifier salvato quando l'utente l'ha chiesto.
    private func exchange(token: String) async throws -> AriaWebAccount? {
        guard let verifier = AriaKeychain.get(Keys.linkVerifier) else {
            AriaAuthTrace.step("link.exchange.noVerifier", "")
            throw AriaError.stream(String(localized: "This link was requested on another device. Send a new one from here."))
        }
        var req = webRequest("api/mobile/auth/exchange", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["token": token, "codeVerifier": verifier])
        AriaAuthTrace.step("link.exchange", req.url?.absoluteString ?? "-")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            // Rete: di solito il token non è stato usato, si può toccare di nuovo il link.
            AriaAuthTrace.failure("link.exchange.network", error)
            throw error
        }
        AriaAuthTrace.response("link.exchange.response", response, data)
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            let code = (try? JSONDecoder().decode(AriaJSON.self, from: data))?["error"]?.stringValue
            if code == "LINK_NOT_FOR_THIS_DEVICE" {
                // Un link vecchio o di un altro telefono: il verifier può servire al link più recente.
                throw AriaError.stream(String(localized: "This link is not the latest one sent to this device. Open the most recent email, or send a new link."))
            }
            AriaKeychain.delete(Keys.linkVerifier)
            throw AriaError.stream(String(localized: "This sign-in link has expired or has already been used. Request a new one."))
        }
        try Self.checkMagicLink(response, data)
        let exchanged: ExchangeResponse
        do { exchanged = try JSONDecoder().decode(ExchangeResponse.self, from: data) }
        catch {
            AriaAuthTrace.failure("link.exchange.decode", error)
            throw AriaError.decoding("exchange: \(error)")
        }
        AriaKeychain.delete(Keys.linkVerifier)
        store(.webBearer(exchanged.sessionToken))
        resetAccessToken()
        _ = try await refresh()
        AriaAuthTrace.step("link.exchange.ok", "")
        return exchanged.user
    }

    /// Apre il link come farebbe il browser, senza seguire il redirect: il 302 porta il cookie di sessione.
    private func openWebLink(_ link: URL) async throws {
        var req = URLRequest(url: link)
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        let (data, response) = try await session.data(for: req, delegate: NoRedirect())
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }

        let location = http.value(forHTTPHeaderField: "Location").flatMap { URL(string: $0, relativeTo: link) }
        if let code = location.flatMap(Self.errorCode(in:)) {
            throw AriaError.stream(Self.message(forLinkError: code))
        }
        if !(300..<400).contains(http.statusCode) { try Self.checkMagicLink(response, data) }

        guard let cookie = Self.sessionCookie(in: http, for: link) else {
            throw AriaError.stream(String(localized: "The sign-in link did not start a session. Request a new one."))
        }
        store(.webCookie(cookie))
        resetAccessToken()
        _ = try await refresh()
    }

    /// Chi è l'utente della sessione web (nome ed email), per mostrarlo nell'app. `nil` se la web non risponde:
    /// il login è comunque valido.
    func fetchWebAccount() async -> AriaWebAccount? {
        guard let credential = loadCredential(context: nil) else { return nil }
        if case .mobile = credential { return nil }
        let req = webRequest("api/auth/get-session", method: "GET", credential: credential)
        guard let (data, response) = try? await session.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let user = (try? JSONDecoder().decode(AriaJSON.self, from: data))?["user"],
              let id = user["id"]?.stringValue, let email = user["email"]?.stringValue else { return nil }
        return AriaWebAccount(id: id, name: user["name"]?.stringValue ?? "", email: email)
    }

    /// Solo sviluppo: usa un access token già emesso (niente rinnovo, vale fino a `exp`).
    func useDeveloperToken(_ token: String) throws {
        guard let exp = Self.expiry(ofJWT: token), exp.timeIntervalSinceNow > 0 else {
            throw AriaError.stream(String(localized: "The token is not a valid JWT or has expired."))
        }
        clear()
        AriaKeychain.set(token, for: Keys.devAccess)
        useAccessToken(token, validFor: .seconds(exp.timeIntervalSinceNow))
    }

    /// Chiude la sessione di questo dispositivo (gli altri restano collegati).
    /// Con la sessione ancora chiusa da Face ID la si dimentica solo qui: sul server scade da sola.
    func signOut() async {
        switch loadCredential(context: nil) {
        case .mobile(let token):
            let req = request("api/auth/sign-out", method: "POST", bearer: token)
            _ = try? await session.data(for: req)
        case let credential?:
            var req = webRequest("api/auth/sign-out", method: "POST", credential: credential)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data("{}".utf8)
            _ = try? await session.data(for: req)
        case nil:
            break
        }
        clear()
    }

    /// Dimentica la sessione senza chiamare il server: la sessione è già finita
    /// (utente mobile disabilitato, membership non più attiva).
    func discardSession() {
        clear()
    }

    // MARK: Token

    func validAccessToken() async throws -> String {
        if let token = accessToken, ContinuousClock.now < validUntil { return token }
        if let dev = AriaKeychain.get(Keys.devAccess) {
            guard let exp = Self.expiry(ofJWT: dev), exp.timeIntervalSinceNow > 0 else {
                clear()
                throw AriaError.signedOut
            }
            useAccessToken(dev, validFor: .seconds(exp.timeIntervalSinceNow))
            return dev
        }
        return try await refresh()
    }

    /// Chiamato dopo un 401 dell'API: il prossimo validAccessToken() conia un JWT nuovo.
    func invalidate() {
        // Un token incollato non si può rinnovare: dopo un 401 è finito.
        if AriaKeychain.get(Keys.devAccess) != nil { clear() }
        resetAccessToken()
    }

    private func refresh() async throws -> String {
        if let running = refreshTask { return try await running.value }
        let task = Task(name: "aria.auth.refresh") { try await self.performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    /// Passo 2: sessione (7 gg) → JWT per l'host API (15').
    private func performRefresh() async throws -> String {
        // Sessione della web (cookie o Bearer) oppure di un utente mobile (Bearer): una sola.
        guard let credential = loadCredential(context: nil) else {
            if hasStoredLogin {
                // Salvata ma protetta da Face ID: l'app la apre con `unlock`, qui non si chiede nulla.
                AriaAuthTrace.step("token.locked", "sessione da aprire con Face ID")
                throw AriaError.locked
            }
            AriaAuthTrace.step("token.noSession", "niente in Keychain: si torna al login")
            throw AriaError.signedOut
        }
        let req = switch credential {
        case .mobile(let token): request("api/aria/token", method: "GET", bearer: token)
        case .webCookie, .webBearer: webRequest("api/aria/token", method: "GET", credential: credential)
        }
        AriaAuthTrace.step("token.request", req.url?.absoluteString ?? "-")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            AriaAuthTrace.failure("token.network", error)
            throw error
        }
        AriaAuthTrace.response("token.response", response, data)
        // Tunnel spento: la sessione è ancora buona, non si slogga. (Solo il tunnel: la web non è ngrok.)
        if case .mobile = credential, let offline = AriaHTTP.tunnelError(response) {
            AriaAuthTrace.step("token.hostOffline", "")
            throw offline
        }
        do {
            try AriaHTTP.check(response, data)
        } catch AriaError.http(let status, _) where status == 401 || status == 403 {
            // 401/403 significano "sessione finita" (scaduta, utente disabilitato, password
            // reimpostata, terzo dispositivo che ha scalzato questo): si rifà il login.
            AriaAuthTrace.step("token.sessionEnded", "status=\(status): sessione cancellata dal Keychain")
            clear()
            throw AriaError.signedOut
        }
        // Il server può riemettere la sessione quando la proroga.
        if let http = response as? HTTPURLResponse {
            let renewed = if case .webCookie = credential {
                Self.sessionCookie(in: http, for: req.url!)
            } else {
                http.value(forHTTPHeaderField: "set-auth-token").flatMap { $0.isEmpty ? nil : $0 }
            }
            if let renewed, renewed != credential.value { store(credential.renewed(renewed)) }
        }
        // `companyId` della risposta si ignora: l'azienda la sceglie AriaBackend con GET /v1/companies.
        let token = try JSONDecoder().decode(TokenResponse.self, from: data).token
        guard let exp = Self.expiry(ofJWT: token) else {
            AriaAuthTrace.step("token.invalidJWT", "la risposta non è un JWT")
            throw AriaError.decoding("token")
        }
        AriaAuthTrace.step("token.ok", "scade fra \(Int(exp.timeIntervalSinceNow))s")
        useAccessToken(token, validFor: Self.mintedTokenLifetime)
        return token
    }

    private func useAccessToken(_ token: String, validFor lifetime: Duration) {
        accessToken = token
        validUntil = .now + lifetime
    }

    private func resetAccessToken() {
        accessToken = nil
        validUntil = .now
    }

    /// Legge la sessione salvata, se non è già in memoria. Senza `context` (autenticato da Face ID)
    /// una sessione protetta resta chiusa: non si chiede mai nulla all'utente da qui.
    private func loadCredential(context: LAContext?) -> Credential? {
        if let credential { return credential }
        credential = AriaKeychain.get(Keys.webSession, context: context).map(Credential.webCookie)
            ?? AriaKeychain.get(Keys.linkSession, context: context).map(Credential.webBearer)
            ?? AriaKeychain.get(Keys.session, context: context).map(Credential.mobile)
        return credential
    }

    /// Salva la sessione (protetta da Face ID se il telefono ha un codice) al posto di ogni altra.
    private func store(_ new: Credential) {
        for key in Keys.sessions + [Keys.devAccess] where key != new.key { AriaKeychain.delete(key) }
        AriaKeychain.set(new.value, for: new.key, protected: AriaBiometrics.isAvailable)
        credential = new
    }

    private func clear() {
        resetAccessToken()
        credential = nil
        for key in Keys.sessions + [Keys.devAccess] { AriaKeychain.delete(key) }
    }

    /// Richiesta alla web app: better-auth controlla l'Origin delle POST. La sessione va a mano,
    /// come cookie (link incollato) o come Bearer (link dell'app): mai un cookie storage condiviso.
    private func webRequest(_ path: String, method: String, credential: Credential? = nil) -> URLRequest {
        var req = URLRequest(url: config.webBaseURL.appending(path: path))
        req.httpMethod = method
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        req.setValue(Self.origin(of: config.webBaseURL), forHTTPHeaderField: "Origin")
        switch credential {
        case .webCookie(let cookie): req.setValue(cookie, forHTTPHeaderField: "Cookie")
        case .webBearer(let token), .mobile(let token): req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case nil: break
        }
        return req
    }

    private func request(_ path: String, method: String, bearer: String? = nil) -> URLRequest {
        var req = URLRequest(url: config.authBaseURL.appending(path: path))
        req.httpMethod = method
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        // Per gli utenti mobili è il nome del dispositivo che l'admin vede fra le sessioni.
        req.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        // Senza questo ngrok può rispondere la sua pagina di avviso al posto dell'API.
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        return req
    }

    // MARK: PKCE

    /// 32 byte casuali in base64url: il `code_verifier` del link.
    private static func randomVerifier() -> String {
        base64URL(Data(SymmetricKey(size: .bits256).withUnsafeBytes(Array.init)))
    }

    /// `base64url(SHA-256(verifier))`, senza padding: la web lo calcola uguale.
    private static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: Parsing

    /// better-auth limita invio e verifica dei link a 5 richieste al minuto.
    private static func checkMagicLink(_ response: URLResponse, _ data: Data) throws {
        if (response as? HTTPURLResponse)?.statusCode == 429 {
            throw AriaError.stream(String(localized: "Too many attempts. Wait a minute and try again."))
        }
        try AriaHTTP.check(response, data)
    }

    /// La web non ha la rotta: 404, oppure la pagina "not found" di Next (HTML, su Vercel con stato 200).
    /// Le rotte di autenticazione rispondono sempre JSON.
    private static func isMissingRoute(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 404
            || http.value(forHTTPHeaderField: "x-matched-path") == "/_not-found"
            || http.value(forHTTPHeaderField: "Content-Type")?.localizedCaseInsensitiveContains("text/html") == true
    }

    private static func origin(of url: URL) -> String {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host()
        components.port = url.port
        return components.string ?? url.absoluteString
    }

    /// `better-auth.session_token`, o `__Secure-better-auth.session_token` su https.
    private static func sessionCookie(in response: HTTPURLResponse, for url: URL) -> String? {
        // In HTTP/2 l'header arriva come "set-cookie" e HTTPCookie cerca solo "Set-Cookie":
        // value(forHTTPHeaderField:) invece non distingue maiuscole e minuscole.
        guard let header = response.value(forHTTPHeaderField: "Set-Cookie") else { return nil }
        return HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": header], for: url)
            .first { $0.name.hasSuffix("better-auth.session_token") && !$0.value.isEmpty }
            .map { "\($0.name)=\($0.value)" }
    }

    private static func errorCode(in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first { $0.name == "error" }?.value
    }

    private static func message(forLinkError code: String) -> String {
        switch code {
        case "EXPIRED_TOKEN":
            String(localized: "This sign-in link has expired. Request a new one.")
        case "INVALID_TOKEN", "ATTEMPTS_EXCEEDED":
            String(localized: "This sign-in link has already been used or is not valid. Request a new one.")
        default:
            String(localized: "Sign-in failed (\(code)). Request a new link.")
        }
    }

    /// Errori del login con username: si decide sul codice, non sul testo.
    private static func checkSignIn(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        if let offline = AriaHTTP.tunnelError(response) { throw offline }
        let code = (try? JSONDecoder().decode(AriaJSON.self, from: data))?["code"]?.stringValue
        switch http.statusCode {
        case 401:
            // Stessa risposta per username e password sbagliati.
            throw AriaError.invalidCredentials
        case 404:
            // Rotta assente sull'host di accesso: le credenziali non sono state verificate.
            throw AriaError.usernameSignInUnavailable
        case 403 where code == "ACCOUNT_DISABLED":
            throw AriaError.stream(String(localized: "This account is disabled. Contact your company administrator."))
        case 429:
            // 5 tentativi al minuto per indirizzo IP.
            if let seconds = http.value(forHTTPHeaderField: "X-Retry-After").flatMap(Int.init), seconds > 0 {
                throw AriaError.stream(String(localized: "Too many attempts. Try again in \(seconds) seconds."))
            }
            throw AriaError.stream(String(localized: "Too many attempts. Wait a minute and try again."))
        default:
            try AriaHTTP.check(response, data)
        }
    }

    /// Legge `exp` dal payload del JWT (senza verificare la firma: la verifica è del server).
    private static func expiry(ofJWT token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONDecoder().decode(AriaJSON.self, from: data),
              case .number(let exp) = payload["exp"] else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}

/// Ferma i redirect: il cookie di sessione arriva sulla risposta 302 del link.
private nonisolated final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
