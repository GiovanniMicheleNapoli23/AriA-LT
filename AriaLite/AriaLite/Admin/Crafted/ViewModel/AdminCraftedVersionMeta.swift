//
//  AdminCraftedVersionMeta.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Chi ha salvato una versione, quando e come si legge: i testi di authorOf, editedLine e summaryOf della
//  web. Vale per le versioni degli artifact e per quelle dei report: la cronologia e il confronto li
//  leggono da qui, senza sapere di quale delle due si tratta.
//

import Foundation

nonisolated struct AdminCraftedVersionMeta: Hashable, Sendable {
    let number: Int
    let createdAt: Date
    let author: String?
    let kind: AdminCraftedVersionKind
    let restoredFrom: Int?
    let via: AdminCraftedAriaRequest?

    init(_ version: AdminCraftedArtifactVersion) {
        self.init(number: version.number, createdAt: version.createdAt, author: version.author, kind: version.kind,
                  restoredFrom: version.restoredFrom, via: version.via)
    }

    init(_ version: AdminCraftedReportVersion) {
        self.init(number: version.number, createdAt: version.createdAt, author: version.author, kind: version.kind,
                  restoredFrom: version.restoredFrom, via: version.via)
    }

    init(number: Int, createdAt: Date, author: String?, kind: AdminCraftedVersionKind, restoredFrom: Int?, via: AdminCraftedAriaRequest?) {
        self.number = number
        self.createdAt = createdAt
        self.author = author
        self.kind = kind
        self.restoredFrom = restoredFrom
        self.via = via
    }

    // MARK: Testi

    /// "v3".
    static func label(_ number: Int) -> String { String(localized: "v\(number)") }

    static func when(_ date: Date) -> String { date.formatted(date: .abbreviated, time: .shortened) }

    private static var someone: String { String(localized: "Someone") }

    /// Di chi è: una persona, o Aria per conto di qualcuno.
    var authorName: String {
        guard let via else { return author ?? Self.someone }
        return String(localized: "Aria, for \(via.requestedBy ?? Self.someone)")
    }

    /// "Marco · 23 ott, 10:45".
    var byline: String { "\(authorName) · \(Self.when(createdAt))" }

    /// La riga sopra un documento letto come modificato: quale versione, di chi, quando.
    var editedLine: String {
        let when = Self.when(createdAt)
        if let via {
            return String(localized: "version \(number) by Aria, asked by \(via.requestedBy ?? Self.someone): “\(via.instruction)”, \(when)")
        }
        let name = author ?? Self.someone
        if kind == .restore {
            return String(localized: "version \(number): \(name) restored v\(restoredFrom ?? 1), \(when)")
        }
        return String(localized: "version \(number) by \(name), \(when)")
    }

    /// "+12 −4 parole · 2 celle", oppure che non è cambiato niente.
    static func summary(of count: AdminCraftedChangeCount) -> String {
        var pieces: [String] = []
        if count.added > 0 || count.removed > 0 {
            pieces.append(String(localized: "+\(count.added) −\(count.removed) words"))
        }
        if count.cells == 1 {
            pieces.append(String(localized: "1 cell"))
        } else if count.cells > 1 {
            pieces.append(String(localized: "\(count.cells) cells"))
        }
        return pieces.isEmpty ? String(localized: "No changes") : pieces.joined(separator: " · ")
    }
}
