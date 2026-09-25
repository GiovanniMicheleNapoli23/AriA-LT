//
//  AriaNetworking.swift
//  AriaLite
//
//  Configurazione, errori, controllo delle risposte HTTP e Keychain
//  per la connessione al backend Aria (FastAPI aria-backend).
//

import Foundation
import Security

nonisolated struct AriaConfig: Sendable {
    static let productionAPI = URL(string: "https://api.ariaplt.com")!
    static let productionWeb = URL(string: "https://app.ariaplt.com")!

    /// FastAPI aria-backend: chat, sessioni, aziende, stabilimenti.
    var apiBaseURL: URL
    /// Web app Next.js: login mobile (/api/mobile/auth/*). Firma lo stesso JWT di /api/aria/token.
    var authBaseURL: URL
    /// Mandato come X-Aria-Client: solo diagnostica, non è un segreto.
    var clientId = "aria-ios/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")"
    /// Limite WAF CloudFront. Alzalo quando il backend esenta /v1/responses.
    var maxBodyBytes = 8_000
    /// Silenzio massimo sullo stream prima di considerarlo morto (i tool possono essere lenti).
    var streamIdleTimeout: TimeInterval = 180
    /// `model` per /v1/responses: il modello Bedrock lo sceglie il backend.
    var model = "default"

    static let production = AriaConfig(apiBaseURL: productionAPI, authBaseURL: productionWeb)

    private static let apiKey = "aria.api_base_url"
    private static let webKey = "aria.web_base_url"

    /// Server salvati (in DEBUG si possono cambiare dalle impostazioni), altrimenti produzione.
    static var current: AriaConfig {
        #if DEBUG
        let defaults = UserDefaults.standard
        return AriaConfig(
            apiBaseURL: defaults.string(forKey: apiKey).flatMap(URL.init(string:)) ?? productionAPI,
            authBaseURL: defaults.string(forKey: webKey).flatMap(URL.init(string:)) ?? productionWeb
        )
        #else
        return production
        #endif
    }

    static func saveServers(api: URL?, web: URL?) {
        UserDefaults.standard.set(api?.absoluteString, forKey: apiKey)
        UserDefaults.standard.set(web?.absoluteString, forKey: webKey)
    }
}

nonisolated enum AriaError: LocalizedError, Sendable {
    case signedOut
    case http(status: Int, detail: String)
    case wafBlocked
    case bodyTooLarge(bytes: Int, limit: Int)
    case missingCompany
    case missingPlant
    case decoding(String)
    case stream(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: String(localized: "Your Aria session has expired. Sign in again.")
        case .http(let status, let detail): String(localized: "Error \(status): \(detail)")
        case .wafBlocked: String(localized: "Request blocked by the firewall (body over 8 KB).")
        case .bodyTooLarge(let bytes, let limit): String(localized: "Message too long (\(bytes) bytes, limit \(limit)).")
        case .missingCompany: String(localized: "No company selected.")
        case .missingPlant: String(localized: "Select a plant before using the chat.")
        case .decoding(let message): String(localized: "Invalid server response: \(message)")
        case .stream(let message): message
        }
    }
}

nonisolated enum AriaHTTP {
    static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        guard !(200..<300).contains(http.statusCode) else { return }
        let server = http.value(forHTTPHeaderField: "Server") ?? ""
        if http.statusCode == 403, server.localizedCaseInsensitiveContains("cloudfront") {
            throw AriaError.wafBlocked
        }
        throw AriaError.http(status: http.statusCode, detail: detail(from: data))
    }

    /// FastAPI: {"detail": "…"} | {"detail": [{"msg": …}]} | {"detail": {"code": …, "message": …}}
    static func detail(from data: Data) -> String {
        guard let json = try? JSONDecoder().decode(AriaJSON.self, from: data), let detail = json["detail"] else {
            return String(decoding: data.prefix(500), as: UTF8.self)
        }
        return switch detail {
        case .string(let s): s
        case .array(let items): items.compactMap { $0["msg"]?.stringValue }.joined(separator: "; ")
        case .object: detail["message"]?.stringValue ?? detail["code"]?.stringValue ?? "\(detail)"
        default: "\(detail)"
        }
    }
}

nonisolated enum AriaKeychain {
    private static let service = (Bundle.main.bundleIdentifier ?? "AriaLite") + ".aria"

    private static func baseQuery(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func set(_ value: String, for account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
        var item = baseQuery(account)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func get(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}
