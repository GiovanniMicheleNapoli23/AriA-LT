//
//  AdminAgentStudioNotification.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una notifica di Agent Studio (run finito, approvazione richiesta…). Forma non documentata:
//  letta in modo tollerante. `isRead` si aggiorna qui appena l'utente la segna come letta.
//

import Foundation

nonisolated struct AdminAgentStudioNotification: AdminAgentStudioJSONModel, Identifiable, Hashable {
    static let listKeys = ["notifications", "items"]

    let id: String
    let title: String
    let body: String?
    let kind: String?
    let createdAt: Date?
    var isRead: Bool
    let runId: String?
    let approvalId: String?
    let workflowId: String?

    init?(json: AriaJSON) {
        let fields = AdminAgentStudioFields(json)
        guard let id = fields.string("id", "notificationId") else { return nil }
        self.id = id
        let body = fields.string("body", "message", "text", "detail")
        title = fields.string("title", "subject") ?? body ?? String(localized: "Notification")
        self.body = fields.string("title", "subject") == nil ? nil : body
        kind = fields.string("kind", "type", "level", "severity")
        createdAt = fields.date("createdAt", "created", "timestamp", "ts")
        isRead = fields.bool("read", "isRead") ?? (fields.value("readAt") != nil)
        runId = fields.string("runId")
        approvalId = fields.string("approvalId")
        workflowId = fields.string("workflowId")
    }

    var systemImage: String {
        let kind = (kind ?? "").lowercased()
        if kind.contains("approval") || approvalId != nil { return "person.badge.shield.checkmark" }
        if kind.contains("fail") || kind.contains("error") { return "exclamationmark.triangle" }
        if kind.contains("run") || runId != nil { return "play.circle" }
        return "bell"
    }
}
