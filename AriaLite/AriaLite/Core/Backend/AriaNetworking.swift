//
//  AriaNetworking.swift
//  AriaLite
//
//  Configurazione, errori, controllo delle risposte HTTP e Keychain
//  per la connessione al backend Aria (FastAPI aria-backend).
//

import Foundation
import LocalAuthentication
import Security

nonisolated struct AriaConfig: Sendable {
    static let productionAPI = URL(string: "https://api.ariaplt.com")!
    /// Host di accesso: tunnel temporaneo, in linea solo mentre la nostra macchina lo serve.
    static let productionSignIn = URL(string: "https://benito-fumigatory-christinia.ngrok-free.dev")!
    static let productionWeb = URL(string: "https://app.ariaplt.com")!

    /// FastAPI aria-backend: tutti i dati, sotto /v1.
    var apiBaseURL: URL
    /// Host di accesso: accetta solo /api/auth/* e GET /api/aria/token (il resto risponde 404).
    var authBaseURL: URL
    /// Host dei lavori dell'utente mobile (`/v1/companies`, `/v1/mobile/*`): lo stesso tunnel
    /// dell'accesso, che lascia passare solo quelle rotte (il resto, `/v1/work-orders` compreso, è 404).
    var mobileBaseURL: URL { authBaseURL }
    /// Web app Next.js: login con magic link (better-auth, cookie di sessione) e JWT da /api/aria/token;
    /// serve anche ad aprire i link relativi delle risposte (es. /work-orders/12) nel browser.
    var webBaseURL = AriaConfig.productionWeb
    /// Chiave pubblica Cloudflare Turnstile della web: better-auth vuole il captcha per mandare il link.
    var turnstileSiteKey = "0x4AAAAAADF3cO-EJy4kf-nF"
    /// Mandato come X-Aria-Client: solo diagnostica, non è un segreto.
    var clientId = "aria-ios/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")"
    /// `AriaPLT-Mobile/<versione> (<os> <versione os>; <modello>)`: per gli utenti mobili
    /// è il nome del dispositivo nell'elenco delle sessioni dell'admin (AriA_Mobile_API.md §3.6).
    var userAgent = AriaConfig.makeUserAgent()
    /// Limite WAF CloudFront. Alzalo quando il backend esenta /v1/responses.
    var maxBodyBytes = 8_000
    /// Silenzio massimo sullo stream prima di considerarlo morto (i tool possono essere lenti).
    var streamIdleTimeout: TimeInterval = 180
    /// `model` per /v1/responses: il modello Bedrock lo sceglie il backend.
    var model = "default"

    static let production = AriaConfig(apiBaseURL: productionAPI, authBaseURL: productionSignIn)

    private static let apiKey = "aria.api_base_url"
    private static let authKey = "aria.auth_base_url"

    /// Server salvati (in DEBUG si possono cambiare dalle impostazioni), altrimenti produzione.
    static var current: AriaConfig {
        #if DEBUG
        let defaults = UserDefaults.standard
        return AriaConfig(
            apiBaseURL: defaults.string(forKey: apiKey).flatMap(URL.init(string:)) ?? productionAPI,
            authBaseURL: defaults.string(forKey: authKey).flatMap(URL.init(string:)) ?? productionSignIn
        )
        #else
        return production
        #endif
    }

    static func saveServers(api: URL?, auth: URL?) {
        UserDefaults.standard.set(api?.absoluteString, forKey: apiKey)
        UserDefaults.standard.set(auth?.absoluteString, forKey: authKey)
    }

    private static func makeUserAgent() -> String {
        let app = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var osVersion = "\(os.majorVersion).\(os.minorVersion)"
        if os.patchVersion > 0 { osVersion += ".\(os.patchVersion)" }
        return "AriaPLT-Mobile/\(app) (iOS \(osVersion); \(deviceModel))"
    }

    /// Identificativo del modello (`iPhone15,2`); sul simulatore quello del dispositivo simulato.
    private static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
}

