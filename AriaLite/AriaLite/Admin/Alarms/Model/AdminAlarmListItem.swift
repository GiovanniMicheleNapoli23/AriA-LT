//
//  AdminAlarmListItem.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga di un elenco modificabile nel modulo (una causa, un passo): l'id serve solo a lista e fuoco,
//  non va al server.
//

import Foundation

nonisolated struct AdminAlarmListItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    /// Le righe di un elenco come voci del modulo.
    static func items(_ lines: [String]) -> [Self] { lines.map { Self(text: $0) } }

    /// Il testo delle voci, senza spazi attorno e senza righe vuote.
    static func lines(_ items: [Self]) -> [String] {
        items.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
