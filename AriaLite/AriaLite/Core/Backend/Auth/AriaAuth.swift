//
//  AriaAuth.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Accesso dell'operatore mobile, senza password: un link via email. Tutto sull'host di accesso
//  (app.ariaplt.com, la web app; i dati stanno su api.ariaplt.com):
//
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
//  Mai cookie verso l'host: solo l'header Authorization. Il JWT resta in memoria e si rinnova
//  13' dopo il conio (orologio monotono: l'ora del telefono può essere sbagliata), un rinnovo
//  alla volta. 401 sul rinnovo = sessione finita, si rifà l'accesso.
//
//  Un host che non risponde (502/503/504) non va scambiato per un link sbagliato né per una sessione finita.
//
//  iOS apre l'app da solo col link dell'email (Universal Link, `applinks:app.ariaplt.com`) se aria-web
//  elenca questo bundle in `MOBILE_IOS_APP_IDS`; altrimenti il link si copia dall'email e si incolla
//  (o `aria://sign-in#token=…`, se la pagina ha un pulsante).
//
//  La sessione salvata è protetta da Face ID nel Keychain: all'avvio `unlock` la legge una volta
//  e da lì resta in memoria; nessuna altra lettura chiede Face ID.
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

/// Un link di accesso riconosciuto, toccato nell'email o incollato.
nonisolated struct AriaSignInLink: Sendable, Equatable {
    let token: String
}

