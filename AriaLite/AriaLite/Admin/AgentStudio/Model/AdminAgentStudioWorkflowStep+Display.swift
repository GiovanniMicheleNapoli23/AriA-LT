//
//  AdminAgentStudioWorkflowStep+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Come si legge un passo nel flusso "How it works": gli identificatori (generate_report,
//  maintainx.create_work_order) diventano frasi, il trigger si presenta come "Starts".
//

import Foundation

nonisolated extension AdminAgentStudioWorkflowStep {
    var isTrigger: Bool { kind == "trigger" }

    /// Il titolo senza underscore e punti: "Maintainx · Create work order".
    var displayTitle: String { Self.humanized(title) }

    /// Il dettaglio, ripulito allo stesso modo; il testo libero (con spazi) resta com'è.
    var displayDetail: String? {
        guard let detail else { return nil }
        // Un nome di file come "report.pdf" non è un identificatore da spezzare.
        if kind == "output", detail.contains(".") { return detail }
        return Self.humanized(detail)
    }

    /// Il titolo nel flusso: il trigger è "Starts" e il suo dettaglio dice quando.
    var flowTitle: String { isTrigger ? String(localized: "Starts") : displayTitle }

    var flowDetail: String? {
        guard isTrigger else { return displayDetail }
        if let displayDetail { return displayDetail }
        return title == String(localized: "Trigger") ? nil : displayTitle
    }

    /// "generate_report" → "Generate report"; "a.b_c" → "A · B c". Se c'è uno spazio o un simbolo
    /// strano è già testo scritto da una persona e non si tocca.
    static func humanized(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-."))
        guard !text.isEmpty, text.unicodeScalars.allSatisfy(allowed.contains) else { return text }
        return text.split(separator: ".")
            .map { sentence(String($0)) }
            .joined(separator: " · ")
    }

    private static func sentence(_ part: String) -> String {
        var spaced = ""
        var previous: Character?
        for character in part {
            if character == "_" || character == "-" {
                spaced.append(" ")
            } else {
                // camelCase: createWorkOrder → create Work Order
                if let previous, previous.isLowercase, character.isUppercase { spaced.append(" ") }
                spaced.append(character)
            }
            previous = character
        }
        let words = spaced.split(separator: " ").map { word -> String in
            // Le sigle (OEE, ERP) restano maiuscole.
            word.count > 1 && word == word.uppercased() ? String(word) : word.lowercased()
        }
        let joined = words.joined(separator: " ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }
}
