//
//  AriaLocaleFormatterCache.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Tiene i formattatori già pronti per lingua e formato: crearne uno per ogni etichetta di un grafico o di una
//  lista costa molto. La chiave contiene l'identificatore della lingua letto a ogni richiesta, quindi un cambio
//  di lingua o di regione dà un formattatore nuovo. Si usa da qualsiasi thread (i formattatori di Foundation
//  leggono in modo sicuro una volta configurati; la configurazione avviene sotto il blocco, prima di condividerli).
//

import Foundation

nonisolated final class AriaLocaleFormatterCache<Format: Formatter>: @unchecked Sendable {
    private let lock = NSLock()
    private var formatters: [String: Format] = [:]

    /// Il formattatore per `variant` (il formato scelto) e `locale`; `make` lo crea e lo configura solo la prima volta.
    func formatter(variant: String, locale: Locale, make: () -> Format) -> Format {
        let key = "\(locale.identifier)|\(variant)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = formatters[key] { return cached }
        let created = make()
        formatters[key] = created
        return created
    }
}
