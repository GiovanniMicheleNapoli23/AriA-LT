//
//  AdminUsageWords.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I nomi che la pagina Usage dà a piani, azioni e agenti (`usage.plans`, `usage.actionTypes`,
//  `scheduled.dialog.agent` della web). Una chiave che l'app non conosce si mostra com'è arrivata.
//

import Foundation

nonisolated enum AdminUsageWords {
    /// Il nome di un piano. Una chiave sconosciuta si mostra com'è.
    static func planName(_ key: String) -> String {
        switch key {
        case "free_demo": String(localized: "usage.plan.free_demo", defaultValue: "Free Demo")
        case "basic": String(localized: "usage.plan.basic", defaultValue: "Basic")
        case "basic_plus": String(localized: "usage.plan.basic_plus", defaultValue: "Basic Plus")
        case "professional": String(localized: "usage.plan.professional", defaultValue: "Professional")
        case "enterprise": String(localized: "usage.plan.enterprise", defaultValue: "Enterprise")
        default: key
        }
    }

    /// Il nome di un tipo di azione: i punti della chiave diventano trattini bassi (`chat.reply` → `chat_reply`).
    /// Una chiave sconosciuta si mostra com'è; `nil` è "Not attributed".
    static func actionName(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return notAttributed }
        switch key.replacingOccurrences(of: ".", with: "_") {
        case "chat_reply": return String(localized: "usage.action.chat_reply", defaultValue: "Chat replies")
        case "workflow_step": return String(localized: "usage.action.workflow_step", defaultValue: "Agent Studio steps")
        case "doc_generate": return String(localized: "usage.action.doc_generate", defaultValue: "Documents")
        case "workflow_design": return String(localized: "usage.action.workflow_design", defaultValue: "Workflow design")
        case "stt_polish": return String(localized: "usage.action.stt_polish", defaultValue: "Dictation")
        case "cmms_assist": return String(localized: "usage.action.cmms_assist", defaultValue: "CMMS assistant")
        case "rag_diagnostic": return String(localized: "usage.action.rag_diagnostic", defaultValue: "Diagnostics")
        case "doc_generate_async":
            return String(localized: "usage.action.doc_generate_async", defaultValue: "Background documents")
        case "fact_translate": return String(localized: "usage.action.fact_translate", defaultValue: "Fact translations")
        case "classify": return String(localized: "usage.action.classify", defaultValue: "Classification")
        case "voice_turn": return String(localized: "usage.action.voice_turn", defaultValue: "Talk with Aria")
        case "doc_ingest": return String(localized: "usage.action.doc_ingest", defaultValue: "Document uploads")
        case "workflow_run": return String(localized: "usage.action.workflow_run", defaultValue: "Agent Studio runs")
        case "chat_assist": return String(localized: "usage.action.chat_assist", defaultValue: "Chat assistance")
        case "predictive_run":
            return String(localized: "usage.action.predictive_run", defaultValue: "Predictive maintenance")
        default: return key
        }
    }

    /// Il nome di un agente: `workflow:<id>` ha il nome del workflow nella riga; `agent:general` è "AriA",
    /// `agent:predictive` "Predictive maintenance", gli altri personaggi di `scheduled.dialog.agent`; il resto com'è.
    static func agentName(key: String?, label: String?) -> String {
        let raw = key ?? ""
        if raw.hasPrefix("workflow:") {
            guard let label, !label.isEmpty else { return notAttributed }
            return label
        }
        let name = raw.hasPrefix("agent:") ? String(raw.dropFirst("agent:".count)) : raw
        switch name {
        case "general": return String(localized: "usage.agent.general", defaultValue: "AriA")
        case "predictive": return String(localized: "usage.agent.predictive", defaultValue: "Predictive maintenance")
        case "technical": return String(localized: "usage.agent.technical", defaultValue: "Technical")
        case "order": return String(localized: "usage.agent.order", defaultValue: "Work orders")
        case "reporter": return String(localized: "usage.agent.reporter", defaultValue: "Reporting")
        case "connector": return String(localized: "usage.agent.connector", defaultValue: "Connectors")
        case "safety": return String(localized: "usage.agent.safety", defaultValue: "Safety")
        case "": return notAttributed
        default: return name
        }
    }

    static var notAttributed: String {
        String(localized: "usage.breakdown.unattributed", defaultValue: "Not attributed")
    }
}
