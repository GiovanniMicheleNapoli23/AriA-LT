//
//  AriaHTTP.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Le sessioni senza cookie né cache, la lettura delle risposte HTTP in AriaError, il riconoscimento di un
//  host giù o di un telefono offline e la guardia sui redirect (AriaRedirectGuard).
//

import Foundation

nonisolated enum AriaHTTP {
    /// Solo per i test (AriaLiteTests): `URLProtocol` che risponde al posto della rete, inseriti in ogni sessione.
    /// Vuoto in produzione.
    nonisolated(unsafe) static var extraProtocolClasses: [AnyClass] = []

    /// Sessione senza cookie: i cookie non si salvano né si mandano mai (solo l'header Authorization).
    /// Niente cache su disco (le risposte sono dati dell'azienda) e redirect filtrati da `AriaRedirectGuard`.
    static func cookielessSession(_ configuration: URLSessionConfiguration = .ephemeral) -> URLSession {
        configuration.protocolClasses = extraProtocolClasses + (configuration.protocolClasses ?? [])
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: AriaRedirectGuard.shared, delegateQueue: nil)
    }

    /// Una risposta fuori da 2xx diventa l'AriaError del suo codice. L'ordine dei controlli conta: il firewall
    /// prima dei codici, i rifiuti dei diritti prima di quelli delle persone e dell'uso.
    static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        let status = http.statusCode
        guard !(200..<300).contains(status) else { return }
        // Il corpo si legge una volta sola.
        let json = try? JSONDecoder().decode(AriaJSON.self, from: data)
        let errorCode = json.flatMap(code(in:))
        let serverDetail = json?["detail"]
        // 402 al tetto di spesa: `{"error":{"type":"spend_cap_reached","code":402}}`. Il `code` qui è il NUMERO 402,
        // quindi si legge `error.type`.
        if status == 402, json?["error"]?["type"]?.stringValue == "spend_cap_reached" {
            throw AriaError.spendCapReached(detail(from: data))
        }
        if status == 403 {
            if (http.value(forHTTPHeaderField: "Server") ?? "").localizedCaseInsensitiveContains("cloudfront") {
                throw AriaError.wafBlocked
            }
            switch errorCode {
            case "not_a_mobile_user": throw AriaError.notMobileUser
            case "operation_forbidden": throw AriaError.notOnPhone
            case "session_ended": throw AriaError.sessionEnded
            default: break
            }
            if let denial = AriaPermissionDenial(data) { throw AriaError.permissionDenied(denial) }
        }
        if let refusal = errorCode.flatMap(AriaAccessRefusal.init(rawValue:)) {
            throw AriaError.accessRefused(refusal)
        }
        // Mai su un 403: `membership_suspended` lì è il rifiuto dei diritti (Agent Studio), non quello delle persone.
        if status != 403 {
            if let refusal = errorCode.flatMap(AriaPeopleRefusal.init(rawValue:)) {
                throw AriaError.peopleRefused(refusal, detail: detail(from: data))
            }
            if let refusal = AriaUsageRefusal(data) { throw AriaError.usageRefused(refusal) }
        }
        if status == 409, let conflict = AriaTurnConflict(data) {
            throw AriaError.turnConflict(conflict)
        }
        if status == 422, let field = serverDetail?["field"]?.stringValue, let valid = serverDetail?["valid"]?.arrayValue {
            throw AriaError.invalidChoice(field: field, valid: valid.compactMap(\.stringValue),
                                          message: serverDetail?["message"]?.stringValue ?? detail(from: data))
        }
        if let serverCode = errorCode.flatMap(AriaServerCode.init(rawValue:)) {
            let missing = serverDetail?["missing"]?.arrayValue.compactMap(\.stringValue) ?? []
            throw AriaError.workOrder(serverCode, missing: missing)
        }
        throw AriaError.http(status: status, detail: detail(from: data))
    }

    /// Il gateway davanti all'host non raggiunge il server (502/503/504): l'host è giù, non ha rifiutato lui.
    /// Si guarda il codice, non l'HTML (è anche quello del firewall, 403 CloudFront, e di un 404 di Next). Con il
    /// body, un JSON con `detail` vuol dire che ha risposto il backend (502 `gateway_rejected` di Composio, 503 di
    /// un servizio non configurato): non è un host giù, il messaggio va mostrato.
    static func isHostDown(_ response: URLResponse, body: Data? = nil) -> Bool {
        guard let status = (response as? HTTPURLResponse)?.statusCode, [502, 503, 504].contains(status) else { return false }
        guard let body, let json = try? JSONDecoder().decode(AriaJSON.self, from: body) else { return true }
        return json["detail"] == nil
    }

    static func hostDownError(_ response: URLResponse, body: Data? = nil) -> AriaError? {
        isHostDown(response, body: body) ? .signInHostOffline : nil
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
        (try? JSONDecoder().decode(AriaJSON.self, from: data)).flatMap(code(in:))
    }

    private static func code(in json: AriaJSON) -> String? {
        (json["code"] ?? json["detail"]?["code"] ?? json["error"]?["code"])?.stringValue
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

/// Redirect delle sessioni dell'app: mai verso http, e verso un altro host senza le credenziali
/// (URLSession copierebbe Authorization, Company-Id e Cookie sulla richiesta nuova).
/// Un delegate del singolo task (es. `NoRedirect` di AriaAuth) ha la precedenza.
nonisolated final class AriaRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = AriaRedirectGuard()

    static let credentialHeaders = ["Authorization", "Company-Id", "Cookie"]

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(Self.redirect(request, from: task.originalRequest))
    }

    /// La richiesta da seguire, o `nil` per fermarsi sulla risposta 3xx.
    static func redirect(_ new: URLRequest, from original: URLRequest?) -> URLRequest? {
        guard let url = new.url, url.scheme?.lowercased() == "https" else { return nil }
        if let host = original?.url?.host()?.lowercased(), url.host()?.lowercased() == host { return new }
        var stripped = new
        for header in credentialHeaders { stripped.setValue(nil, forHTTPHeaderField: header) }
        return stripped
    }
}
