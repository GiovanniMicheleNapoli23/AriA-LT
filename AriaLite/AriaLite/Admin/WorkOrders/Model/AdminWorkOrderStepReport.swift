//
//  AdminWorkOrderStepReport.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il resoconto di un passo (GET /v1/work-orders/{id}/step-reports): oltre al risultato dice chi l'ha
//  registrato, quando e da dove (telefono o web).
//

import Foundation

nonisolated enum AdminWorkOrderStatusSource: String, AriaUnknownCaseDecodable, Hashable {
    case mobile, desktop
    case unknown

    static var unknownCase: Self { .unknown }

    var localized: String {
        switch self {
        case .mobile: String(localized: "Phone")
        case .desktop: String(localized: "Web")
        case .unknown: String(localized: "Unknown")
        }
    }
}

nonisolated struct AdminWorkOrderStepReport: Decodable, Sendable, Hashable, Identifiable {
    let stepId: String
    var status: AdminWorkOrderStepStatus
    var note: String?
    var photoCount: Int
    var reportedByName: String?
    var reportedAt: Date?
    var statusSource: AdminWorkOrderStatusSource?
    var statusByName: String?
    var statusAt: Date?

    var id: String { stepId }

    private enum CodingKeys: String, CodingKey {
        case stepId, status, note, photos, reportedBy, reportedByName, reportedAt, statusSource, statusByName, statusAt
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let stepId = f.id(.stepId) else {
            throw DecodingError.keyNotFound(CodingKeys.stepId, .init(codingPath: decoder.codingPath, debugDescription: "step_id"))
        }
        self.stepId = stepId
        status = f.value(AdminWorkOrderStepStatus.self, .status) ?? .unknown
        note = f.text(.note)
        photoCount = f.value([AriaJSON].self, .photos)?.count ?? 0
        reportedByName = f.text(.reportedByName) ?? f.text(.reportedBy)
        reportedAt = f.date(.reportedAt)
        statusSource = f.value(AdminWorkOrderStatusSource.self, .statusSource)
        statusByName = f.text(.statusByName)
        statusAt = f.date(.statusAt)
    }
}
