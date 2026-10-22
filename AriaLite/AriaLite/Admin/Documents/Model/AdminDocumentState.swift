//
//  AdminDocumentState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli stati di una pipeline del documento (DocumentState del backend) e il gruppo che si mostra:
//  in elaborazione, pronto, fallito, annullato, in cancellazione. Un valore nuovo del server resta
//  leggibile (etichetta dal valore grezzo) e conta come "in elaborazione" solo se è tra quelli noti.
//

import SwiftUI

nonisolated enum AdminDocumentState: String, Sendable, CaseIterable {
    case queued, fetching, parsing, chunking, embedding, indexing, classifying, extracting, validating, persisting
    case completed, failed, canceled, paused
    case pendingDeletion = "pending_deletion"
    case deleted

    /// La pipeline sta lavorando: la lista e il dettaglio si aggiornano da soli.
    var isActive: Bool {
        switch self {
        case .queued, .fetching, .parsing, .chunking, .embedding, .indexing, .classifying, .extracting,
             .validating, .persisting, .pendingDeletion:
            true
        case .completed, .failed, .canceled, .paused, .deleted:
            false
        }
    }

    var label: String {
        switch self {
        case .queued: String(localized: "Queued")
        case .fetching: String(localized: "Fetching")
        case .parsing: String(localized: "Parsing")
        case .chunking: String(localized: "Chunking")
        case .embedding: String(localized: "Embedding")
        case .indexing: String(localized: "Indexing")
        case .classifying: String(localized: "Classifying")
        case .extracting: String(localized: "Extracting")
        case .validating: String(localized: "Validating")
        case .persisting: String(localized: "Saving")
        case .completed: String(localized: "Completed")
        case .failed: String(localized: "Failed")
        case .canceled: String(localized: "Canceled")
        case .paused: String(localized: "Paused")
        case .pendingDeletion: String(localized: "Deleting")
        case .deleted: String(localized: "Deleted")
        }
    }

    /// Etichetta anche per un valore che l'app non conosce ("new_state" → "New state").
    static func label(for raw: String) -> String {
        if let known = AdminDocumentState(rawValue: raw) { return known.label }
        let words = raw.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

/// Lo stato complessivo di un documento, che unisce indicizzazione ed estrazione.
nonisolated enum AdminDocumentStatusGroup: String, Sendable, CaseIterable, Identifiable {
    case processing, ready, failed, canceled, deleting

    var id: String { rawValue }

    var label: String {
        switch self {
        case .processing: String(localized: "Processing")
        case .ready: String(localized: "Ready")
        case .failed: String(localized: "Failed")
        case .canceled: String(localized: "Canceled")
        case .deleting: String(localized: "Deleting")
        }
    }

    var systemImage: String {
        switch self {
        case .processing: "arrow.triangle.2.circlepath"
        case .ready: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .canceled: "xmark.circle"
        case .deleting: "trash"
        }
    }

    var tint: Color {
        switch self {
        case .processing: .blue
        case .ready: .green
        case .failed: .orange
        case .canceled, .deleting: .secondary
        }
    }

    /// Dagli stati delle due pipeline (grezzi, possono mancare). Conta il peggiore:
    /// cancellazione, poi lavoro in corso, errore, annullamento; altrimenti è pronto.
    static func from(ingestion: String?, extraction: String?) -> AdminDocumentStatusGroup {
        let states = [ingestion, extraction].compactMap { $0.flatMap(AdminDocumentState.init(rawValue:)) }
        if states.contains(where: { $0 == .pendingDeletion || $0 == .deleted }) { return .deleting }
        if states.contains(where: \.isActive) { return .processing }
        if states.contains(.failed) { return .failed }
        if states.contains(.canceled) || states.contains(.paused) { return .canceled }
        return .ready
    }
}
