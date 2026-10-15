//
//  AriaNetworking.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Configurazione, errori, controllo delle risposte HTTP e Keychain
//  per la connessione al backend Aria (FastAPI aria-backend).
//

import Foundation
import LocalAuthentication
import Security

nonisolated struct AriaConfig: Sendable {
    /// Gli host arrivano da Info.plist (xcconfig); se mancano o non sono validi valgono questi.
    static let productionAPI = infoURL("AriaAPIHost") ?? URL(string: "https://api.ariaplt.com")!
    static let productionWeb = infoURL("AriaWebHost") ?? URL(string: "https://app.ariaplt.com")!
    /// Host di accesso: la web app (aria-web), che serve `/api/auth/mobile/*`, `/api/aria/token` e `/m/sign-in`.
    static let productionSignIn = productionWeb

    /// FastAPI aria-backend: tutti i dati, sotto /v1 (compresi `/v1/companies` e `/v1/mobile/*` dell'operatore).
    var apiBaseURL: URL
    /// Host di accesso: solo login, token di sessione e logout.
    var authBaseURL: URL
    /// Web app Next.js: serve ad aprire i link relativi delle risposte (es. /work-orders/12) nel browser.
    var webBaseURL = AriaConfig.productionWeb
    /// Mandato come X-Aria-Client: solo diagnostica, non è un segreto.
    var clientId = "aria-ios/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")"
    /// `AriaPLT-Mobile/<versione> (<os> <versione os>; <modello>)`: è il nome del dispositivo
    /// nell'elenco delle sessioni che vede l'admin.
    var userAgent = AriaConfig.makeUserAgent()
    /// Limite WAF CloudFront. Alzalo quando il backend esenta /v1/responses.
    var maxBodyBytes = 8_000
    /// Silenzio massimo sullo stream prima di considerarlo morto (i tool possono essere lenti).
    var streamIdleTimeout: TimeInterval = 180
    /// `model` per /v1/responses: il modello Bedrock lo sceglie il backend.
    var model = "default"

    static let production = AriaConfig(apiBaseURL: productionAPI, authBaseURL: productionSignIn)

    /// Chiavi nuove: i server salvati dalle versioni con il tunnel ngrok non devono più valere.
    private static let apiKey = "aria.api_base_url.v2"
    private static let authKey = "aria.auth_base_url.v2"
    private static let legacyKeys = ["aria.api_base_url", "aria.auth_base_url"]

    /// Server salvati (in DEBUG si possono cambiare dalle impostazioni), altrimenti produzione.
    static var current: AriaConfig {
        #if DEBUG
        let defaults = UserDefaults.standard
        legacyKeys.forEach(defaults.removeObject(forKey:))
        return AriaConfig(
            apiBaseURL: defaults.string(forKey: apiKey).flatMap(URL.init(string:)) ?? productionAPI,
            authBaseURL: defaults.string(forKey: authKey).flatMap(URL.init(string:)) ?? productionSignIn
        )
        #else
        return production
        #endif
    }

    #if DEBUG
    static func saveServers(api: URL?, auth: URL?) {
        UserDefaults.standard.set(api?.absoluteString, forKey: apiKey)
        UserDefaults.standard.set(auth?.absoluteString, forKey: authKey)
    }
    #endif

    /// `https://<host>` dall'host scritto in Info.plist sotto `key`; nil se manca o non è valido.
    static func infoURL(_ key: String) -> URL? {
        httpsURL(host: Bundle.main.object(forInfoDictionaryKey: key) as? String)
    }

    /// Solo un host semplice (lettere, cifre, `.` e `-`): niente schema, porta, percorso, credenziali.
    /// Lo schema è sempre https, mai http.
    static func httpsURL(host: String?) -> URL? {
        guard let host, !host.isEmpty,
              host.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        guard components.host == host else { return nil }
        return components.url
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
    /// 401 `INVALID_OR_EXPIRED_LINK`: il link è già stato usato o è scaduto.
    case linkExpired
    /// L'host di accesso non ha le rotte del link (404): non è il server giusto.
    case linkSignInUnavailable
    /// L'host di accesso non risponde (502/503/504 del gateway). Non è un problema del link.
    case signInHostOffline
    /// Il sistema non è raggiungibile (nessuna rete, server giù): non è un errore dell'operatore.
    case serverOffline
    /// 403 `not_a_mobile_user`: il login è valido ma non è quello di un utente mobile.
    case notMobileUser
    case http(status: Int, detail: String)
    /// Il server ha rifiutato un passo o un lavoro con un codice noto (`detail.code`).
    /// `missing`: gli id dei passi senza risultato (`steps_incomplete`).
    case workOrder(AriaServerCode, missing: [String] = [])
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
        case .linkExpired:
            String(localized: "This sign-in link has expired or has already been used. Request a new one.")
        case .linkSignInUnavailable:
            String(localized: "This server doesn't support signing in with an email link. Ask your company administrator.")
        case .signInHostOffline:
            String(localized: "The sign-in server is offline. Try again later.")
        case .serverOffline:
            String(localized: "Aria is offline. Try again in a moment.")
        case .notMobileUser:
            String(localized: "This login is not a mobile user. Ask your company administrator for a mobile account.")
        case .http(let status, let detail): String(localized: "Error \(status): \(detail)")
        case .workOrder(let code, _): code.localized
        case .wafBlocked: String(localized: "Request blocked by the firewall (body over 8 KB).")
        case .bodyTooLarge(let bytes, let limit): String(localized: "Message too long (\(bytes) bytes, limit \(limit)).")
        case .missingCompany: String(localized: "No company selected.")
        case .missingPlant: String(localized: "Select a plant before using the chat.")
        case .decoding(let message): String(localized: "Invalid server response: \(message)")
        case .stream(let message): message
        }
    }
}

