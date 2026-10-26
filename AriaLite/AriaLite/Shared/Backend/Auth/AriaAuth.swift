//
//  AriaAuth.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Accesso senza password: un link via email. Due tipi di account, un solo campo email nell'app.
//  Tutto sull'host di accesso (app.ariaplt.com, la web app; i dati stanno su api.ariaplt.com).
//
//  • Operatore mobile (creato dalla web fra i "Mobile Users"):
//      POST /api/auth/mobile/request-link  {"email"} → 202 {} sempre, che l'indirizzo sia
//           di un operatore o no. L'email porta https://<host>/m/sign-in#token=<token>:
//           il token sta nel FRAMMENTO dell'URL, non nella query. Vale una volta, 15 minuti.
//      POST /api/auth/mobile/verify        {"token"} → 200 {"token", "user": {id, name, email}};
//           la sessione è anche nell'header `set-auth-token`.
//           401 INVALID_OR_EXPIRED_LINK · 403 ACCOUNT_DISABLED · 429 con `X-Retry-After`.
//      GET  /api/aria/token                Bearer <sessione> → {"token": "<JWT>"}, valido 15'.
//      POST /api/auth/sign-out             Bearer <sessione>.
//    Una sessione per dispositivo, 2 dispositivi per account: il terzo accesso fa uscire il più
//    vecchio, e il suo prossimo rinnovo del JWT risponde 401.
//
//  • Account della piattaforma (owner, admin, member): il magic link della web (better-auth).
//      POST /api/auth/sign-in/magic-link   {"email", "callbackURL"}, con `x-captcha-response` (Turnstile)
//           e `Origin`. Link valido 10', una volta. 400 MISSING_RESPONSE · 403 VERIFICATION_FAILED · 429.
//      GET  /api/auth/magic-link/verify?token=…&callbackURL=…  → 302 verso callbackURL con il cookie
//           di sessione; un link non valido rimanda con `?error=CODICE`.
//      GET  /api/aria/token                Cookie <sessione> → {"token", "companyId"}, valido 15'.
//      POST /api/auth/sign-out             Cookie, `Origin` e body `{}`.
//    `callbackURL` è `/?from=aria-ios`: l'apple-app-site-association della web apre nell'app solo
//    /api/auth/magic-link/verify con `callbackURL=*aria-ios*`, così il link toccato nell'email torna qui.
//
//  L'app manda le due richieste insieme (AriaBackend.sendSignInLink): solo quella del tipo di account
//  giusto spedisce un'email, e la forma del link che arriva decide come si completa l'accesso.
//
//  Mai un cookie storage: la sessione dell'operatore va come Bearer, il cookie della web a mano
//  nell'header `Cookie`. Il JWT resta in memoria e si rinnova 13' dopo il conio (orologio monotono:
//  l'ora del telefono può essere sbagliata), un rinnovo alla volta. 401 sul rinnovo = sessione finita,
//  si rifà l'accesso.
//
//  Un host che non risponde (502/503/504) non va scambiato per un link sbagliato né per una sessione finita.
//
//  La sessione salvata (dell'uno o dell'altro tipo) è protetta da Face ID nel Keychain: all'avvio
//  `unlock` la legge una volta e da lì resta in memoria; nessuna altra lettura chiede Face ID.
//
//  In DEBUG si può anche incollare un access token (GET /api/aria/token).
//

import Foundation
import LocalAuthentication

/// L'account collegato: l'operatore restituito dalla verifica del link (`user` della risposta),
/// o l'account della web riconosciuto da GET /v1/me.
nonisolated struct AriaMobileAccount: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let email: String
    /// Assente nei profili salvati prima dell'accesso admin: erano tutti operatori.
    var kind: AriaAccountKind = .operator

    init(id: String, name: String, email: String, kind: AriaAccountKind = .operator) {
        self.id = id
        self.name = name
        self.email = email
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, email, kind
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        email = try c.decode(String.self, forKey: .email)
        kind = try c.decodeIfPresent(AriaAccountKind.self, forKey: .kind) ?? .operator
    }
}

