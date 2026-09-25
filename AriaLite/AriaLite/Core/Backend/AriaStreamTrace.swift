//
//  AriaStreamTrace.swift
//  AriaLite
//
//  Solo DEBUG: i tempi dello stream nella console (Console.app / `log stream`, categoria "stream").
//  `recv` è quando un evento arriva dalla rete, `apply` quando la chat lo mostra: se il testo arriva
//  a blocchi già in `recv` è il server, se `apply` resta indietro è la UI.
//

import OSLog

nonisolated enum AriaStreamTrace {
    #if DEBUG
    private static let log = Logger(subsystem: "com.giovanniMichele.AriaLite", category: "stream")
    #endif

    static func event(_ phase: StaticString, _ name: String, bytes: Int = 0) {
        #if DEBUG
        log.debug("\(phase, privacy: .public) \(name, privacy: .public) \(bytes, privacy: .public)")
        #endif
    }
}