/// Codici di `detail.code` delle chiamate /v1/mobile sui passi e sul completamento.
nonisolated enum AriaServerCode: String, Sendable, CaseIterable {
    case stepNotFound = "step_not_found"
    case photoNotFound = "photo_not_found"
    case workOrderClosed = "work_order_closed"
    case stepNotReported = "step_not_reported"
    case photoLimitReached = "photo_limit_reached"
    case photoNotUploaded = "photo_not_uploaded"
    case stepsIncomplete = "steps_incomplete"
    case noteRequired = "note_required"
    case noteTooLong = "note_too_long"
    case unsupportedMediaType = "unsupported_media_type"
    case photoTooLarge = "photo_too_large"
    case resolutionNotesRequired = "resolution_notes_required"
    case storageUnavailable = "storage_unavailable"

    var localized: String {
        switch self {
        case .stepNotFound: String(localized: "This step was removed. The task has been refreshed.")
        case .photoNotFound: String(localized: "This photo no longer exists.")
        case .workOrderClosed: String(localized: "This task is closed and can no longer be changed.")
        case .stepNotReported: String(localized: "Mark the step as done or not done before adding photos.")
        case .photoLimitReached: String(localized: "A step can have at most 3 photos.")
        case .photoNotUploaded: String(localized: "The photo was not uploaded. Try again.")
        case .stepsIncomplete: String(localized: "Every step needs a result before the task can be completed.")
        case .noteRequired: String(localized: "Add a note to explain why the step was not done.")
        case .noteTooLong: String(localized: "The note is too long (2000 characters at most).")
        case .unsupportedMediaType: String(localized: "This photo format is not supported.")
        case .photoTooLarge: String(localized: "The photo is too large (10 MB at most).")
        case .resolutionNotesRequired: String(localized: "Describe what was done before completing the task.")
        case .storageUnavailable: String(localized: "Photo storage is not available on the server.")
        }
    }
}

nonisolated enum AriaHTTP {
    /// Solo per i test (AriaLiteTests): `URLProtocol` che risponde al posto della rete, inseriti in ogni sessione.
    /// Vuoto in produzione.
    nonisolated(unsafe) static var extraProtocolClasses: [AnyClass] = []

    /// Sessione senza cookie: i cookie non si salvano né si mandano mai (solo l'header Authorization).
    static func cookielessSession(_ configuration: URLSessionConfiguration = .ephemeral) -> URLSession {
        configuration.protocolClasses = extraProtocolClasses + (configuration.protocolClasses ?? [])
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }

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
        if let code = code(from: data).flatMap(AriaServerCode.init(rawValue:)) {
            let missing = (try? JSONDecoder().decode(AriaJSON.self, from: data))?["detail"]?["missing"]?
                .arrayValue.compactMap(\.stringValue) ?? []
            throw AriaError.workOrder(code, missing: missing)
        }
        throw AriaError.http(status: http.statusCode, detail: detail(from: data))
    }

    /// Il gateway davanti all'host non raggiunge il server (502/503/504): l'host è giù, non ha rifiutato lui.
    /// Si guarda solo il codice: l'HTML è anche quello del firewall (403 CloudFront) e di un 404 di Next.
    static func isHostDown(_ response: URLResponse) -> Bool {
        guard let status = (response as? HTTPURLResponse)?.statusCode else { return false }
        return [502, 503, 504].contains(status)
    }

    static func hostDownError(_ response: URLResponse) -> AriaError? {
        isHostDown(response) ? .signInHostOffline : nil
    }

    /// Il sistema non si raggiunge: telefono senza rete, server che non risponde.
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
