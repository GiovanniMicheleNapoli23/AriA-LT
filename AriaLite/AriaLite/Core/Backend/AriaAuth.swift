//
//  AriaAuth.swift
//  AriaLite
//
//  Login come la web app (better-auth, magic link): l'app chiede il link via email
//  (POST /api/auth/sign-in/magic-link, con captcha Turnstile), l'utente incolla il link,
//  l'app lo apre e tiene il cookie di sessione della web (7 gg) nel Keychain.
//  Con quel cookie GET /api/aria/token dà l'access JWT (15') per api.ariaplt.com,
//  esattamente come fa il browser. Access token solo in memoria.
//  Rinnovo proattivo 60 s prima della scadenza e un solo rinnovo alla volta.
//
//  In DEBUG si può anche incollare un access token preso dalla web (GET /api/aria/token).
//

import Foundation

actor AriaAuth {
    private nonisolated enum Keys {
        /// Cookie di sessione better-auth, salvato come "nome=valore".
        static let session = "aria.web_session"
        static let devAccess = "aria.dev_access_token"
    }

    private nonisolated struct TokenResponse: Decodable, Sendable {
        let token: String
    }

    private let config: AriaConfig
    private let session: URLSession
    private var accessToken: String?
    private var expiresAt = Date.distantPast
    private var refreshTask: Task<String, any Error>?

    init(config: AriaConfig) {
        self.config = config
        // I cookie li gestiamo a mano: niente cookie condivisi che finiscano su richieste non volute.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        session = URLSession(configuration: configuration)
    }

    nonisolated var hasStoredSession: Bool {
        AriaKeychain.get(Keys.session) != nil || AriaKeychain.get(Keys.devAccess) != nil
    }

    // MARK: Login

    /// Come il form della web: better-auth manda l'email col link (valido 10', usabile una volta).
    func sendMagicLink(email: String, captcha: String, locale: String) async throws {
        var req = request("api/auth/sign-in/magic-link", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(captcha, forHTTPHeaderField: "x-captcha-response")
        req.setValue(locale, forHTTPHeaderField: "x-aria-locale")
        req.httpBody = try JSONEncoder().encode(["email": email, "callbackURL": "/"])
        let (data, response) = try await session.data(for: req)
        try Self.checkLogin(response, data)
    }

    /// Estrae il link di accesso da un testo incollato. Solo link della nostra web app.
    nonisolated func magicLink(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.matches(in: text, range: range).lazy
            .compactMap(\.url)
            .first { url in
                url.host() == config.authBaseURL.host()
                    && url.path().hasSuffix("/magic-link/verify")
                    && URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.contains { $0.name == "token" && $0.value?.isEmpty == false } == true
            }
    }

    /// Apre il link come farebbe il browser, senza seguire il redirect: il 302 porta il cookie di sessione.
    func completeSignIn(with link: URL) async throws {
        var req = URLRequest(url: link)
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        let (data, response) = try await session.data(for: req, delegate: NoRedirect())
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }

        let location = http.value(forHTTPHeaderField: "Location").flatMap { URL(string: $0, relativeTo: link) }
        if let code = location.flatMap(Self.errorCode(in:)) {
            throw AriaError.stream(Self.message(forLinkError: code))
        }
        if !(300..<400).contains(http.statusCode) { try Self.checkLogin(response, data) }

        guard let cookie = Self.sessionCookie(in: http, for: link) else {
            throw AriaError.stream(String(localized: "The sign-in link did not start a session. Request a new one."))
        }
        AriaKeychain.delete(Keys.devAccess)
        AriaKeychain.set(cookie, for: Keys.session)
        accessToken = nil
        expiresAt = .distantPast
        _ = try await refresh()
    }

    /// Solo sviluppo: usa un access token già emesso (niente rinnovo, vale fino a `exp`).
    func useDeveloperToken(_ token: String) throws {
        guard let exp = Self.expiry(ofJWT: token), exp.timeIntervalSinceNow > 0 else {
            throw AriaError.stream(String(localized: "The token is not a valid JWT or has expired."))
        }
        AriaKeychain.delete(Keys.session)
        AriaKeychain.set(token, for: Keys.devAccess)
        accessToken = token
        expiresAt = exp
    }

    func signOut() async {
        if let cookie = AriaKeychain.get(Keys.session) {
            var req = request("api/auth/sign-out", method: "POST", cookie: cookie)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data("{}".utf8)
            _ = try? await session.data(for: req)
        }
        clear()
    }

    // MARK: Token

    func validAccessToken() async throws -> String {
        if let token = accessToken, expiresAt.timeIntervalSinceNow > 60 { return token }
        if let dev = AriaKeychain.get(Keys.devAccess) {
            guard let exp = Self.expiry(ofJWT: dev), exp.timeIntervalSinceNow > 0 else {
                clear()
                throw AriaError.signedOut
            }
            accessToken = dev
            expiresAt = exp
            return dev
        }
        return try await refresh()
    }

    /// Chiamato dopo un 401: il prossimo validAccessToken() forza il rinnovo.
    func invalidate() {
        // Un token incollato non si può rinnovare: dopo un 401 è finito.
        if AriaKeychain.get(Keys.devAccess) != nil { clear() }
        accessToken = nil
        expiresAt = .distantPast
    }

    private func refresh() async throws -> String {
        if let running = refreshTask { return try await running.value }
        let task = Task(name: "aria.auth.refresh") { try await self.performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    /// Stesso endpoint che usa il browser: sessione better-auth → JWT per il backend.
    private func performRefresh() async throws -> String {
        guard let cookie = AriaKeychain.get(Keys.session) else { throw AriaError.signedOut }
        let req = request("api/aria/token", method: "GET", cookie: cookie)
        let (data, response) = try await session.data(for: req)
        do {
            try AriaHTTP.check(response, data)
        } catch AriaError.http(let status, _) where status == 401 || status == 403 {
            // Solo 401/403 significano "sessione finita": un errore di rete non slogga.
            clear()
            throw AriaError.signedOut
        }
        // better-auth può riemettere il cookie quando proroga la sessione.
        if let http = response as? HTTPURLResponse, let renewed = Self.sessionCookie(in: http, for: req.url!) {
            AriaKeychain.set(renewed, for: Keys.session)
        }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data).token
        guard let exp = Self.expiry(ofJWT: token) else { throw AriaError.decoding("token") }
        accessToken = token
        expiresAt = exp
        return token
    }

    private func clear() {
        accessToken = nil
        expiresAt = .distantPast
        AriaKeychain.delete(Keys.session)
        AriaKeychain.delete(Keys.devAccess)
    }

    private func request(_ path: String, method: String, cookie: String? = nil) -> URLRequest {
        var req = URLRequest(url: config.authBaseURL.appending(path: path))
        req.httpMethod = method
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        // better-auth controlla l'Origin delle POST che portano cookie.
        req.setValue(Self.origin(of: config.authBaseURL), forHTTPHeaderField: "Origin")
        if let cookie { req.setValue(cookie, forHTTPHeaderField: "Cookie") }
        return req
    }

    // MARK: Parsing

    /// better-auth limita invio e verifica dei link a 5 richieste al minuto.
    private static func checkLogin(_ response: URLResponse, _ data: Data) throws {
        if (response as? HTTPURLResponse)?.statusCode == 429 {
            throw AriaError.stream(String(localized: "Too many attempts. Wait a minute and try again."))
        }
        try AriaHTTP.check(response, data)
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