nonisolated enum AriaError: LocalizedError, Sendable {
    case signedOut
    /// La sessione è salvata ma protetta da Face ID e l'app non l'ha ancora aperta: non è un logout.
    case locked
    /// Login con username: username o password sbagliati (il server non dice quale).
    case invalidCredentials
    /// L'host di accesso non ha questa rotta (accetta solo /api/auth/* e /api/aria/token):
    /// le credenziali non vengono nemmeno verificate.
    case usernameSignInUnavailable
    /// L'host di accesso è un tunnel temporaneo: ha risposto la pagina d'errore di ngrok,
    /// cioè è spento. Non è un problema di credenziali.
    case signInHostOffline
    /// Il sistema non è raggiungibile (tunnel spento, nessuna rete, server giù): non è un errore dell'operatore.
    case serverOffline
    /// 403 `not_a_mobile_user`: il login è valido ma non è quello di un utente mobile.
    case notMobileUser
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
        case .locked: String(localized: "Unlock AriaPLT to continue.")
        case .invalidCredentials: String(localized: "Wrong username or password.")
        case .usernameSignInUnavailable:
            String(localized: "This server doesn't support signing in with a username. Ask your company administrator.")
        case .signInHostOffline:
            String(localized: "The sign-in server is offline. Try again later: your credentials are fine.")
        case .serverOffline:
            String(localized: "Aria is offline. Try again in a moment.")
        case .notMobileUser:
            String(localized: "This login is not a mobile user. Ask your company administrator for a mobile account.")
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
        if http.statusCode == 403, code(from: data) == "not_a_mobile_user" {
            throw AriaError.notMobileUser
        }
        throw AriaError.http(status: http.statusCode, detail: detail(from: data))
    }

    /// Pagina d'errore di ngrok: il tunnel è spento, non è il server ad aver rifiutato.
    /// ngrok marca le sue risposte con `ngrok-error-code`; se mancasse resta l'HTML,
    /// dove il tunnel manda sempre JSON.
    static func tunnelError(_ response: URLResponse) -> AriaError? {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return nil }
        let isNgrokPage = http.value(forHTTPHeaderField: "ngrok-error-code") != nil
            || http.value(forHTTPHeaderField: "Content-Type")?.localizedCaseInsensitiveContains("text/html") == true
        return isNgrokPage ? .signInHostOffline : nil
    }

    /// Risposta di ngrok (c'è sempre `ngrok-error-code`): il tunnel è spento. A differenza di `tunnelError`
    /// non guarda l'HTML, che è anche quello del firewall (403 CloudFront).
    static func isNgrokError(_ response: URLResponse) -> Bool {
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ngrok-error-code") != nil
    }

    /// Il sistema non si raggiunge: tunnel spento, telefono senza rete, server che non risponde.
    static func isOffline(_ error: any Error) -> Bool {
        switch error {
        case AriaError.serverOffline, AriaError.signInHostOffline: return true
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost,
                 .dnsLookupFailed, .timedOut, .internationalRoamingOff, .dataNotAllowed:
                return true
            default: return false
            }
        default: return false
        }
    }

    /// Codice dell'errore: {"code": "…"} oppure annidato in `detail` / `error`.
    static func code(from data: Data) -> String? {
        guard let json = try? JSONDecoder().decode(AriaJSON.self, from: data) else { return nil }
        return (json["code"] ?? json["detail"]?["code"] ?? json["error"]?["code"])?.stringValue
    }

    /// FastAPI: {"detail": "…"} | {"detail": [{"msg": …}]} | {"detail": {"code": …, "message": …}}
    /// aria-backend, HTTPException con testo semplice: {"error": {"message": "…", "code": 403, …}}
    /// better-auth (host di accesso): {"message": "…", "code": "…"} oppure {"error": "…"}
    static func detail(from data: Data) -> String {
        guard let json = try? JSONDecoder().decode(AriaJSON.self, from: data),
              let detail = json["detail"] ?? json["message"] ?? json["error"]?["message"] ?? json["error"] else {
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

    /// `protected`: per leggerlo serve Face ID (o il codice del telefono). Senza codice impostato
    /// la protezione non si può creare e il valore si salva come gli altri.
    static func set(_ value: String, for account: String, protected: Bool = false) {
        SecItemDelete(baseQuery(account) as CFDictionary)
        var item = baseQuery(account)
        item[kSecValueData as String] = Data(value.utf8)
        if protected, let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, nil) {
            item[kSecAttrAccessControl as String] = access
            if SecItemAdd(item as CFDictionary, nil) == errSecSuccess { return }
            item[kSecAttrAccessControl as String] = nil
        }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    /// Un valore protetto si legge solo con un `context` già autenticato (AriaBiometrics.authenticate),
    /// così il sistema non chiede Face ID una seconda volta. Senza `context` non chiede mai nulla:
    /// un valore protetto risulta assente.
    static func get(_ account: String, context: LAContext? = nil) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context ?? silentContext()
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// C'è un valore, protetto o no, senza leggerlo e senza chiedere Face ID.
    static func exists(_ account: String) -> Bool {
        var query = baseQuery(account)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = silentContext()
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private static func silentContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }
}

/// Face ID (o Touch ID, o il codice del telefono) per aprire l'app con una sessione salvata.
nonisolated enum AriaBiometrics {
    /// Il telefono ha un codice: la sessione si può proteggere e l'app chiudere a chiave.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Il metodo che il sistema proporrà per primo (per il testo e l'icona del pulsante).
    static var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Chiede Face ID (con il codice del telefono come riserva). Il contesto restituito
    /// apre i valori protetti del Keychain senza un secondo prompt.
    static func authenticate(reason: String) async throws -> LAContext {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "Use Passcode")
        try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        return context
    }

    /// L'utente ha annullato (o il sistema ha interrotto il prompt): non è un errore da mostrare.
    static func isCancellation(_ error: any Error) -> Bool {
        guard let error = error as? LAError else { return false }
        return [.userCancel, .appCancel, .systemCancel, .notInteractive].contains(error.code)
    }
}
