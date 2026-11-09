//
//  AdminCraftedAriaSplitter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un testo troppo lungo per una richiesta, tagliato (splitText di edit-with-aria.ts): ai capoversi, se no
//  alle frasi, se no a forza; e le modifiche fatte ai pezzi rimesse insieme come modifiche al blocco da
//  cui vengono (joinPieces). Le misure sono in byte UTF-8.
//

import Foundation

/// Un blocco di testo tagliato in pezzi: gli id dei pezzi (`<id>~0`, `<id>~1`…) e i loro testi, in ordine.
nonisolated struct AdminCraftedAriaPieces: Hashable, Sendable {
    let blockId: String
    let ids: [String]
    let texts: [String]
}

nonisolated enum AdminCraftedAriaSplitter {
    /// Il testo in pezzi di al più `budget` byte.
    static func split(_ text: String, budget: Int) -> [String] {
        var out: [String] = []
        var current = ""
        func push(_ piece: String, _ separator: String) {
            let joined = current.isEmpty ? piece : current + separator + piece
            if joined.utf8.count <= budget {
                current = joined
            } else {
                if !current.isEmpty { out.append(current) }
                current = piece
            }
        }
        // Il taglio a forza: un pezzo di scalari che sta di sicuro nel budget (al più 4 byte l'uno).
        let chunk = max(1, budget / 4)
        for paragraph in paragraphs(text) {
            if paragraph.utf8.count <= budget {
                push(paragraph, "\n\n")
                continue
            }
            for sentence in sentences(paragraph) {
                var rest = sentence
                while rest.utf8.count > budget {
                    let scalars = rest.unicodeScalars
                    let cut = scalars.index(scalars.startIndex, offsetBy: chunk)
                    push(String(scalars[..<cut]), " ")
                    rest = String(scalars[cut...])
                }
                push(rest, " ")
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    /// `text.split(/\n{2,}/)`: i capoversi, senza le righe vuote che li separano.
    static func paragraphs(_ text: String) -> [String] {
        var out: [String] = []
        var current = String.UnicodeScalarView()
        var newlines = 0
        for scalar in text.unicodeScalars {
            if scalar == "\n" {
                newlines += 1
                continue
            }
            if newlines == 1 { current.append("\n") }
            if newlines >= 2 {
                out.append(String(current))
                current = String.UnicodeScalarView()
            }
            newlines = 0
            current.append(scalar)
        }
        if newlines == 1 { current.append("\n") }
        out.append(String(current))
        return out
    }

    /// `text.split(/(?<=[.!?;:])\s+/)`: si taglia dove uno spazio segue la punteggiatura.
    static func sentences(_ text: String) -> [String] {
        let stops: Set<Unicode.Scalar> = [".", "!", "?", ";", ":"]
        var out: [String] = []
        var current = String.UnicodeScalarView()
        var previous: Unicode.Scalar?
        var inCut = false
        for scalar in text.unicodeScalars {
            if inCut {
                if scalar.properties.isWhitespace { continue }
                inCut = false
            }
            if scalar.properties.isWhitespace, let last = previous, stops.contains(last) {
                out.append(String(current))
                current = String.UnicodeScalarView()
                inCut = true
                previous = nil
                continue
            }
            current.append(scalar)
            previous = scalar
        }
        out.append(String(current))
        return out
    }

    // MARK: Rimettere insieme

    /// Le modifiche ai pezzi come modifiche al blocco intero: un pezzo non toccato resta com'era.
    static func join(_ changes: [AdminCraftedAriaChange], pieces: [AdminCraftedAriaPieces]) -> [AdminCraftedAriaChange] {
        guard !pieces.isEmpty else { return changes }
        let byId = Dictionary(changes.map { ($0.id, $0) }) { _, last in last }
        var out = changes.filter { !$0.id.contains("~") }
        for entry in pieces where entry.ids.contains(where: { byId[$0] != nil }) {
            let joined = entry.ids.enumerated().map { index, pieceId -> String in
                if case .text(_, let text)? = byId[pieceId] { return text }
                return entry.texts[index]
            }.joined(separator: "\n\n")
            out.append(.text(id: entry.blockId, text: joined))
        }
        return out
    }
}
