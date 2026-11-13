//
//  AdminRoleNames.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  I nomi di gruppi, sezioni e azioni di Roles & Rights, con le parole della web (`sidebar.*` e
//  `rolesAndRights.actions.*`). Uno slug che l'app non conosce si mostra così com'è, come fa la web.
//

import Foundation

nonisolated enum AdminRoleNames {
    static func group(_ group: AdminRoleGroup?) -> String {
        switch group {
        case .operational: String(localized: "Operations")
        case .resources: String(localized: "Resources")
        case .purchases: String(localized: "Purchases")
        case .analytics: String(localized: "Analytics")
        case .intelligence: String(localized: "Intelligence")
        case .configuration: String(localized: "Configuration")
        case nil: String(localized: "Other")
        }
    }

    static func section(_ slug: String) -> String {
        switch slug {
        case "work_orders": String(localized: "Work Orders")
        case "maintenance": String(localized: "Maintenance")
        case "inspections": String(localized: "Inspections")
        case "taskboard": String(localized: "Taskboard")
        case "assets": String(localized: "Assets")
        case "spare_parts": String(localized: "Spare Parts")
        case "alarms": String(localized: "Alarms")
        case "meters": String(localized: "Meters")
        case "locations": String(localized: "Locations")
        case "purchase_orders": String(localized: "Purchase Orders")
        case "vendors": String(localized: "Vendors")
        case "reports": String(localized: "Reports")
        case "llm_usage": String(localized: "LLM Usage")
        case "documents": String(localized: "Documents")
        case "knowledge_graph": String(localized: "Knowledge Graph")
        case "agent_studio": String(localized: "Agent Studio")
        case "marketplace": String(localized: "Marketplace")
        case "extraction_review": String(localized: "Extraction Review")
        case "learned_knowledge": String(localized: "Learned knowledge")
        case "scenario_analysis": String(localized: "Scenario analysis")
        case "crafted": String(localized: "Crafted")
        case "plants": String(localized: "Sites")
        case "categories": String(localized: "Categories")
        case "teams": String(localized: "Teams")
        case "members": String(localized: "Members")
        case "agent_prompts": String(localized: "Agent prompts")
        case "audit_log": String(localized: "Audit log")
        default: slug
        }
    }

    static func action(_ slug: String) -> String {
        switch slug {
        case "verify": String(localized: "Verify", comment: "Roles & Rights action")
        case "reopen": String(localized: "Reopen", comment: "Roles & Rights action")
        case "cancel": String(localized: "Cancel", comment: "Roles & Rights action")
        case "complete": String(localized: "Complete", comment: "Roles & Rights action")
        case "auto_assign": String(localized: "Auto-assign", comment: "Roles & Rights action")
        case "bulk_reassign": String(localized: "Bulk reassign", comment: "Roles & Rights action")
        case "step_photos": String(localized: "Step photos", comment: "Roles & Rights action")
        case "approve": String(localized: "Approve", comment: "Roles & Rights action")
        case "unapprove": String(localized: "Withdraw approval", comment: "Roles & Rights action")
        case "reject": String(localized: "Reject", comment: "Roles & Rights action")
        case "acknowledge": String(localized: "Acknowledge", comment: "Roles & Rights action")
        case "refresh_health": String(localized: "Refresh health", comment: "Roles & Rights action")
        case "receive": String(localized: "Receive", comment: "Roles & Rights action")
        case "stop_session": String(localized: "Stop sessions", comment: "Roles & Rights action")
        case "cancel_run": String(localized: "Cancel runs", comment: "Roles & Rights action")
        case "ingest": String(localized: "Ingest", comment: "Roles & Rights action")
        case "extract": String(localized: "Extract", comment: "Roles & Rights action")
        case "sync_knowledge": String(localized: "Sync knowledge", comment: "Roles & Rights action")
        case "reindex_knowledge": String(localized: "Reindex knowledge", comment: "Roles & Rights action")
        case "approve_fact": String(localized: "Approve facts", comment: "Roles & Rights action")
        case "revoke_fact": String(localized: "Revoke facts", comment: "Roles & Rights action")
        case "reject_proposal": String(localized: "Reject proposals", comment: "Roles & Rights action")
        case "settle_verdict": String(localized: "Settle verdicts", comment: "Roles & Rights action")
        case "approve_closure": String(localized: "Approve closures", comment: "Roles & Rights action")
        case "reassign_closure": String(localized: "Reassign closures", comment: "Roles & Rights action")
        case "dismiss_closure": String(localized: "Dismiss closures", comment: "Roles & Rights action")
        case "backfill": String(localized: "Backfill", comment: "Roles & Rights action")
        // "Run" è già il sostantivo ("Esecuzione"): qui è il verbo.
        case "run": String(localized: "roles.action.run", defaultValue: "Run", comment: "Roles & Rights action")
        case "enable_workflow": String(localized: "Switch workflows on and off", comment: "Roles & Rights action")
        case "publish_flow": String(localized: "Publish flows", comment: "Roles & Rights action")
        case "restore_flow": String(localized: "Restore versions", comment: "Roles & Rights action")
        case "archive_flow": String(localized: "Archive flows", comment: "Roles & Rights action")
        case "unarchive_flow": String(localized: "Unarchive flows", comment: "Roles & Rights action")
        case "create": String(localized: "Create", comment: "Roles & Rights action")
        case "edit": String(localized: "Edit", comment: "Roles & Rights action")
        case "delete": String(localized: "Delete", comment: "Roles & Rights action")
        case "manage_members": String(localized: "Manage members", comment: "Roles & Rights action")
        case "log_reading": String(localized: "Log readings", comment: "Roles & Rights action")
        case "assign_shifts": String(localized: "Assign shifts", comment: "Roles & Rights action")
        case "save_chart": String(localized: "Save charts", comment: "Roles & Rights action")
        case "delete_chart": String(localized: "Delete saved charts", comment: "Roles & Rights action")
        case "reset": String(localized: "Reset to default", comment: "Roles & Rights action")
        default: slug
        }
    }

    /// La riga di una sezione nell'elenco del ruolo. `onActions`: gli slug delle azioni accese, `total`: quelle del
    /// catalogo. Una o due si dicono per nome, da tre in su si contano.
    static func summary(isOn: Bool, onActions: [String], total: Int) -> String {
        guard isOn else { return String(localized: "roles.summary.off", defaultValue: "Off") }
        guard !onActions.isEmpty else { return String(localized: "View only") }
        if total > 0, onActions.count >= total { return String(localized: "All actions") }
        if onActions.count <= 2 { return onActions.map(action).joined(separator: ", ") }
        return String(localized: "\(onActions.count) of \(total) actions")
    }
}
