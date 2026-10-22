//
//  AdminMobileUserStepReport.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il risultato di un passo di un ordine di lavoro (StepReportResponse, snake_case): fatto o non fatto, nota
//  dell'operatore, quante foto, chi l'ha segnato e da dove. Il testo del passo sta nella procedura
//  (AdminMobileUserProcedureOrder): il report ha solo l'id del passo.
//

import Foundation

nonisolated struct AdminMobileUserStepReport: Decodable, Sendable, Identifiable, Hashable {
    let stepId: String
    /// `done` o `not_done`.
    let status: String
    let note: String?
    let photoCount: Int
    let reportedByName: String?
    let reportedAt: Date?
    /// `mobile` o `desktop`: da dove è stato segnato il passo.
    let statusSource: String?
    let statusByName: String?
    let statusAt: Date?

    var id: String { stepId }
    var isDone: Bool { status == "done" }

    private enum CodingKeys: String, CodingKey {
        case stepId, status, note, photos, reportedByName, reportedAt, statusSource, statusByName, statusAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }
        stepId = try c.decode(String.self, forKey: .stepId)
        status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "not_done"
        let text = (try? c.decodeIfPresent(String.self, forKey: .note))?.trimmingCharacters(in: .whitespacesAndNewlines)
        note = text?.isEmpty == false ? text : nil
        photoCount = (try? c.decodeIfPresent(AriaLossyArray<AriaJSON>.self, forKey: .photos))?.items.count ?? 0
        reportedByName = try? c.decodeIfPresent(String.self, forKey: .reportedByName)
        reportedAt = date(.reportedAt)
        statusSource = try? c.decodeIfPresent(String.self, forKey: .statusSource)
        statusByName = try? c.decodeIfPresent(String.self, forKey: .statusByName)
        statusAt = date(.statusAt)
    }
}

/// GET /v1/work-orders/{id}?include=procedure, ridotto ai passi: numero e testo per ogni id.
nonisolated struct AdminMobileUserProcedureOrder: Decodable, Sendable {
    nonisolated struct Step: Decodable, Sendable, Identifiable, Hashable {
        let id: String
        let number: Int
        let text: String
    }

    nonisolated struct Procedure: Decodable, Sendable {
        let steps: [Step]

        private enum CodingKeys: String, CodingKey { case steps }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            steps = (try? c.decodeIfPresent(AriaLossyArray<Step>.self, forKey: .steps))?.items ?? []
        }
    }

    let procedure: Procedure?

    var steps: [Step] { procedure?.steps ?? [] }

    private enum CodingKeys: String, CodingKey { case procedure }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        procedure = try? c.decodeIfPresent(Procedure.self, forKey: .procedure)
    }
}
