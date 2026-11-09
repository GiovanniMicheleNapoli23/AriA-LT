//
//  AdminCraftedTextDiff.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Cosa una versione ha aggiunto e tolto parola per parola (diffText della web): sottosequenza comune
//  più lunga sui token, dopo aver messo da parte inizio e fine uguali. Ogni cambio si legge come una
//  frase tolta seguita da una nuova, non come frammenti alternati.
//

import Foundation

nonisolated enum AdminCraftedTextDiff {
    enum ChangeType: String, Sendable { case same, added, removed }

    nonisolated struct Segment: Hashable, Sendable {
        var type: ChangeType
        var text: String

        init(_ type: ChangeType, _ text: String) {
            self.type = type
            self.text = text
        }

        /// Quante parole contiene (0 se è solo spazio).
        var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }
    }

    /// Oltre queste celle la tabella delle parole è troppo grande per un tasto: si passa alle righe.
    private static let maxCells = 2_500_000

    static func diff(before: String, after: String) -> [Segment] {
        if before == after { return before.isEmpty ? [] : [Segment(.same, before)] }
        var a = tokenize(before)
        var b = tokenize(after)
        if a.count * b.count > maxCells * 4 {
            a = lines(before)
            b = lines(after)
        }
        return merge(lcsDiff(a, b))
    }

    /// Parole e spazi fra loro, così il diff rimette la spaziatura com'era.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentIsSpace = false
        for character in text {
            let isSpace = character.isWhitespace
            if !current.isEmpty, isSpace != currentIsSpace {
                tokens.append(current)
                current = ""
            }
            current.append(character)
            currentIsSpace = isSpace
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Righe con il loro a capo in fondo.
    private static func lines(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == "\n" || character == "\r\n" {
                out.append(current)
                current = ""
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    private static func lcsDiff(_ a: [String], _ b: [String]) -> [Segment] {
        var start = 0
        while start < a.count, start < b.count, a[start] == b[start] { start += 1 }
        var endA = a.count
        var endB = b.count
        while endA > start, endB > start, a[endA - 1] == b[endB - 1] {
            endA -= 1
            endB -= 1
        }
        let head = a[..<start].map { Segment(.same, $0) }
        let tail = a[endA...].map { Segment(.same, $0) }
        let x = Array(a[start..<endA])
        let y = Array(b[start..<endB])
        let n = x.count
        let m = y.count

        // Ancora troppo grande dopo il taglio: tutto sostituito, invece di bloccarsi.
        if n * m > maxCells {
            return head + x.map { Segment(.removed, $0) } + y.map { Segment(.added, $0) } + tail
        }

        // Confronto fra interi: i token si numerano una volta sola.
        var ids: [String: Int] = [:]
        func id(_ token: String) -> Int {
            if let known = ids[token] { return known }
            ids[token] = ids.count
            return ids.count - 1
        }
        let xs = x.map(id)
        let ys = y.map(id)

        // lengths[i][j] = LCS di x[i...] e y[j...], appiattita.
        let width = m + 1
        var lengths = [UInt32](repeating: 0, count: (n + 1) * width)
        if n > 0, m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    lengths[i * width + j] = xs[i] == ys[j]
                        ? lengths[(i + 1) * width + j + 1] + 1
                        : max(lengths[(i + 1) * width + j], lengths[i * width + j + 1])
                }
            }
        }
        var middle: [Segment] = []
        var i = 0
        var j = 0
        while i < n, j < m {
            if xs[i] == ys[j] {
                middle.append(Segment(.same, x[i]))
                i += 1
                j += 1
            } else if lengths[(i + 1) * width + j] >= lengths[i * width + j + 1] {
                middle.append(Segment(.removed, x[i]))
                i += 1
            } else {
                middle.append(Segment(.added, y[j]))
                j += 1
            }
        }
        while i < n { middle.append(Segment(.removed, x[i])); i += 1 }
        while j < m { middle.append(Segment(.added, y[j])); j += 1 }
        return head + middle + tail
    }

    /// Ogni cambio come una frase tolta e una nuova. Uno spazio solo fra due cambi appartiene a entrambi.
    private static func merge(_ segments: [Segment]) -> [Segment] {
        var out: [Segment] = []
        var removed = ""
        var added = ""
        func flush() {
            if !removed.isEmpty { out.append(Segment(.removed, removed)) }
            if !added.isEmpty { out.append(Segment(.added, added)) }
            removed = ""
            added = ""
        }
        for (k, segment) in segments.enumerated() {
            let inChange = !removed.isEmpty || !added.isEmpty
            let next = k + 1 < segments.count ? segments[k + 1] : nil
            switch segment.type {
            case .removed:
                removed += segment.text
            case .added:
                added += segment.text
            case .same:
                if inChange, isBlank(segment.text), let next, next.type != .same {
                    removed += segment.text
                    added += segment.text
                } else {
                    flush()
                    if let last = out.last, last.type == .same {
                        out[out.count - 1].text += segment.text
                    } else {
                        out.append(Segment(.same, segment.text))
                    }
                }
            }
        }
        flush()
        return out
    }

    /// Solo spazi e tabulazioni (`/^[ \t]+$/` della web).
    private static func isBlank(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0 == " " || $0 == "\t" }
    }
}

/// Quanto una versione ha cambiato rispetto a un'altra, per la sua riga nella cronologia.
nonisolated struct AdminCraftedChangeCount: Hashable, Sendable {
    var added = 0
    var removed = 0
    var cells = 0

    var isEmpty: Bool { added == 0 && removed == 0 && cells == 0 }

    /// Somma le parole aggiunte e tolte di un diff.
    mutating func add(_ segments: [AdminCraftedTextDiff.Segment]) {
        for segment in segments {
            switch segment.type {
            case .added: added += segment.wordCount
            case .removed: removed += segment.wordCount
            case .same: break
            }
        }
    }
}
