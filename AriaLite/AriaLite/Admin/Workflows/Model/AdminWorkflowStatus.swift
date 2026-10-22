//
//  AdminWorkflowStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un flusso come lo dà il server (`draft`, `archived`: "published" non è uno stato, vedi
//  AdminWorkflow.isPublished) e la scelta del filtro in lista.
//

import Foundation

nonisolated enum AdminWorkflowStatus: String, Sendable, CaseIterable, Hashable {
    case draft
    case archived

    var label: String {
        switch self {
        case .draft: String(localized: "Draft")
        case .archived: String(localized: "Archived")
        }
    }

    var systemImage: String {
        switch self {
        case .draft: "pencil.and.list.clipboard"
        case .archived: "archivebox"
        }
    }
}
