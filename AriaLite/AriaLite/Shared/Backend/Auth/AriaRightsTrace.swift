//
//  AriaRightsTrace.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Solo DEBUG: i diritti letti da GET /v1/me nella console (Xcode, Console.app / `log stream`, categoria
//  "rights"), a ogni cambio. Per ogni sezione dell'operatore: se la sidebar la mostra, se il ruolo la concede,
//  gli switch che il server manda e, per ogni pulsante dell'app, se si vede o no (e perché).
//

import Foundation
import OSLog

nonisolated enum AriaRightsTrace {
    #if DEBUG
    private static let log = Logger(subsystem: "com.giovanniMichele.AriaLite", category: "rights")
    #endif

    /// Un pulsante dell'app: gli switch che lo accendono (tutti) e quando compare (stato del record).
    private struct Button {
        let title: String
        let actions: [AriaSectionAction]
        let when: String

        init(_ title: String, _ actions: AriaSectionAction..., when: String = "") {
            self.title = title
            self.actions = actions
            self.when = when
        }
    }

    private static let review: [Button] = [
        Button("Approve", .approve, when: "record not approved"),
        Button("Unapprove (back to draft)", .unapprove, when: "record approved, in Edit"),
        Button("Reject / Back to draft from rejected", .reject, when: "banner on pending records, or Edit"),
        Button("Reject an approved record", .reject, .unapprove, when: "record approved, in Edit"),
        Button("Delete", .reject, when: "record not rejected, detail (approved: also unapprove)"),
        Button("Delete a rejected record", when: "record rejected, detail"),
    ]

    /// Le sezioni dell'operatore, nell'ordine della sidebar, con i pulsanti che l'app ha.
    private static let sections: [(section: AriaSection, buttons: [Button], missing: [String])] = [
        (.workOrders, [
            Button("Complete", .complete, when: "open order"),
            Button("Add/Delete step photo, Clear a step with photos", .stepPhotos),
            Button("Verify", .verify, when: "completed order, status menu"),
            Button("Cancel / Delete", .cancel, when: "open order (Delete also detail)"),
            Button("Reopen (to Proposed)", .reopen, when: "verified or cancelled order"),
            Button("Auto-assign", .autoAssign, when: "order detail / Taskboard"),
            Button("Accept a move of a reassignment plan", when: "chat, reassignment-plan card"),
            Button("Apply all", .bulkReassign, when: "chat, reassignment-plan card with 2+ pending moves"),
        ], []),
        (.taskboard, [], []),
        (.marketplace, [], []),
        (.crafted, [], ["intervention-report list: only with the scenario_analysis section (own report stays in chat)"]),
        (.maintenance, review, []),
        (.assets, review + [
            Button("Approve selected", .approve, when: "list showing not-approved assets, Select"),
            Button("Refresh health score", .refreshHealth, when: "asset detail, Health card (reading needs only the section)"),
        ], []),
        (.spareParts, review, []),
        (.alarms, review + [
            Button("Approve selected", .approve, when: "list, Draft filter, Select"),
            Button("Mark event read / Mark all read", .acknowledge, when: "Alarm events (bell in the Alarms toolbar)"),
        ], []),
        (.vendors, [Button("New vendor", .create), Button("Edit", .edit), Button("Delete", .delete)], []),
        (.llmUsage, [Button("Stop on someone else's session", .stopSession, when: "own session: always")], []),
        (.categories, [Button("New category", .create), Button("Edit", .edit), Button("Delete", .delete)], []),
    ]

    /// Scrive tutto il quadro: chiamato quando `access` cambia (prima lettura compresa).
    static func dump(_ rights: AriaRights, operatorLayout: Bool, sidebar: [String]) {
        #if DEBUG
        guard let access = rights.access else {
            log.notice("rights: no access block (old backend or failed /v1/me) → everything allowed, layout=\(operatorLayout ? "operator" : "admin", privacy: .public)")
            return
        }
        let role = access.role.map { "\($0.name) (\($0.enabled ? "enabled" : "PAUSED"))" } ?? "NONE"
        log.notice("""
            rights: model=\(access.model, privacy: .public) admin=\(access.admin) role=\(role, privacy: .public) \
            appFollowsRole=\(access.appFollowsRole) → followsRole=\(rights.followsRole) roleBased=\(rights.isRoleBased) \
            layout=\(operatorLayout ? "operator" : "admin", privacy: .public) version=\(access.version ?? "-", privacy: .public)
            """)
        log.notice("rights: sidebar = \(sidebar.joined(separator: ", "), privacy: .public)")
        if operatorLayout, rights.isRoleBased, !rights.followsRole {
            log.notice("rights: appFollowsRole is false → the operator sees only Tasks + Calendar, no section buttons")
        }

        for (section, buttons, missing) in sections {
            let grant = access.sections[section.rawValue]
            let granted = grant?.granted == true
            let actions = grant?.actions.sorted().joined(separator: ", ") ?? "-"
            var lines = ["[\(section.rawValue)] granted=\(granted) usable=\(rights.has(section)) switches=[\(actions)]"]
            for button in buttons {
                let shown = button.actions.allSatisfy { rights.can($0, in: section) } && rights.has(section)
                let needs = button.actions.isEmpty ? "section only"
                    : "needs " + button.actions.map(\.rawValue).joined(separator: " + ")
                let when = button.when.isEmpty ? "" : ", when \(button.when)"
                lines.append("  \(shown ? "✅ SHOWN " : "⛔️ HIDDEN") \(button.title) (\(needs)\(when))")
            }
            for name in missing { lines.append("  ➖ not in app: \(name)") }
            log.notice("rights: \(lines.joined(separator: "\n"), privacy: .public)")
        }

        let others = access.sections.keys.filter { slug in !sections.contains { $0.section.rawValue == slug } }.sorted()
        let rest = others.map { slug in
            let g = access.sections[slug]
            return "\(slug)=\(g?.granted == true ? "granted" : "no")[\(g?.actions.joined(separator: ",") ?? "")]"
        }
        log.notice("rights: other sections (no operator screen): \(rest.joined(separator: " "), privacy: .public)")
        #endif
    }
}
