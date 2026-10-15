//
//  AriaAuthTrace.swift
//  AriaLite
//
//  Created by Giovanni Michele on 08/10/26.
//
//  Solo DEBUG: il percorso del login nella console (Console.app / `log stream`, categoria "auth").
//  Serve a rispondere a due domande: l'app ha davvero provato il login sul server
//  (o si è fermata alle credenziali mock?) e cosa ha risposto la web app.
//
//  Non si scrivono mai password, cookie o token: solo lunghezze, stato HTTP e messaggio d'errore.
//

import Foundation
import OSLog

nonisolated enum AriaAuthTrace {
    #if DEBUG
    private static let log = Logger(subsystem: "com.giovanniMichele.AriaLite", category: "auth")
    #endif

    /// Un passo del flusso, con un dettaglio leggibile (mai segreti).
    static func step(_ phase: StaticString, _ detail: String = "") {
        #if DEBUG
        log.notice("\(phase, privacy: .public) \(detail, privacy: .public)")
        #endif
    }

    /// Risposta della web app: stato, sessione restituita e — solo se è un errore — il corpo.
    /// Il corpo delle risposte riuscite non si scrive: contiene la sessione.
    static func response(_ phase: StaticString, _ response: URLResponse?, _ data: Data) {
        #if DEBUG
        guard let http = response as? HTTPURLResponse else {
            step(phase, "nessuna risposta HTTP")
            return
        }
        var parts = ["status=\(http.statusCode)", "bytes=\(data.count)"]
        if let token = http.value(forHTTPHeaderField: "set-auth-token") {
            parts.append("set-auth-token=\(token.count) caratteri")
        }
        if http.value(forHTTPHeaderField: "Set-Cookie") != nil { parts.append("set-cookie=sì") }
        if let retry = http.value(forHTTPHeaderField: "X-Retry-After") { parts.append("retry-after=\(retry)") }
        if !(200..<300).contains(http.statusCode) {
            parts.append("body=\(String(decoding: data.prefix(300), as: UTF8.self))")
        }
        step(phase, parts.joined(separator: " "))
        #endif
    }

    static func failure(_ phase: StaticString, _ error: any Error) {
        #if DEBUG
        // Sia il tipo (AriaError.invalidCredentials, URLError…) sia il testo mostrato all'utente.
        log.error("\(phase, privacy: .public) \(String(reflecting: error), privacy: .public) — \(error.localizedDescription, privacy: .public)")
        #endif
    }
}
