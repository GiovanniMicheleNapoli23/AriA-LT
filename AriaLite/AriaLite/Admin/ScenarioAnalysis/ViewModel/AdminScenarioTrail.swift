//
//  AdminScenarioTrail.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si racconta una voce della traccia (feedback, nota, revisione), un passo della procedura e la riga
//  secondaria di sessioni e chiusure nelle liste: testi e icone derivati dai campi che il server ha valorizzato.
//

import Foundation

extension AdminScenarioFeedbackEvent {
    /// "Note", "Step failed · Step 3", "Answer vote"…
    var headline: String {
        var parts: [String] = []
        if let kind { parts.append(AdminScenarioLabel.humanized(kind)) }
        if let action, action != kind { parts.append(AdminScenarioLabel.humanized(action)) }
        if let step = stepLabel ?? stepTitle ?? step.map({ String(localized: "Step \($0)") }) { parts.append(step) }
        return parts.isEmpty ? String(localized: "Feedback") : parts.joined(separator: " · ")
    }

    /// Il testo più utile che ha: la nota, la domanda, l'estratto della risposta o l'esito.
    var bodyText: String? {
        [note, question, answerExcerpt, outcome.map(AdminScenarioLabel.verdict)]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    var systemImage: String {
        switch vote?.lowercased() {
        case "up", "upvote", "positive": return "hand.thumbsup"
        case "down", "downvote", "negative": return "hand.thumbsdown"
        default: break
        }
        if note != nil { return "note.text" }
        if outcome != nil || rating != nil { return "checkmark.seal" }
        if step != nil || stepLabel != nil { return "list.number" }
        return "text.bubble"
    }

    /// "da Mario Rossi · 12 ott, 10:30".
    var footnote: String? {
        let parts = [createdBy, createdAt.map { AdminScenarioFormat.date($0) }].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Ha insegnato qualcosa ad Aria (non solo archiviato).
    var taughtAria: Bool { reflectionId != nil }
}

extension AdminScenarioStep {
    var headline: String {
        [label, title].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " — ")
    }

    var outcomeLabel: String? { outcome.map(AdminScenarioLabel.humanized) }
}

extension AdminScenarioSessionReview {
    /// "★★★★☆ · 12 ott, 10:30 · Procedure 2".
    var metaLine: String? {
        var parts: [String] = []
        if let stars = AdminScenarioFormat.stars(reviewRating) { parts.append(stars) }
        if let date = startedAt ?? updatedAt { parts.append(AdminScenarioFormat.date(date)) }
        if episode > 1 { parts.append(String(localized: "Procedure \(episode)")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension AdminScenarioClosure {
    /// "Mario Rossi · Part not available · 12 ott, 10:30".
    var metaLine: String? {
        let parts = [
            closedByName,
            closureReasonCode.map(AdminScenarioLabel.humanized),
            createdAt.map { AdminScenarioFormat.date($0) },
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
