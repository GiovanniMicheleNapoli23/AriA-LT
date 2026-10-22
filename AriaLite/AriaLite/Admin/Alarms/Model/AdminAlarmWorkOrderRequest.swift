//
//  AdminAlarmWorkOrderRequest.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  POST /v1/work-orders dalla diagnosi di un allarme (WorkOrderCreate). Un body proprio, minimo: il
//  collegamento all'allarme (`alarm_code`) e la procedura (`checklist_data`) non stanno in quello delle
//  altre sezioni. `checklist_data` è un testo JSON {"steps": [{"text", "checked"}]}.
//

import Foundation

nonisolated struct AdminAlarmWorkOrderCreate: Encodable, Sendable {
    var title: String
    var plantId: String
    var type = "reactive"
    var priority: String
    var category: String?
    var assetTag: String?
    var alarmCode: String?
    var description: String?
    var estimatedDurationMin: Int?
    var checklistData: String?

    /// I passi di riparazione come testo di `checklist_data`; `nil` se non ce ne sono.
    static func checklistText(steps: [String]) -> String? {
        struct Step: Encodable { let text: String; let checked = false }
        struct Checklist: Encodable { let steps: [Step] }
        let clean = steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let checklist = Checklist(steps: clean.map { Step(text: $0) })
        guard !clean.isEmpty, let data = try? JSONEncoder().encode(checklist) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// L'ordine appena creato: basta sapere che esiste e come si chiama.
nonisolated struct AdminAlarmCreatedWorkOrder: Decodable, Sendable, Equatable {
    var id: String?
    var title: String?

    private enum CodingKeys: String, CodingKey { case id, title }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(AriaJSON.self, forKey: .id))?.nonEmptyString
        title = (try? c.decodeIfPresent(AriaJSON.self, forKey: .title))?.nonEmptyString
    }
}
