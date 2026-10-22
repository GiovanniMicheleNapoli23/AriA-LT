//
//  AdminProcedure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La procedura di un ordine (GET /v1/work-orders/{id}?include=procedure): passi, avvertenze di sicurezza,
//  attrezzi e ricambi. Qui è in sola lettura: i passi li esegue l'operatore dal telefono.
//

import Foundation

nonisolated struct AdminProcedure: Decodable, Sendable, Hashable {
    var steps: [AdminProcedureStep]
    var safetyWarnings: [String]
    var toolsNeeded: [String]
    var partsNeeded: [String]
    var progress: AdminStepProgress?

    private enum CodingKeys: String, CodingKey { case steps, safetyWarnings, toolsNeeded, partsNeeded, progress }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        steps = f.array(AdminProcedureStep.self, .steps).sorted { $0.number < $1.number }
        safetyWarnings = f.array(String.self, .safetyWarnings)
        toolsNeeded = f.array(String.self, .toolsNeeded)
        partsNeeded = f.array(String.self, .partsNeeded)
        progress = f.value(AdminStepProgress.self, .progress)
    }
}

nonisolated struct AdminProcedureStep: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var number: Int
    var text: String
    /// Il risultato registrato, se c'è.
    var report: AdminStepResult?

    private enum CodingKeys: String, CodingKey { case id, number, text, report }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        number = f.int(.number) ?? 0
        text = f.value(String.self, .text) ?? ""
        report = f.value(AdminStepResult.self, .report)
    }
}

nonisolated enum AdminStepStatus: String, AriaUnknownCaseDecodable, Hashable {
    case done
    case notDone = "not_done"
    case unknown

    static var unknownCase: Self { .unknown }

    var localized: String {
        switch self {
        case .done: String(localized: "Done")
        case .notDone: String(localized: "Not done")
        case .unknown: String(localized: "Unknown")
        }
    }
}

/// Il risultato di un passo dentro la procedura.
nonisolated struct AdminStepResult: Decodable, Sendable, Hashable {
    var status: AdminStepStatus
    var note: String?
    var photoCount: Int
    var reportedAt: Date?

    private enum CodingKeys: String, CodingKey { case status, note, photos, reportedAt }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        status = f.value(AdminStepStatus.self, .status) ?? .unknown
        note = f.text(.note)
        photoCount = f.value([AriaJSON].self, .photos)?.count ?? 0
        reportedAt = f.date(.reportedAt)
    }
}
