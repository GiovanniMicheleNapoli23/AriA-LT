//
//  AdminWorkOrderAIFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa dire quando ai-assist o ai-draft falliscono. I valori di `action` sono indovinati: un 400/422 vuol
//  dire quasi sempre che il server non conosce quello mandato. Si mostra il suo dettaglio così com'è e,
//  se elenca le azioni valide (422 con `detail.valid`), anche quelle, da copiare in AdminWorkOrderAIAction.
//

import Foundation

enum AdminWorkOrderAIFailure {
    /// `nil` se non c'è niente da dire (richiesta annullata).
    static func failure(for error: any Error, action: String, backend: AriaBackend) -> AdminWorkOrderAssistantFailure? {
        switch error as? AriaError {
        case .invalidChoice(_, let valid, let message)?:
            return AdminWorkOrderAssistantFailure(
                message: String(localized: "The server didn't accept the action “\(action)”: \(message)"),
                validActions: valid)
        case .http(let status, let detail)? where status == 400 || status == 422:
            return AdminWorkOrderAssistantFailure(
                message: String(localized: "The server didn't accept the action “\(action)”: \(detail)"),
                validActions: validActions(in: detail))
        default:
            guard let message = AdminWorkOrderFailure.message(for: error, backend: backend) else { return nil }
            return AdminWorkOrderAssistantFailure(message: message, validActions: [])
        }
    }

    /// Le azioni elencate in un dettaglio testuale come "Must be one of: a, b, c", "valid actions: [a, b]"
    /// o, alla pydantic, "Input should be 'a', 'b' or 'c'".
    static func validActions(in detail: String) -> [String] {
        let lower = detail.lowercased()
        let markers = ["one of", "valid actions", "allowed actions", "supported actions", "should be", "expected"]
        guard let marker = markers.lazy.compactMap({ lower.range(of: $0) }).first else { return [] }
        let tail = lower[marker.upperBound...].prefix { $0 != "." && !$0.isNewline }
        let filler: Set<String> = ["or", "and", "be", "of", "the", "are", "is", "one", "actions", "action", "valid", "got", "input"]
        var seen = Set<String>()
        return tail.split(whereSeparator: { " ,;:[]()|/'\"`".contains($0) })
            .map(String.init)
            .filter { $0.wholeMatch(of: /[a-z][a-z0-9_]*/) != nil && !filler.contains($0) }
            .filter { seen.insert($0).inserted }
    }
}
