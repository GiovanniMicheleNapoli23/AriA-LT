//
//  AdminAgentStudioAPI+Approvals.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Approvazioni (pagine /agent-studio/approvals e /approvals/{id}) e notifiche di Agent Studio.
//  Le risposte non hanno schema (oggetti liberi): si leggono con AdminAgentStudioList / One.
//

import Foundation

extension AdminAgentStudioAPI {
    // MARK: Approvazioni

    /// `status`: pending, approved, rejected, expired, cancelled; `nil` = tutte.
    static func approvals(status: String?) -> AriaEndpoint<AdminAgentStudioList<AdminAgentStudioApproval>> {
        guard let status else { return .get("v1/agent-studio/approvals") }
        return .get("v1/agent-studio/approvals", query: ["status": status])
    }

    static func approval(id: String) -> AriaEndpoint<AdminAgentStudioOne<AdminAgentStudioApproval>> {
        .get("v1/agent-studio/approvals/\(id)")
    }

    /// Approva o rifiuta un passo in attesa; deciso, il run riparte. La risposta si ignora: si rilegge il dettaglio.
    static func decide(approvalId: String, _ decision: AdminAgentStudioDecision, comment: String) -> AriaEndpoint<AriaNoContent> {
        .post("v1/agent-studio/approvals/\(approvalId)/decision",
              body: AdminAgentStudioDecisionBody(decision: decision.rawValue, comment: comment))
    }

    // MARK: Notifiche

    static func notifications(unreadOnly: Bool = false) -> AriaEndpoint<AdminAgentStudioList<AdminAgentStudioNotification>> {
        unreadOnly ? .get("v1/agent-studio/notifications", query: ["unread_only": "true"])
            : .get("v1/agent-studio/notifications")
    }

    static func markRead(notificationId: String) -> AriaEndpoint<AriaNoContent> {
        .post("v1/agent-studio/notifications/\(notificationId)/read")
    }
}