actor AriaAuth {
    private nonisolated enum Keys {
        /// Token di sessione (`set-auth-token`), mandato come Bearer all'host.
        static let session = "aria.mobile_session"
        static let devAccess = "aria.dev_access_token"
        /// Sessioni delle versioni precedenti (cookie e Bearer della web): non valgono più.
        static let legacy = ["aria.web_session", "aria.link_session", "aria.link_verifier"]
    }

    private nonisolated struct VerifyResponse: Decodable, Sendable {
        let token: String?
        let user: AriaMobileAccount
    }

    private nonisolated struct TokenResponse: Decodable, Sendable {
        let token: String
    }

    /// L'host ne conia uno ogni 15': si rinnova un po' prima.
    private static let mintedTokenLifetime: Duration = .seconds(13 * 60)

    private let config: AriaConfig
    private let session: URLSession
    /// La sessione aperta: letta dal Keychain una volta, poi tenuta in memoria.
    private var sessionToken: String?
    private var accessToken: String?
    private var validUntil = ContinuousClock.now
    private var refreshTask: Task<String, any Error>?

    init(config: AriaConfig) {
        self.config = config
        session = AriaHTTP.cookielessSession()
        // Le sessioni delle versioni precedenti non servono più: via dal Keychain.
        Keys.legacy.forEach(AriaKeychain.delete)
    }

    /// Controlli sul Keychain che non leggono il valore: non chiedono mai Face ID.
    nonisolated var hasStoredSession: Bool {
        hasStoredLogin || AriaKeychain.exists(Keys.devAccess)
    }

    /// Una sessione salvata (non il token di sviluppo): all'avvio va aperta con Face ID.
    nonisolated var hasStoredLogin: Bool {
        AriaKeychain.exists(Keys.session)
    }

    /// Sessione di un operatore (non il token di sviluppo): una sola azienda, disabilitabile dall'admin a sessione aperta.
    nonisolated var isMobileSession: Bool {
        AriaKeychain.exists(Keys.session)
    }

    /// Dimentica la sessione salvata senza chiamare il server (nessun profilo che la accompagni).
    nonisolated func forgetStoredSession() {
        AriaKeychain.delete(Keys.session)
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
        if sessionToken != nil { return true }
        guard let found = AriaKeychain.get(Keys.session, context: context) else { return false }
        sessionToken = found
        // Una sessione salvata prima di Face ID era in chiaro: da ora è protetta.
        store(found)
        AriaAuthTrace.step("unlock.ok", "")
        return true
    }

    // MARK: Login

    /// Passo 1: l'email col link. Risponde 202 anche per un indirizzo che non è di un operatore,
    /// quindi un esito positivo non dice niente sull'account.
    func requestLink(email: String) async throws {
        var req = request("api/auth/mobile/request-link", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["email": email])
        AriaAuthTrace.step("link.request", req.url?.absoluteString ?? "-")
        let (data, response) = try await send(req, response: "link.request.response", network: "link.request.network")
        try Self.checkLink(response, data)
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

    /// Il link di accesso in un URL aperto dal sistema o incollato: `https://<host>/m/sign-in#token=…`,
    /// o `aria://sign-in#token=…`. Il token sta nel frammento; la query si accetta per tolleranza.
    nonisolated func signInLink(from url: URL) -> AriaSignInLink? {
        if url.scheme == "aria" {
            guard url.host() == "sign-in" else { return nil }
        } else {
            guard url.host() == config.authBaseURL.host(), url.path() == "/m/sign-in" else { return nil }
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let fromFragment = components.fragment
            .flatMap { URLComponents(string: "?" + $0)?.queryItems?.first { $0.name == "token" }?.value }
        let token = fromFragment ?? components.queryItems?.first { $0.name == "token" }?.value
        guard let token, !token.isEmpty else { return nil }
        return AriaSignInLink(token: token)
    }

    /// Passo 2: il token del link contro una sessione. Il token vale una volta; se la rete cade
    /// prima della risposta di solito non è stato consumato e il link si può riprovare.
    func completeSignIn(with link: AriaSignInLink) async throws -> AriaMobileAccount {
        var req = request("api/auth/mobile/verify", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["token": link.token])
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
        guard let token = [header, verified.token].lazy.compactMap({ $0 }).first(where: { !$0.isEmpty }) else {
            AriaAuthTrace.step("link.verify.noSession", "manca set-auth-token")
            throw AriaError.stream(String(localized: "Sign-in did not return a session. Try again."))
        }
        store(token)
        resetAccessToken()
        _ = try await refresh()
        AriaAuthTrace.step("link.verify.ok", "id=\(verified.user.id)")
        return verified.user
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
        sessionToken = token
        _ = try await refresh()
    }
    #endif

    /// Chiude la sessione di questo dispositivo (gli altri restano collegati).
    /// Con la sessione ancora chiusa da Face ID la si dimentica solo qui: sul server scade da sola.
    func signOut() async {
        if let token = sessionToken ?? AriaKeychain.get(Keys.session) {
            let req = request("api/auth/sign-out", method: "POST", bearer: token)
            _ = try? await session.data(for: req)
        }
        clear()
    }

    /// Dimentica la sessione senza chiamare il server: la sessione è già finita
    /// (operatore disabilitato, membership non più attiva).
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

    /// Sessione → JWT per l'host dei dati (15').
    private func performRefresh() async throws -> String {
        guard let token = loadSession() else {
            if hasStoredLogin {
                // Salvata ma protetta da Face ID: l'app la apre con `unlock`, qui non si chiede nulla.
                AriaAuthTrace.step("token.locked", "sessione da aprire con Face ID")
                throw AriaError.locked
            }
            AriaAuthTrace.step("token.noSession", "niente in Keychain: si torna al login")
            throw AriaError.signedOut
        }
        let req = request("api/aria/token", method: "GET", bearer: token)
        AriaAuthTrace.step("token.request", req.url?.absoluteString ?? "-")
        let (data, response) = try await send(req, response: "token.response", network: "token.network")
        // Host giù: la sessione è ancora buona, non si slogga.
        if let offline = AriaHTTP.hostDownError(response) {
            AriaAuthTrace.step("token.hostOffline", "")
            throw offline
        }
        do {
            try AriaHTTP.check(response, data)
        } catch AriaError.http(let status, _) where status == 401 || status == 403 {
            // 401/403 significano "sessione finita" (scaduta, operatore disabilitato, terzo
            // dispositivo che ha scalzato questo): si rifà l'accesso.
            AriaAuthTrace.step("token.sessionEnded", "status=\(status): sessione cancellata dal Keychain")
            clear()
            throw AriaError.signedOut
        }
        // Il server può riemettere la sessione quando la proroga.
        if let renewed = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "set-auth-token"),
           !renewed.isEmpty, renewed != token {
            store(renewed)
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

    /// La sessione, se non è già in memoria. Senza Face ID autenticato (`unlock`) una sessione
    /// protetta resta chiusa: non si chiede mai nulla all'utente da qui.
    private func loadSession() -> String? {
        if sessionToken == nil { sessionToken = AriaKeychain.get(Keys.session) }
        return sessionToken
    }

    /// Salva la sessione (protetta da Face ID se il telefono ha un codice) al posto di ogni altra.
    private func store(_ token: String) {
        AriaKeychain.delete(Keys.devAccess)
        AriaKeychain.set(token, for: Keys.session, protected: AriaBiometrics.isAvailable)
        sessionToken = token
    }

    private func clear() {
        resetAccessToken()
        sessionToken = nil
        for key in [Keys.session, Keys.devAccess] { AriaKeychain.delete(key) }
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

    // MARK: Parsing

    /// Errori di request-link e verify: si decide sul codice, non sul testo.
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
