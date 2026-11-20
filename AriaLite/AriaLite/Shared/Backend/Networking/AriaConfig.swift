//
//  AriaConfig.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Gli indirizzi del backend Aria (host dei dati, di accesso e web), gli header che identificano l'app e i
//  limiti della connessione. In DEBUG i server si possono cambiare dalle impostazioni.
//

import Foundation

nonisolated struct AriaConfig: Sendable {
    /// Gli host arrivano da Info.plist (xcconfig); se mancano o non sono validi valgono questi.
    static let productionAPI = infoURL("AriaAPIHost") ?? URL(string: "https://api.ariaplt.com")!
    static let productionWeb = infoURL("AriaWebHost") ?? URL(string: "https://app.ariaplt.com")!
    /// Host di accesso: la web app (aria-web), che serve `/api/auth/mobile/*`, `/api/aria/token` e `/m/sign-in`.
    static let productionSignIn = productionWeb

    /// FastAPI aria-backend: tutti i dati, sotto /v1. Le rotte `/v1/mobile/*` non esistono più: l'operatore usa quelle condivise.
    var apiBaseURL: URL
    /// Host di accesso: solo login, token di sessione e logout.
    var authBaseURL: URL
    /// Web app Next.js: serve ad aprire i link relativi delle risposte (es. /work-orders/12) nel browser.
    var webBaseURL = AriaConfig.productionWeb
    /// Chiave pubblica Cloudflare Turnstile della web: il captcha serve a mandare il magic link e il link d'iscrizione.
    /// La chiave accetta solo i domini della web: il widget si carica con l'origine di `webBaseURL`.
    var turnstileSiteKey = "0x4AAAAAADF3cO-EJy4kf-nF"
    /// Mandato come X-Aria-Client: solo diagnostica, non è un segreto.
    var clientId = "aria-ios/\(AriaConfig.appVersion)"
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

    private static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

    private static func makeUserAgent() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var osVersion = "\(os.majorVersion).\(os.minorVersion)"
        if os.patchVersion > 0 { osVersion += ".\(os.patchVersion)" }
        return "AriaPLT-Mobile/\(appVersion) (iOS \(osVersion); \(deviceModel))"
    }

    /// Identificativo del modello (`iPhone15,2`); sul simulatore quello del dispositivo simulato.
    private static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
}
