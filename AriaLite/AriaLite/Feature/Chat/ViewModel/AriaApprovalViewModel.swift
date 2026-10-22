//
//  AriaApprovalViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica della card di approvazione (interrupt-approval-card della web): ogni parametro semplice
//  è modificabile; se cambia qualcosa, "Approva con modifiche" manda decision "edit" con gli args completi.
//  Nasce con una pausa: un'altra pausa è un view model nuovo (identità della vista).
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaApprovalViewModel {
    let interrupt: AriaInterrupt
    private let onDecide: (AriaResumeDecision) -> Void

    /// I parametri come li vede l'operatore, con le sue modifiche.
    private(set) var edited: [String: AriaJSON]

    init(interrupt: AriaInterrupt, onDecide: @escaping (AriaResumeDecision) -> Void) {
        self.interrupt = interrupt
        self.onDecide = onDecide
        edited = interrupt.args ?? [:]
    }

    // MARK: - Derived

    private var original: [String: AriaJSON] { interrupt.args ?? [:] }
    var isEdited: Bool { edited != original }
    var keys: [String] { original.keys.sorted() }
    var toolLabel: String { AriaChatCopy.toolLabel(interrupt.name ?? "") }
    var warning: String? { interrupt.warning.flatMap { $0.isEmpty ? nil : $0 } }

    func value(_ key: String) -> AriaJSON {
        edited[key] ?? original[key] ?? .null
    }

    /// "work_order_id" → "Work order id".
    func label(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }

    /// Uno spostamento di calendario in sola lettura: "WO 12 · Titolo: da → a".
    func moveDescription(_ move: AriaJSON) -> String {
        let id = (move["work_order_id"] ?? move["workOrderId"] ?? move["id"])?.stringValue ?? ""
        let to = (move["due_date"] ?? move["dueDate"] ?? move["to"])?.stringValue ?? ""
        let title = move["title"]?.stringValue.map { " · \($0)" } ?? ""
        let from = move["from"]?.stringValue.map { "\($0) → " } ?? ""
        return "WO \(id)\(title): \(from)\(to)"
    }

    // MARK: - Actions

    func set(_ key: String, _ value: AriaJSON) {
        edited[key] = value
    }

    func approve() {
        onDecide(isEdited ? .edit(edited) : .approve)
    }

    func reject() {
        onDecide(.reject)
    }
}
