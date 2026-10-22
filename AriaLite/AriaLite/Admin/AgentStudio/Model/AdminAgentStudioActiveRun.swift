//
//  AdminAgentStudioActiveRun.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I run in corso e quelli fermi ad aspettare una persona (GET workflow-runs/active).
//  La forma non è documentata: si leggono tutti gli array della risposta, e il nome dell'array
//  (es. `paused`) fa da stato quando il run non lo dice.
//

import Foundation

nonisolated struct AdminAgentStudioActiveRun: Sendable, Identifiable, Hashable {
    let id: String
    let workflowId: String?
    let workflowName: String?
    let status: String?
    let mode: String?
    let startedAt: Date?
    let startedBy: String?
    let waitingFor: String?

    init?(json: AriaJSON, group: String?) {
        let fields = AdminAgentStudioFields(json)
        guard let id = fields.string("runId", "id") else { return nil }
        self.id = id
        workflowId = fields.string("workflowId")
        workflowName = fields.string("workflowName", "name")
        status = fields.string("status", "state") ?? group.flatMap(Self.status(forGroup:))
        mode = fields.string("mode")
        startedAt = fields.date("startedAt", "createdAt")
        startedBy = fields.string("startedBy", "userId")
        waitingFor = fields.string("waitingFor", "approvalTitle", "pendingApproval", "nodeId")
    }

    /// `running` / `paused` come chiavi della risposta; le altre chiavi non dicono uno stato.
    private static func status(forGroup group: String) -> String? {
        switch group.lowercased() {
        case "running", "active": "running"
        case "paused", "waiting", "awaiting_approval": "paused"
        default: nil
        }
    }
}

/// La risposta di GET workflow-runs/active: un array nudo o un oggetto con uno o più array.
nonisolated struct AdminAgentStudioActiveRuns: Decodable, Sendable {
    let items: [AdminAgentStudioActiveRun]

    init(from decoder: any Decoder) throws {
        let json = try AriaJSON(from: decoder)
        var runs: [AdminAgentStudioActiveRun] = []
        switch json {
        case .array(let list):
            runs = list.compactMap { AdminAgentStudioActiveRun(json: $0, group: nil) }
        case .object(let object):
            for key in object.keys.sorted() {
                for item in object[key]?.arrayValue ?? [] {
                    if let run = AdminAgentStudioActiveRun(json: item, group: key) { runs.append(run) }
                }
            }
        default:
            break
        }
        var seen = Set<String>()
        items = runs.filter { seen.insert($0.id).inserted }
    }
}
