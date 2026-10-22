//
//  AdminWorkOrderChecklist.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I passi della procedura scritti creando un ordine, e il `checklist_data` che li porta al server.
//  WorkOrderCreate vuole un testo JSON: {"steps": [{"text", "checked"}], "safety_warnings", "tools_needed",
//  "parts_needed"}. Gli id dei passi li mette il server alla creazione; da lì nasce la procedura che
//  l'operatore esegue (aria-backend, cmms/domain/procedure.py).
//

import Foundation

/// Un passo nel form: l'id serve solo a lista, fuoco e riordino, non va al server.
nonisolated struct AdminWorkOrderDraftStep: Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

nonisolated struct AdminWorkOrderChecklist: Encodable, Sendable {
    nonisolated struct Step: Encodable, Sendable {
        let text: String
        let checked = false
    }

    var steps: [Step]
    var safetyWarnings: [String]
    var toolsNeeded: [String]
    var partsNeeded: [String]

    private enum CodingKeys: String, CodingKey {
        case steps
        case safetyWarnings = "safety_warnings"
        case toolsNeeded = "tools_needed"
        case partsNeeded = "parts_needed"
    }

    /// Senza righe vuote; `nil` se non resta niente da mandare.
    init?(steps: [AdminWorkOrderDraftStep], safetyWarnings: [String], toolsNeeded: [String], partsNeeded: [String]) {
        func clean(_ items: [String]) -> [String] {
            items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        self.steps = clean(steps.map(\.text)).map { Step(text: $0) }
        self.safetyWarnings = clean(safetyWarnings)
        self.toolsNeeded = clean(toolsNeeded)
        self.partsNeeded = clean(partsNeeded)
        if self.steps.isEmpty && self.safetyWarnings.isEmpty && self.toolsNeeded.isEmpty && self.partsNeeded.isEmpty {
            return nil
        }
    }

    /// Il testo da mettere in `checklist_data`.
    var jsonText: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
