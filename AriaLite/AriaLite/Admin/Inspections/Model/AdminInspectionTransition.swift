//
//  AdminInspectionTransition.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I cambi di stato che il dettaglio offre (avvia, completa, riapri, annulla) e da quale stato si possono fare.
//  Il server non dichiara una macchina a stati: i valori scritti sono IPOTESI (vedi AdminInspectionStatus).
//

import Foundation

nonisolated enum AdminInspectionTransition: String, CaseIterable, Identifiable, Sendable {
    case start, complete, reopen, cancel

    var id: String { rawValue }

    /// Lo stato in cui l'ispezione finisce.
    var target: AdminInspectionStatus {
        switch self {
        case .start, .reopen: .inProgress
        case .complete: .completed
        case .cancel: .cancelled
        }
    }

    var title: String {
        switch self {
        case .start: String(localized: "Start inspection")
        case .complete: String(localized: "Complete inspection")
        case .reopen: String(localized: "Reopen")
        case .cancel: String(localized: "Cancel inspection")
        }
    }

    var systemImage: String {
        switch self {
        case .start: "play.fill"
        case .complete: "checkmark.seal.fill"
        case .reopen: "arrow.uturn.backward"
        case .cancel: "xmark.circle"
        }
    }

    /// Le azioni possibili da uno stato; uno stato sconosciuto si tratta come "da fare".
    static func available(from status: AdminInspectionStatus?) -> [Self] {
        switch status {
        case nil, .pending?: [.start, .complete, .cancel]
        case .inProgress?: [.complete, .cancel]
        case .completed?, .cancelled?: [.reopen]
        }
    }
}
