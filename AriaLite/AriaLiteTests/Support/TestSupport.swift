//
//  TestSupport.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Stato condiviso dei test del backend: ambiente pulito (Keychain, UserDefaults, cookie, rete finta),
//  JWT di prova, JSON d'esempio e la suite madre che li esegue uno alla volta (stato globale condiviso).
//

import Foundation
import Testing
@testable import AriaLite

/// Tutti i test che toccano la rete finta, il Keychain o UserDefaults stanno qui sotto e non girano in parallelo.
@Suite("Backend", .serialized)
struct BackendTests {}

enum TestEnv {
    static let authHost = "app.test"
    static let apiHost = "api.test"

    static let config = AriaConfig(apiBaseURL: URL(string: "https://\(apiHost)")!,
                                   authBaseURL: URL(string: "https://\(authHost)")!)

    static let defaultsKeys = ["aria.company_id", "aria.plant_id", "aria.operator_account", "aria.mobile_account",
                               "aria.install_marker",
                               "aria.magic_link_email", "aria.magic_link_sent_at", "aria.availability_preference",
                               "aria.api_base_url", "aria.auth_base_url",
                               "aria.api_base_url.v2", "aria.auth_base_url.v2"]
    static let keychainAccounts = ["aria.mobile_session", "aria.dev_access_token", "aria.operator_account",
                                   "aria.web_session", "aria.link_session", "aria.link_verifier"]

    /// Ambiente pulito prima di ogni test.
    static func reset() {
        AriaHTTP.extraProtocolClasses = [StubURLProtocol.self]
        StubServer.shared.reset()
        keychainAccounts.forEach(AriaKeychain.delete)
        defaultsKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        if let cookies = HTTPCookieStorage.shared.cookies { cookies.forEach(HTTPCookieStorage.shared.deleteCookie) }
    }

    /// JWT non firmato con `exp`: all'app serve solo la scadenza.
    static func jwt(expiresIn seconds: TimeInterval = 900, tag: String = "a") -> String {
        func b64(_ data: Data) -> String {
            data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        let header = b64(Data(#"{"alg":"none"}"#.utf8))
        let payload = b64(Data(#"{"exp":\#(Int(Date.now.timeIntervalSince1970 + seconds)),"tag":"\#(tag)"}"#.utf8))
        return "\(header).\(payload).sig"
    }

    static func tokenReply(tag: String = "a", headers: [String: String] = [:], delay: TimeInterval = 0) -> Reply {
        .json(#"{"token":"\#(jwt(tag: tag))"}"#, headers: headers, delay: delay)
    }

    static let verifyBody = #"{"token":"SESSION","user":{"id":"u1","name":"Mario Rossi","email":"mario@acme.test"}}"#

    static func verifyReply(session: String = "SESSION") -> Reply {
        .json(verifyBody, headers: ["set-auth-token": session])
    }

    /// Stubba un accesso completo: verify, JWT, aziende e stabilimenti.
    static func stubSignIn(companies: String = #"[{"id":"c1","name":"Acme","myRole":"member"}]"#,
                           plants: Reply = .json(#"[{"id":"p1","name":"Plant 1","code":"P1"}]"#)) {
        let server = StubServer.shared
        server.route("POST /api/auth/mobile/verify", verifyReply())
        server.route("GET /api/aria/token", tokenReply())
        server.route("GET /v1/companies", .json(companies))
        server.route("GET /v1/mobile/plants", plants)
    }

    /// Lo stesso install di prima: il Keychain rimasto è di chi usa l'app, non di una disinstallazione.
    static func markInstalled() {
        UserDefaults.standard.set(true, forKey: "aria.install_marker")
    }

    /// Il link chiesto da questo dispositivo: senza, `completeSignIn` del backend rifiuta ogni link.
    static func requestLink(_ backend: AriaBackend, email: String = "mario@acme.test") async throws {
        StubServer.shared.route("POST /api/auth/mobile/request-link", .json("{}", status: 202))
        try await backend.sendSignInLink(email: email)
    }

    /// Un ordine nel formato di GET /v1/mobile/work-orders.
    static func orderJSON(id: String = "o1", status: String = "assigned", title: String = "Fix", withProcedure: Bool = false,
                          reported: Int = 0, total: Int = 2) -> String {
        let steps = (1...max(total, 1)).map { n in
            let report = n <= reported
                ? #"{"status":"done","note":null,"photos":[],"reportedAt":"2026-10-09T09:12:00.120000Z"}"# : "null"
            return #"{"id":"s\#(n)","number":\#(n),"text":"Step \#(n): Do thing \#(n)","report":\#(report)}"#
        }.joined(separator: ",")
        let procedure = withProcedure
            ? #","procedure":{"steps":[\#(steps)],"safetyWarnings":["LOTO"],"toolsNeeded":[],"partsNeeded":[],"progress":{"done":\#(reported),"notDone":0,"total":\#(total)}}"#
            : ""
        return #"{"id":"\#(id)","title":"\#(title)","status":"\#(status)","priority":"high","progress":{"done":\#(reported),"notDone":0,"total":\#(total)}\#(procedure)}"#
    }

    static func stepJSON(id: String = "s1", status: String? = "done") -> String {
        let report = status.map { #"{"status":"\#($0)","note":null,"photos":[],"reportedAt":"2026-10-09T09:12:00Z"}"# } ?? "null"
        return #"{"id":"\#(id)","number":1,"text":"Step 1","report":\#(report)}"#
    }

    /// Un AriaAuth già con una sessione aperta (verify + JWT passati dalla rete finta).
    static func signedInAuth() async throws -> AriaAuth {
        stubSignIn()
        let auth = AriaAuth(config: config)
        _ = try await auth.completeSignIn(with: AriaSignInLink(token: "t"))
        return auth
    }

    /// Un client già collegato, con Company-Id c1.
    static func signedInClient() async throws -> AriaAPIClient {
        let auth = try await signedInAuth()
        let context = AriaContext()
        await context.setCompany("c1")
        return AriaAPIClient(config: config, auth: auth, context: context)
    }

    /// Backend e store collegati (verify, aziende e stabilimenti stubbati), con la rete finta ripulita dalle chiamate di accesso.
    static func signedInStore() async throws -> (backend: AriaBackend, store: AriaWorkOrderStore) {
        stubSignIn()
        let backend = AriaBackend()
        try await requestLink(backend)
        try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
        return (backend, AriaWorkOrderStore(backend: backend))
    }
}

// MARK: - Aiuti per leggere gli esiti

extension AriaWorkOrderStore.Change {
    var order: AriaWorkOrder? {
        if case .updated(let order) = self { order } else { nil }
    }

    var isGone: Bool {
        if case .gone = self { true } else { false }
    }

    var failureMessage: String? {
        if case .failed(let message) = self { message } else { nil }
    }
}

extension AriaError {
    /// Il codice del server dietro un errore dei passi, se è quello.
    var serverCode: AriaServerCode? {
        if case .workOrder(let code, _) = self { code } else { nil }
    }
}
