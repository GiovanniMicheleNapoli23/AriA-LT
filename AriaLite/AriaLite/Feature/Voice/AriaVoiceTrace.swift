//
//  AriaVoiceTrace.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Solo DEBUG: lo stato della sessione vocale nella console (Console.app / `log stream`, categoria "voice").
//
//  Si scrivono solo tipi di evento, stati e stato HTTP. Mai chiavi o token (nemmeno un prefisso),
//  corpi delle risposte riuscite, trascrizioni, argomenti delle funzioni o testo del RAG.
//

import Foundation
import OSLog

nonisolated enum AriaVoiceTrace {
    #if DEBUG
    private static let log = Logger(subsystem: "com.giovanniMichele.AriaLite", category: "voice")
    #endif

    /// Un passo del flusso, con un dettaglio leggibile (mai segreti).
    static func step(_ phase: StaticString, _ detail: String = "") {
        #if DEBUG
        log.notice("\(phase, privacy: .public) \(detail, privacy: .public)")
        #endif
    }

    /// Risposta di Aria Engine: stato e dimensione. Il corpo si scrive solo se è un errore:
    /// quello di /token riuscito contiene la chiave effimera.
    static func response(_ phase: StaticString, _ response: HTTPURLResponse, _ data: Data) {
        #if DEBUG
        var parts = ["status=\(response.statusCode)", "bytes=\(data.count)"]
        if response.statusCode != 200 {
            parts.append("body=\(String(decoding: data.prefix(200), as: UTF8.self))")
        }
        step(phase, parts.joined(separator: " "))
        #endif
    }

    /// Solo tipo, dominio e codice dell'errore: il testo può citare URL o risposte del server.
    static func failure(_ phase: StaticString, _ error: any Error) {
        #if DEBUG
        let nsError = error as NSError
        log.error("\(phase, privacy: .public) \(String(describing: type(of: error)), privacy: .public) \(nsError.domain, privacy: .public)#\(nsError.code, privacy: .public)")
        #endif
    }
}
