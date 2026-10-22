//
//  AdminDocumentAction.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni su un documento che chiedono conferma: rilanciare estrazione o indicizzazione,
//  fermare le pipeline, cancellare (anche con i dati CMMS estratti). Testi della conferma inclusi.
//

import Foundation

nonisolated enum AdminDocumentAction: String, Sendable, Identifiable {
    case extract, ingest, cancel, delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .extract: String(localized: "Run extraction again?")
        case .ingest: String(localized: "Index this document again?")
        case .cancel: String(localized: "Stop processing?")
        case .delete: String(localized: "Delete this document?")
        }
    }

    var message: String {
        switch self {
        case .extract: String(localized: "Aria reads the document again and proposes assets, spare parts and procedures for review.")
        case .ingest: String(localized: "The text is split and indexed again, so Aria can cite it in answers. It takes a few minutes.")
        case .cancel: String(localized: "Every running step for this document stops. You can start it again later.")
        case .delete: String(localized: "Aria will no longer use it in answers. Data extracted from it stays unless you remove it too.")
        }
    }

    var confirmLabel: String {
        switch self {
        case .extract: String(localized: "Run extraction")
        case .ingest: String(localized: "Index again")
        case .cancel: String(localized: "Stop processing")
        case .delete: String(localized: "Delete document")
        }
    }

    var failureTitle: String {
        switch self {
        case .extract: String(localized: "Couldn't start extraction")
        case .ingest: String(localized: "Couldn't start indexing")
        case .cancel: String(localized: "Couldn't stop processing")
        case .delete: String(localized: "Couldn't delete the document")
        }
    }

    var isDestructive: Bool { self == .delete || self == .cancel }
}