/// Un link di accesso riconosciuto, toccato nell'email o incollato. La sua forma decide come si completa.
nonisolated enum AriaSignInLink: Sendable, Equatable {
    /// Link dell'operatore (`/m/sign-in#token=…`, o `aria://sign-in#token=…`): il token si verifica.
    case mobile(token: String)
    /// Magic link della web (`/api/auth/magic-link/verify?token=…`): si apre come il browser,
    /// il cookie di sessione arriva sul 302.
    case web(URL)

    /// Il link dell'operatore con questo token.
    init(token: String) {
        self = .mobile(token: token)
    }

    /// Il token del link dell'operatore; `nil` per il link della web (lo legge la web).
    var token: String? {
        switch self {
        case .mobile(let token): token
        case .web: nil
        }
    }
}

actor AriaAuth {
    private nonisolated enum Keys {
        /// Token di sessione dell'operatore (`set-auth-token`), mandato come Bearer all'host.
        static let session = "aria.mobile_session"
        /// Cookie di sessione better-auth dell'account della piattaforma, salvato come "nome=valore".
        /// Chiave nuova: `aria.web_session` delle versioni precedenti si cancella a ogni avvio.
        static let webSession = "aria.web_session.v2"
        static let devAccess = "aria.dev_access_token"
        /// Le sessioni salvate: quelle che Face ID protegge.
        static let sessions = [session, webSession]
        /// Sessioni delle versioni precedenti (cookie e Bearer della web): non valgono più.
        static let legacy = ["aria.web_session", "aria.link_session", "aria.link_verifier"]
    }

    /// La sessione aperta: letta dal Keychain una volta, poi tenuta in memoria.
    private nonisolated enum Credential: Sendable {
        /// Operatore: Bearer verso l'host di accesso.
        case mobile(String)
        /// Account della piattaforma: cookie better-auth verso la web.
        case webCookie(String)

        var key: String {
            switch self {
            case .mobile: Keys.session
            case .webCookie: Keys.webSession
            }
        }

        var value: String {
            switch self {
            case .mobile(let value), .webCookie(let value): value
            }
        }

        /// Stessa sessione con un valore nuovo (il server la riemette quando la proroga).
        func renewed(_ value: String) -> Credential {
            switch self {
            case .mobile: .mobile(value)
            case .webCookie: .webCookie(value)
            }
        }

        /// Per la traccia: il tipo, mai il valore.
        var label: String {
            switch self {
            case .mobile: "operatore"
            case .webCookie: "web"
            }
        }
    }

    private nonisolated struct VerifyResponse: Decodable, Sendable {
        let token: String?
        let user: AriaMobileAccount
    }

    private nonisolated struct TokenResponse: Decodable, Sendable {
        let token: String
    }

    /// `callbackURL` dei magic link chiesti dall'app: l'apple-app-site-association della web riconosce
    /// da qui (`*aria-ios*`) i link da aprire nell'app, così quelli chiesti dal sito restano a Safari.
    /// Aperto in un browser (es. sul computer) porta alla home della web, come "/".
    private nonisolated static let appCallbackPath = "/?from=aria-ios"
    private nonisolated static let webVerifyPath = "/api/auth/magic-link/verify"

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
        session = AriaHTTP.cookielessSession()
        // Le sessioni delle versioni precedenti non servono più: via dal Keychain, una volta per installazione
        // (la reinstallazione azzera UserDefaults, quindi il flag, e il Keychain si ripulisce di nuovo).
        if !UserDefaults.standard.bool(forKey: Self.legacyPurgedKey) {
            Keys.legacy.forEach(AriaKeychain.delete)
            UserDefaults.standard.set(true, forKey: Self.legacyPurgedKey)
        }
    }

    private nonisolated static let legacyPurgedKey = "aria.legacy_keys_purged"

    /// Controlli sul Keychain che non leggono il valore: non chiedono mai Face ID.
    nonisolated var hasStoredSession: Bool {
        hasStoredSession(knowingLogin: hasStoredLogin)
    }

    /// Come `hasStoredSession` quando `hasStoredLogin` è già stato letto: evita di rileggere il Keychain.
    nonisolated func hasStoredSession(knowingLogin hasLogin: Bool) -> Bool {
        hasLogin || AriaKeychain.exists(Keys.devAccess)
    }

    /// Una sessione salvata, dell'operatore o della web (non il token di sviluppo): all'avvio va aperta con Face ID.
    nonisolated var hasStoredLogin: Bool {
        Keys.sessions.contains(where: AriaKeychain.exists)
    }

    /// Sessione di un operatore (non della web, non il token di sviluppo): una sola azienda,
    /// disabilitabile dall'admin a sessione aperta.
    nonisolated var isMobileSession: Bool {
        AriaKeychain.exists(Keys.session)
    }

    /// Dimentica la sessione salvata senza chiamare il server (nessun profilo che la accompagni).
    nonisolated func forgetStoredSession() {
        Keys.sessions.forEach(AriaKeychain.delete)
    }

    /// Come `forgetStoredSession`, per il token di sviluppo.
    nonisolated func forgetDeveloperToken() {
        AriaKeychain.delete(Keys.devAccess)
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
        AriaAuthTrace.step("unlock.ok", found.label)
        return true
    }

    // MARK: Login

    /// Passo 1 dell'operatore: l'email col link. Risponde 202 anche per un indirizzo che non è di un operatore,
    /// quindi un esito positivo non dice niente sull'account.
    func requestLink(email: String) async throws {
        var req = request("api/auth/mobile/request-link", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["email": email])
        AriaAuthTrace.step("link.request", req.url?.absoluteString ?? "-")
        let (data, response) = try await send(req, response: "link.request.response", network: "link.request.network")
        try Self.checkLink(response, data)
    }

    /// Passo 1 dell'account della piattaforma, come il form della web: better-auth manda l'email col link
    /// (valido 10', una volta). Il captcha Turnstile vale una volta sola: ogni invio ne vuole uno nuovo.
    func requestWebLink(email: String, captcha: String) async throws {
        var req = webRequest("api/auth/sign-in/magic-link", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(captcha, forHTTPHeaderField: "x-captcha-response")
        req.httpBody = try JSONEncoder().encode(["email": email, "callbackURL": Self.appCallbackPath])
        AriaAuthTrace.step("webLink.request", req.url?.absoluteString ?? "-")
        let (data, response) = try await send(req, response: "webLink.request.response", network: "webLink.request.network")
        do { try Self.checkWebLink(response, data) }
        catch {
            AriaAuthTrace.failure("webLink.request.rejected", error)
            throw error
        }
    }

    /// Estrae il link di accesso da un testo incollato. Solo link del nostro host.
    nonisolated func magicLink(in text: String) -> AriaSignInLink? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.matches(in: text, range: range).lazy
            .compactMap(\.url)
            .compactMap(signInLink(from:))
            .first
    }

    /// Il link di accesso in un URL aperto dal sistema o incollato:
    /// • operatore: `https://<host>/m/sign-in#token=…` o `aria://sign-in#token=…`; il token sta nel frammento,
    ///   la query si accetta per tolleranza;
    /// • web: `https://<host>/api/auth/magic-link/verify?token=…&callbackURL=…`.
    /// L'host è quello di accesso (in produzione è la web app).
    nonisolated func signInLink(from url: URL) -> AriaSignInLink? {
        if url.scheme == "aria" {
            guard url.host() == "sign-in" else { return nil }
            return Self.mobileToken(in: url).map(AriaSignInLink.init(token:))
        }
        guard url.host() == config.authBaseURL.host() else { return nil }
        switch url.path() {
        case "/m/sign-in": return Self.mobileToken(in: url).map(AriaSignInLink.init(token:))
        case Self.webVerifyPath: return webVerifyURL(from: url).map(AriaSignInLink.web)
        default: return nil
        }
    }

    private nonisolated static func mobileToken(in url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let fromFragment = components.fragment
            .flatMap { URLComponents(string: "?" + $0)?.queryItems?.first { $0.name == "token" }?.value }
        let token = fromFragment ?? components.queryItems?.first { $0.name == "token" }?.value
        guard let token, !token.isEmpty else { return nil }
        return token
    }

    /// Il link della web ricostruito sul nostro host (schema e porta compresi): del link arrivato
    /// passa solo `token`; `callbackURL` è sempre quello dell'app.
    private nonisolated func webVerifyURL(from url: URL) -> URL? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let token = items.first(where: { $0.name == "token" })?.value, !token.isEmpty,
              var components = URLComponents(url: config.authBaseURL.appending(path: String(Self.webVerifyPath.dropFirst())),
                                             resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = [URLQueryItem(name: "token", value: token),
                                 URLQueryItem(name: "callbackURL", value: Self.appCallbackPath)]
        return components.url
    }

    /// Passo 2 dell'operatore: il token del link contro una sessione. Il token vale una volta; se la rete cade
    /// prima della risposta di solito non è stato consumato e il link si può riprovare.
    /// Il link della web si apre con `completeWebSignIn`: chi è l'account lo dice poi GET /v1/me.
    func completeSignIn(with link: AriaSignInLink) async throws -> AriaMobileAccount {
        guard case .mobile(let token) = link else {
            assertionFailure("il link della web si apre con completeWebSignIn")
            throw AriaError.linkSignInUnavailable
        }
        var req = request("api/auth/mobile/verify", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["token": token])
        AriaAuthTrace.step("link.verify", req.url?.absoluteString ?? "-")
        let (data, response) = try await send(req, response: "link.verify.response", network: "link.verify.network")
        do { try Self.checkLink(response, data) }
        catch {
            AriaAuthTrace.failure("link.verify.rejected", error)
            throw error
        }

        let verified: VerifyResponse
        do { verified = try JSONDecoder().decode(VerifyResponse.self, from: data) }
        catch {
            AriaAuthTrace.failure("link.verify.decode", error)
            throw AriaError.decoding("verify: \(error)")
        }
        // La sessione è nell'header; il `token` del body è lo stesso valore.
        let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "set-auth-token")
        guard let session = [header, verified.token].lazy.compactMap({ $0 }).first(where: { !$0.isEmpty }) else {
            AriaAuthTrace.step("link.verify.noSession", "manca set-auth-token")
            throw AriaError.stream(String(localized: "Sign-in did not return a session. Try again."))
        }
        store(.mobile(session))
        resetAccessToken()
        // Senza il primo JWT l'accesso non è completo: la sessione appena aperta non resta né in memoria
        // né nel Keychain (il link è già consumato, non si potrebbe comunque riusare).
        do { _ = try await refresh() } catch { clear(); throw error }
        AriaAuthTrace.step("link.verify.ok", "id=\(verified.user.id)")
        return verified.user
    }

    /// Passo 2 dell'account della piattaforma: apre il magic link come farebbe il browser, senza seguire
    /// il redirect (il 302 porta il cookie di sessione), poi conia il primo JWT.
    func completeWebSignIn(with url: URL) async throws {
        var req = URLRequest(url: url)
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        req.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        // Nella traccia niente query: c'è il token del link.
        AriaAuthTrace.step("webLink.verify", "\(url.host() ?? "-")\(url.path())")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req, delegate: NoRedirect())
        } catch {
            // Rete: di solito il token non è stato usato, si può toccare di nuovo il link.
            AriaAuthTrace.failure("webLink.verify.network", error)
            throw error
        }
        AriaAuthTrace.response("webLink.verify.response", response, data)
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        if let offline = AriaHTTP.hostDownError(response) { throw offline }

        let location = http.value(forHTTPHeaderField: "Location").flatMap { URL(string: $0, relativeTo: url) }
        if let code = location.flatMap(Self.errorCode(in:)) {
            AriaAuthTrace.step("webLink.verify.rejected", "error=\(code)")
            throw Self.linkError(code)
        }
        if !(300..<400).contains(http.statusCode) { try Self.checkWebLink(response, data) }

        guard let cookie = Self.sessionCookie(in: http, for: url) else {
            AriaAuthTrace.step("webLink.verify.noSession", "manca il cookie di sessione")
            throw AriaError.stream(String(localized: "The sign-in link did not start a session. Request a new one."))
        }
        store(.webCookie(cookie))
        resetAccessToken()
        do { _ = try await refresh() } catch { clear(); throw error }
        AriaAuthTrace.step("webLink.verify.ok", "")
    }

    #if DEBUG
    /// Solo sviluppo: usa un access token già emesso (niente rinnovo, vale fino a `exp`).
    func useDeveloperToken(_ token: String) throws {
        guard let exp = Self.expiry(ofJWT: token), exp.timeIntervalSinceNow > 0 else {
            throw AriaError.stream(String(localized: "The token is not a valid JWT or has expired."))
        }
        clear()
        AriaKeychain.set(token, for: Keys.devAccess)
        useAccessToken(token, validFor: .seconds(exp.timeIntervalSinceNow))
    }

    /// Solo UI test: la sessione di un operatore già emessa (`set-auth-token`), senza passare dal link via email.
    /// Non protetta da Face ID: un test non può rispondere al prompt.
    func useSessionToken(_ token: String) async throws {
        clear()
        AriaKeychain.set(token, for: Keys.session, protected: false)
        credential = .mobile(token)
        _ = try await refresh()
    }
    #endif

    /// Chiude la sessione di questo dispositivo (gli altri restano collegati).
    /// Con la sessione ancora chiusa da Face ID la si dimentica solo qui: sul server scade da sola.
    func signOut() async {
        switch loadCredential(context: nil) {
        case .mobile(let token)?:
            let req = request("api/auth/sign-out", method: "POST", bearer: token)
            _ = try? await session.data(for: req)
        case .webCookie(let cookie)?:
            var req = webRequest("api/auth/sign-out", method: "POST", cookie: cookie)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data("{}".utf8)
            _ = try? await session.data(for: req)
        case nil:
            break
        }
        clear()
    }

    /// Dimentica la sessione senza chiamare il server: la sessione è già finita
    /// (operatore disabilitato, membership non più attiva) o non va tenuta (accesso non completato).
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

    /// Sessione (Bearer dell'operatore o cookie della web) → JWT per l'host dei dati (15').
    private func performRefresh() async throws -> String {
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
        case .webCookie(let cookie): webRequest("api/aria/token", method: "GET", cookie: cookie)
        }
        AriaAuthTrace.step("token.request", "\(req.url?.absoluteString ?? "-") sessione=\(credential.label)")
        let (data, response) = try await send(req, response: "token.response", network: "token.network")
        // Host giù: la sessione è ancora buona, non si slogga.
        if let offline = AriaHTTP.hostDownError(response) {
            AriaAuthTrace.step("token.hostOffline", "")
            throw offline
        }
        do {
            try AriaHTTP.check(response, data)
        } catch AriaError.http(let status, _) where status == 401 || status == 403 {
            // 401/403 significano "sessione finita" (scaduta, account disabilitato, terzo
            // dispositivo che ha scalzato questo): si rifà l'accesso.
            AriaAuthTrace.step("token.sessionEnded", "status=\(status): sessione cancellata dal Keychain")
            clear()
            throw AriaError.signedOut
        }
        // Il server può riemettere la sessione quando la proroga: header per l'operatore, cookie per la web.
        if let http = response as? HTTPURLResponse, let url = req.url {
            let renewed = switch credential {
            case .mobile: http.value(forHTTPHeaderField: "set-auth-token").flatMap { $0.isEmpty ? nil : $0 }
            case .webCookie: Self.sessionCookie(in: http, for: url)
            }
            if let renewed, renewed != credential.value { store(credential.renewed(renewed)) }
        }
        // `companyId` della risposta si ignora: l'azienda la sceglie AriaBackend con GET /v1/companies.
        let jwt = try JSONDecoder().decode(TokenResponse.self, from: data).token
        guard let exp = Self.expiry(ofJWT: jwt) else {
            AriaAuthTrace.step("token.invalidJWT", "la risposta non è un JWT")
            throw AriaError.decoding("token")
        }
        AriaAuthTrace.step("token.ok", "scade fra \(Int(exp.timeIntervalSinceNow))s")
        useAccessToken(jwt, validFor: Self.mintedTokenLifetime)
        return jwt
    }

    private func useAccessToken(_ token: String, validFor lifetime: Duration) {
        accessToken = token
        validUntil = .now + lifetime
    }

    private func resetAccessToken() {
        accessToken = nil
        validUntil = .now
    }

    /// La sessione, se non è già in memoria. Senza `context` (autenticato da Face ID, `unlock`) una sessione
    /// protetta resta chiusa: non si chiede mai nulla all'utente da qui.
    private func loadCredential(context: LAContext?) -> Credential? {
        if let credential { return credential }
        credential = AriaKeychain.get(Keys.session, context: context).map(Credential.mobile)
            ?? AriaKeychain.get(Keys.webSession, context: context).map(Credential.webCookie)
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

    /// Una richiesta all'host di accesso; la rete che cade si registra e si rilancia.
    private func send(_ req: URLRequest, response label: StaticString, network: StaticString) async throws -> (Data, URLResponse) {
        do {
            let result = try await session.data(for: req)
            AriaAuthTrace.response(label, result.1, result.0)
            return result
        } catch {
            AriaAuthTrace.failure(network, error)
            throw error
        }
    }

    private func request(_ path: String, method: String, bearer: String? = nil) -> URLRequest {
        var req = URLRequest(url: config.authBaseURL.appending(path: path))
        req.httpMethod = method
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        // È il nome del dispositivo che l'admin vede fra le sessioni.
        req.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        return req
    }

    /// Richiesta alle rotte better-auth della web (stesso host di accesso): better-auth controlla l'Origin
    /// delle POST. Il cookie di sessione va a mano, mai da un cookie storage.
    private func webRequest(_ path: String, method: String, cookie: String? = nil) -> URLRequest {
        var req = request(path, method: method)
        req.setValue(Self.origin(of: config.authBaseURL), forHTTPHeaderField: "Origin")
        if let cookie { req.setValue(cookie, forHTTPHeaderField: "Cookie") }
        return req
    }

    // MARK: Parsing

    /// Errori di request-link e verify dell'operatore: si decide sul codice, non sul testo.
    private static func checkLink(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        if let offline = AriaHTTP.hostDownError(response) { throw offline }
        let code = AriaHTTP.code(from: data)
        switch http.statusCode {
        case 200..<300:
            return
        case 401 where code == "INVALID_OR_EXPIRED_LINK":
            throw AriaError.linkExpired
        case 403 where code == "ACCOUNT_DISABLED":
            throw AriaError.stream(String(localized: "This account is disabled. Contact your company administrator."))
        case 404:
            // Rotta assente sull'host di accesso: il server non è quello giusto.
            throw AriaError.linkSignInUnavailable
        case 429:
            // request-link: 10 ogni 10 minuti; verify: 10 al minuto.
            throw tooManyAttempts(http)
        default:
            try AriaHTTP.check(response, data)
        }
    }

    /// Errori del magic link della web (better-auth): captcha mancante o rifiutato, troppi tentativi.
    private static func checkWebLink(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        if let offline = AriaHTTP.hostDownError(response) { throw offline }
        let code = AriaHTTP.code(from: data)
        switch http.statusCode {
        case 200..<300:
            return
        case 400 where code == "MISSING_RESPONSE", 403 where code == "VERIFICATION_FAILED":
            throw AriaError.captchaRejected
        case 429:
            throw tooManyAttempts(http)
        default:
            try AriaHTTP.check(response, data)
        }
    }

    private static func tooManyAttempts(_ http: HTTPURLResponse) -> AriaError {
        .tooManyAttempts(retryAfter: http.value(forHTTPHeaderField: "X-Retry-After").flatMap(Int.init))
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

    /// `?error=CODICE` del redirect di un magic link rifiutato.
    private static func errorCode(in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first { $0.name == "error" }?.value
    }

    private static func linkError(_ code: String) -> AriaError {
        switch code {
        case "EXPIRED_TOKEN", "INVALID_TOKEN", "ATTEMPTS_EXCEEDED":
            .linkExpired
        default:
            .stream(String(localized: "Sign-in failed (\(code)). Request a new link."))
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

/// Ferma i redirect: il cookie di sessione arriva sulla risposta 302 del magic link.
private nonisolated final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
