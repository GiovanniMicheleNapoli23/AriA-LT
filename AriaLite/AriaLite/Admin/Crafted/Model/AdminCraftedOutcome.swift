//
//  AdminCraftedOutcome.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Cosa una conversazione è, come artifact (outcomeOf di generate-artifact.ts e titleFrom di
//  crafted-artifacts.ts): tutti i deliverable prodotti dalle risposte di Aria, oppure l'ultima risposta
//  — il risultato scritto a parole, o una domanda a cui rispondere in chat.
//

import Foundation

nonisolated struct AdminCraftedOutcome: Sendable {
    var status: AdminCraftedArtifactStatus
    var artifacts: [AriaArtifact]
    var note: String?
    /// Il nome per la riga, se la risposta ne dà uno; altrimenti resta quello della richiesta.
    var title: String?

    /// Il risultato di un turno o di una conversazione riletta dal server.
    @MainActor
    static func of(_ messages: [AriaAgentMessage]) -> AdminCraftedOutcome {
        let answers = messages.filter { $0.role == .assistant }
        var seen = Set<String>()
        var artifacts: [AriaArtifact] = []
        for message in answers {
            for artifact in message.artifacts where artifact.isDeliverable && seen.insert(artifact.id).inserted {
                artifacts.append(artifact)
            }
        }
        if !artifacts.isEmpty {
            let named = artifacts.lazy.compactMap { artifact -> String? in
                guard case .string(let title)? = artifact.data["title"] else { return nil }
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }.first
            return AdminCraftedOutcome(status: .ready, artifacts: artifacts, note: nil, title: named)
        }
        guard let last = answers.last else {
            return AdminCraftedOutcome(status: .failed, artifacts: [], note: nil, title: nil)
        }
        let text = last.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = last.error, !error.isEmpty, text.isEmpty {
            return AdminCraftedOutcome(status: .failed, artifacts: [], note: error, title: nil)
        }
        if last.elicitation != nil || last.interrupt != nil || text.isEmpty || asksBack(text) {
            return AdminCraftedOutcome(status: .needsChat, artifacts: [], note: text.isEmpty ? nil : text, title: nil)
        }
        return AdminCraftedOutcome(status: .ready, artifacts: [], note: text, title: headingOf(text))
    }

    /// Una risposta scritta che è una domanda e non la cosa chiesta: breve e che finisce con "?".
    /// Più lunga — un piano scritto in tabella, un elenco con titoli — è il risultato, solo a parole.
    static func asksBack(_ text: String) -> Bool {
        guard text.utf16.count <= 400,
              text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") else { return false }
        let startsLikeDocument = text.split(whereSeparator: \.isNewline).contains { line in
            guard let first = line.first(where: { !$0.isWhitespace }) else { return false }
            return first == "#" || first == "|"
        }
        return !startsLikeDocument
    }

    /// `# Titolo` in cima a una risposta scritta, come nome della riga.
    static func headingOf(_ text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.drop(while: \.isWhitespace)
            let hashes = trimmed.prefix(while: { $0 == "#" }).count
            guard (1...3).contains(hashes), trimmed.dropFirst(hashes).first?.isWhitespace == true else { continue }
            var rest = Substring(trimmed.dropFirst(hashes).drop(while: \.isWhitespace))
            // `## Titolo ##`: i # di chiusura non fanno parte del nome.
            let original = rest
            while rest.last?.isWhitespace == true { rest = rest.dropLast() }
            while rest.last == "#" { rest = rest.dropLast() }
            while rest.last?.isWhitespace == true { rest = rest.dropLast() }
            if rest.isEmpty { rest = original.prefix(1) }
            guard !rest.isEmpty else { continue }
            let cleaned = String(rest.filter { !"*_`".contains($0) }).trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : String(cleaned.prefix(120))
        }
        return nil
    }

    /// La prima riga della richiesta, abbastanza corta per una riga di lista.
    static func titleFrom(_ request: String) -> String {
        let line = request.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        guard line.count > 72 else { return line }
        return String(line.prefix(71)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
