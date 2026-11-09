//
//  AriaElicitationTurn.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come le risposte a una domanda guidata diventano il turno di chat, come fa la web
//  (buildAnswer / composeClosureAnswer / assembleChatTurn).
//

import Foundation

enum AriaElicitationTurn {
    /// buildAnswer della web: la risposta di un passo dalle opzioni scelte e dal testo scritto.
    static func answer(mode: String?, picked: [String], typed: String) -> String {
        switch mode {
        case "rank" where !picked.isEmpty:
            let ranked = picked.enumerated().map { "\($0.offset + 1)) \($0.element)" }.joined(separator: ", ")
            let prefix = String(localized: "In order of priority")
            return typed.isEmpty ? "\(prefix): \(ranked)" : "\(prefix): \(ranked). \(typed)"
        case "multi" where !picked.isEmpty:
            let joined = picked.joined(separator: ", ")
            return typed.isEmpty ? joined : "\(joined). \(typed)"
        default:
            if !typed.isEmpty { return picked.first.map { "\($0). \(typed)" } ?? typed }
            return picked.first ?? ""
        }
    }

    /// composeClosureAnswer della web: l'etichetta canonica resta in testa (il server riconosce il consenso
    /// dall'inizio del messaggio), poi il codice del motivo in inglese e le parole dell'operatore, mai tradotte.
    static func closureAnswer(label: String, reason: String, details: String) -> String {
        var parts = [label.trimmingCharacters(in: .whitespacesAndNewlines).trimmingSuffix(".")]
        let code = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !code.isEmpty { parts.append("Reason: \(code)") }
        let note = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { parts.append("Details: \(note)") }
        return parts.joined(separator: ". ")
    }

    /// assembleChatTurn della web: i passi con `file` non vanno nel turno di chat.
    static func assemble(steps: [AriaElicitationStep], answers: [String], intro: String?) -> String {
        let pairs = zip(steps, answers).filter { $0.0.file == nil }
        let lines = pairs.map { ($0.0, $0.1.trimmingCharacters(in: .whitespacesAndNewlines)) }.filter { !$0.1.isEmpty }
        guard !lines.isEmpty else { return "" }
        if lines.count == 1, pairs.count == 1 { return lines[0].1 }
        let body = lines.map { step, answer in
            let topic = step.topic?.trimmingCharacters(in: .whitespaces)
            return "- \(topic?.isEmpty == false ? topic! : step.question): \(answer)"
        }.joined(separator: "\n")
        if let lead = intro?.trimmingCharacters(in: .whitespacesAndNewlines), !lead.isEmpty { return "\(lead)\n\(body)" }
        return body
    }
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String { hasSuffix(suffix) ? String(dropLast(suffix.count)) : self }
}
