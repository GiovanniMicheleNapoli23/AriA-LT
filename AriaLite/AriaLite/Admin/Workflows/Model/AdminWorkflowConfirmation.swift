//
//  AdminWorkflowConfirmation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un'azione che chiede conferma prima di partire: pubblicare, eliminare per sempre o ripristinare
//  una versione (cambia il grafo del flusso). Titolo, spiegazione e pulsante per il dialogo.
//

import Foundation

nonisolated enum AdminWorkflowConfirmation: Sendable, Hashable {
    case publish
    case delete
    case restore(AdminWorkflowVersion)

    var title: String {
        switch self {
        case .publish: String(localized: "Publish this flow?")
        case .delete: String(localized: "Delete this flow?")
        case .restore(let version): String(localized: "Restore version \(version.version)?")
        }
    }

    var message: String {
        switch self {
        case .publish:
            String(localized: """
                It will be checked first. \
                If it is valid, it becomes a new published version.
                """)
        case .delete: String(localized: "The flow and its versions will be removed for good.")
        case .restore:
            String(localized: """
                The flow goes back to the graph of that version. \
                You can publish it again afterwards.
                """)
        }
    }

    var actionTitle: String {
        switch self {
        case .publish: String(localized: "Publish")
        case .delete: String(localized: "Delete")
        case .restore: String(localized: "Restore")
        }
    }

    var isDestructive: Bool { self == .delete }
}
