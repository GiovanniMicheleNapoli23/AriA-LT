//
//  AriaPanelDedup.swift
//  AriaLite
//
//  Il modello spesso riscrive nel testo quello che arriva anche come pannello:
//  le opzioni della domanda guidata ("A. … B. …") e i task della checklist.
//  Qui si tolgono dal testo quegli elenchi (e la riga che li introduce),
//  così la risposta non ripete il pannello in basso.
//

import Foundation

enum AriaPanelDedup {
    /// - options: etichette (e descrizioni) delle opzioni della domanda guidata.
    /// - tasks: testi dei task della checklist.
    /// - headings: titoli che, subito prima di un elenco tolto, restano orfani (es. il titolo dello step).
    static func strip(_ text: String, options: [String], tasks: [String], headings: [String] = []) -> String {
        let targets = (options + tasks).map(tokens).filter { !$0.isEmpty }
        guard !targets.isEmpty else { return text }
        let headingTokens = headings.map(tokens).filter { !$0.isEmpty }

        var lines = text.components(separatedBy: "\n")
        var remove = IndexSet()
        var inFence = false
        var i = 0

        while i < lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") { inFence.toggle(); i += 1; continue }
            guard !inFence, let first = listItem(lines[i]) else { i += 1; continue }

            // Un blocco = elementi consecutivi (anche separati da righe vuote) più le righe rientrate di continuazione.
            var items = [first.text]
            var lettered = first.lettered ? 1 : 0
            var end = i
            var j = i + 1
            while j < lines.count {
                let line = lines[j]
                if let item = listItem(line) {
                    items.append(item.text)
                    if item.lettered { lettered += 1 }
                    end = j
                } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Riga vuota: il blocco continua solo se dopo c'è un altro elemento.
                    var k = j + 1
                    while k < lines.count, lines[k].trimmingCharacters(in: .whitespaces).isEmpty { k += 1 }
                    guard k < lines.count, listItem(lines[k]) != nil else { break }
                } else if continues(line, after: lines[j - 1]) {
                    items[items.count - 1] += " " + line
                    end = j
                } else {
                    break
                }
                j += 1
            }

            let matched = items.filter { item in
                let itemTokens = tokens(item)
                return targets.contains { covers($0, itemTokens) }
            }.count
            // Le opzioni scritte come "A. B. C." sono quasi sempre la domanda ripetuta.
            let letteredOptions = !options.isEmpty && lettered == items.count && items.count >= 2
                && abs(items.count - options.count) <= 1
            if letteredOptions || (matched > 0 && matched * 2 >= items.count) {
                remove.insert(integersIn: i...end)
                if let lead = leadIn(before: i, in: lines, headings: headingTokens) { remove.insert(lead) }
            }
            i = end + 1
        }

        guard !remove.isEmpty else { return text }
        removeEmptiedHeadings(in: lines, removed: &remove)
        for index in remove.reversed() { lines.remove(at: index) }
        var out = lines.joined(separator: "\n")
        while out.contains("\n\n\n") { out = out.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Un titolo ("### Tasks", "**Tasks**") subito sopra un elenco tolto: resterebbe orfano.
    private static func removeEmptiedHeadings(in lines: [String], removed: inout IndexSet) {
        for index in lines.indices where !removed.contains(index) && isHeading(lines[index]) {
            var next = index + 1
            while next < lines.count, !removed.contains(next), lines[next].trimmingCharacters(in: .whitespaces).isEmpty {
                next += 1
            }
            if next < lines.count, removed.contains(next) { removed.insert(index) }
        }
    }

    private static func isHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") { return true }
        return trimmed.range(of: #"^(\*\*|__)[^*_]+(\*\*|__):?$"#, options: .regularExpression) != nil
    }

    // MARK: - Elenchi

    private static let marker = try! NSRegularExpression(pattern: #"^\s*(?:[-*+•]\s+)?(?:(\d{1,2})[.)]|([A-Ha-h])[.)]|\(([A-Ha-h])\)|[-*+•])\s+(.+)$"#)

    private static func listItem(_ raw: String) -> (text: String, lettered: Bool)? {
        let line = raw.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
        let range = NSRange(line.startIndex..., in: line)
        guard let match = marker.firstMatch(in: line, range: range),
              let body = Range(match.range(at: 4), in: line) else { return nil }
        let lettered = match.range(at: 2).location != NSNotFound || match.range(at: 3).location != NSNotFound
        return (String(line[body]), lettered)
    }

    /// Continuazione dell'elemento: rientrata, o attaccata alla riga sopra (continuazione "pigra" del Markdown).
    private static func continues(_ line: String, after previous: String) -> Bool {
        if line.hasPrefix("  ") || line.hasPrefix("\t") { return true }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !previous.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return !trimmed.hasPrefix("#") && !trimmed.hasPrefix("```") && !trimmed.hasPrefix("|") && !trimmed.hasPrefix(">")
    }

    /// La riga che presenta l'elenco ("Dimmi quale vale:", "Cosa vedi sull'HMI?") o il titolo dello step.
    private static func leadIn(before index: Int, in lines: [String], headings: [Set<String>]) -> Int? {
        var k = index - 1
        while k >= 0, lines[k].trimmingCharacters(in: .whitespaces).isEmpty { k -= 1 }
        guard k >= 0, listItem(lines[k]) == nil else { return nil }
        let line = lines[k].replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        if line.hasSuffix(":") || line.hasSuffix("?") { return k }
        let lineTokens = tokens(line)
        return headings.contains(where: { covers($0, lineTokens) }) ? k : nil
    }

    // MARK: - Confronto

    private static let stopwords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "of", "on", "in", "to", "and", "or", "it", "its", "be", "has", "have", "with", "for", "at", "by", "i",
        "il", "lo", "la", "le", "gli", "un", "una", "uno", "di", "da", "del", "della", "dei", "e", "o", "è", "che", "per", "con", "su", "sul", "sulla", "ha",
    ]

    private static func tokens(_ text: String) -> Set<String> {
        let plain = text.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        let words = plain.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(words.filter { !$0.isEmpty && !stopwords.contains($0) })
    }

    /// Le parole di `target` stanno (quasi tutte) nell'elemento: "F120 active, dryer stopped"
    /// copre "F120 is active on the HMI, dryer is stopped".
    private static func covers(_ target: Set<String>, _ item: Set<String>) -> Bool {
        let hits = target.filter { word in item.contains { same(word, $0) } }.count
        if target.count == 1 { return hits == 1 && item.count <= 3 }
        return hits >= 2 && Double(hits) / Double(target.count) >= 0.6
    }

    /// Stessa parola, o una radice dell'altra ("stop" / "stopped").
    private static func same(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let (short, long) = a.count <= b.count ? (a, b) : (b, a)
        return short.count >= 4 && long.hasPrefix(short)
    }
}
