//
//  AriaAuth.swift
//  AriaLite
//
//  Login mobile verso la web app (/api/mobile/auth/*): OTP via email → access JWT (15') + refresh (30 gg).
//  Access token solo in memoria, refresh token nel Keychain.
//  Rinnovo proattivo 60 s prima della scadenza e un solo refresh alla volta.
//
//  In DEBUG si può anche incollare un access token preso dalla web (GET /api/aria/token).
//

import Foundation

actor AriaAuth {
    private nonisolated enum Keys {
        static let refresh = "aria.refresh_token"
        static let device = "aria.device_id"
        static let devAccess = "aria.dev_access_token"
    }

    private nonisolated struct TokenPair: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    private let config: AriaConfig
    private let session: URLSession
    private var accessToken: String?
    private var expiresAt = Date.distantPast
    private var refreshTask: Task<String, any Error>?

    init(config: AriaConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    nonisolated var hasStoredSession: Bool {
        AriaKeychain.get(Keys.refresh) != nil || AriaKeychain.get(Keys.devAccess) != nil
    }

    nonisolated static var deviceId: String {
        if let id = AriaKeychain.get(Keys.device) { return id }
        let id = UUID().uuidString
        AriaKeychain.set(id, for: Keys.device)
        return id
    }

    // MARK: Login

    func startLogin(email: String) async throws {
        _ = try await post("api/mobile/auth/otp/start", ["email": email])
    }

    func verify(email: String, code: String) async throws {
        let data = try await post("api/mobile/auth/otp/verify",
                                  ["email": email, "code": code, "device_id": Self.deviceId])
        AriaKeychain.delete(Keys.devAccess)
        try store(data)
    }

    /// Solo sviluppo: usa un access token già emesso (niente refresh, vale fino a `exp`).
    func useDeveloperToken(_ token: String) throws {
        guard let exp = Self.expiry(ofJWT: token), exp.timeIntervalSinceNow > 0 else {
            throw AriaError.stream(String(localized: "The token is not a valid JWT or has expired."))
        }
        AriaKeychain.delete(Keys.refresh)
        AriaKeychain.set(token, for: Keys.devAccess)
        accessToken = token
        expiresAt = exp
    }

    func signOut() async {
        if let stored = AriaKeychain.get(Keys.refresh) {
            _ = try? await post("api/mobile/auth/logout", ["refresh_token": stored])
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

    /// Chiamato dopo un 401: il prossimo validAccessToken() forza il refresh.
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

    private func performRefresh() async throws -> String {
        guard let stored = AriaKeychain.get(Keys.refresh) else { throw AriaError.signedOut }
        do {
            return try store(try await post("api/mobile/auth/refresh", ["refresh_token": stored]))
        } catch AriaError.http(let status, _) where status == 401 || status == 403 {
            // Solo 401/403 significano "sessione finita": un errore di rete non slogga.
            clear()
            throw AriaError.signedOut
        }
    }

    @discardableResult
    private func store(_ data: Data) throws -> String {
        let pair = try JSONDecoder().decode(TokenPair.self, from: data)
        AriaKeychain.set(pair.refreshToken, for: Keys.refresh)
        accessToken = pair.accessToken
        expiresAt = Date.now.addingTimeInterval(TimeInterval(pair.expiresIn))
        return pair.accessToken
    }

    private func clear() {
        accessToken = nil
        expiresAt = .distantPast
        AriaKeychain.delete(Keys.refresh)
        AriaKeychain.delete(Keys.devAccess)
    }

    private func post(_ path: String, _ body: [String: String]) async throws -> Data {
        var req = URLRequest(url: config.authBaseURL.appending(path: path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        try AriaHTTP.check(response, data)
        return data
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
