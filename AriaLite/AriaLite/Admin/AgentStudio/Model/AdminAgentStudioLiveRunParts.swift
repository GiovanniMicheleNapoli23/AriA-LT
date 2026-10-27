//
//  AdminAgentStudioLiveRunParts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  I pezzi di AdminAgentStudioLiveRun: fase del run, stato di un nodo, controlli di connettori e policy,
//  rifiuto, approvazioni in attesa, file prodotti e riepilogo. Valori puri, letti da JSON libero.
//

import Foundation

nonisolated extension AdminAgentStudioLiveRun {
    /// Dove si trova il run. `connecting` = POST inviata, nessuna riga ancora.
    enum Phase: Sendable, Hashable {
        case connecting
        case checking
        case running
        case paused
        case finished(status: String)
        case refused
        case failed(message: String)

        var isActive: Bool {
            switch self {
            case .connecting, .checking, .running, .paused: true
            case .finished, .refused, .failed: false
            }
        }
    }

    enum NodeState: Sendable, Hashable {
        case running(startedAt: Date, attempt: Int?)
        case finished(AdminAgentStudioRunStep)
    }

    /// Un nodo visto nello stream; in un ciclo ogni passata è un nodo a sé (`iteration`).
    struct Node: Sendable, Hashable {
        let nodeId: String
        let iteration: Int?
        var state: NodeState
    }

    /// La chiave di un nodo: `nodeId`, o `nodeId#iteration` dentro un ciclo.
    static func key(nodeId: String, iteration: Int?) -> String {
        iteration.map { "\(nodeId)#\($0)" } ?? nodeId
    }

    /// Un controllo di connettore o di policy.
    struct Check: Sendable, Hashable, Identifiable {
        enum Verdict: Sendable, Hashable { case passed, warning, failed }

        let id: String
        let name: String
        let verdict: Verdict
        let message: String?

        /// `connector-check.connectors[]`: `status` connected / failed / not_connected / unsupported.
        init?(connector json: AriaJSON) {
            let fields = AdminAgentStudioFields(json)
            guard let id = fields.string("connectorId", "id", "name") else { return nil }
            self.id = id
            name = fields.string("name", "connectorId") ?? id
            let status = fields.string("status") ?? ""
            if status == "connected" || fields.bool("ok", "ready") == true {
                verdict = .passed
            } else {
                // Un connettore non obbligatorio che manca non ferma il run.
                verdict = fields.bool("required") == false ? .warning : .failed
            }
            message = fields.string("detail", "message")
        }

        /// `policy-check.policies[]`: `status` pass / warn / fail.
        init?(policy json: AriaJSON) {
            let fields = AdminAgentStudioFields(json)
            guard let id = fields.string("id", "title") else { return nil }
            self.id = id
            name = fields.string("title", "id") ?? id
            switch fields.string("status") {
            case "pass"?: verdict = .passed
            case "warn"?: verdict = .warning
            default: verdict = .failed
            }
            message = fields.string("detail", "message")
        }
    }

    /// `run-refused`: il motivo e i blocchi, uno per riga.
    struct Refusal: Sendable, Hashable {
        let reason: String
        let blockers: [String]

        init(json: AriaJSON) {
            let fields = AdminAgentStudioFields(json)
            reason = fields.string("reason", "message") ?? String(localized: "The run was refused")
            let detailed = fields.array("blockerDetails").compactMap { AdminAgentStudioFields($0).string("message") }
            let found = detailed.isEmpty ? fields.strings("blockers") : detailed
            var seen = Set<String>()
            blockers = found.filter { seen.insert($0).inserted }
        }
    }

    /// `approval-requested`: il run aspetta una persona.
    struct PendingApproval: Sendable, Hashable, Identifiable {
        let id: String
        let nodeId: String
        let title: String
        let riskTier: String?
        let expiresAt: Date?

        init?(json: AriaJSON) {
            let fields = AdminAgentStudioFields(json)
            guard let id = fields.string("approvalId"), let nodeId = fields.string("nodeId") else { return nil }
            self.id = id
            self.nodeId = nodeId
            title = fields.string("title") ?? nodeId
            riskTier = fields.string("riskTier")
            expiresAt = fields.date("expiresAt")
        }
    }

    /// `artifact`: un file prodotto da un nodo.
    struct Artifact: Sendable, Hashable, Identifiable {
        let id: String
        let nodeId: String
        let name: String
        let kind: String

        init?(json: AriaJSON) {
            let fields = AdminAgentStudioFields(json)
            let artifact = fields.object("artifact")
            guard let nodeId = fields.string("nodeId"), let id = artifact.string("id") else { return nil }
            self.id = id
            self.nodeId = nodeId
            name = artifact.string("name") ?? id
            kind = artifact.string("kind") ?? "file"
        }
    }

    /// `run-summary`: i contatori finali (la simulazione e il run li mandano a fine corsa).
    struct Summary: Sendable, Hashable {
        let ran: Int
        let blocked: Int
        let unconfigured: Int
        let needsApproval: Int
        let skipped: Int
        let total: Int
        let durationMs: Int?
        let accuracy: Int?
        let ready: Bool?
        let limitations: [String]
        let narrative: String?

        init(json: AdminAgentStudioFields) {
            ran = json.int("ran") ?? 0
            blocked = json.int("blocked") ?? 0
            unconfigured = json.int("unconfigured") ?? 0
            needsApproval = json.int("needsApproval") ?? 0
            skipped = json.int("skipped") ?? 0
            total = json.int("total") ?? 0
            durationMs = json.int("durationMs")
            accuracy = json.int("accuracy")
            ready = json.bool("ready")
            limitations = json.strings("limitations")
            narrative = json.string("narrative")
        }
    }
}
