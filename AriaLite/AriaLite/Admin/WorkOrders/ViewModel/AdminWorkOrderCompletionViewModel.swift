//
//  AdminWorkOrderCompletionViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio "Complete": le note di chiusura e POST /v1/work-orders/{id}/complete. Se mancano risultati
//  dei passi il server rifiuta (`steps_incomplete`) e dal foglio si va alla scheda dei passi.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderCompletionViewModel: Identifiable {
    let order: AdminWorkOrder
    private let backend: AriaBackend
    private let onCompleted: (AdminWorkOrder) -> Void
    /// Dal dettaglio: chiude il foglio e apre i passi. `nil` dalla lista.
    let showSteps: (() -> Void)?

    var notes: String
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    /// Il server vuole un risultato per ogni passo prima di chiudere.
    private(set) var isMissingSteps = false
    private(set) var isDone = false

    static let maxLength = 2000

    init(order: AdminWorkOrder, backend: AriaBackend, showSteps: (() -> Void)?,
         onCompleted: @escaping (AdminWorkOrder) -> Void) {
        self.order = order
        self.backend = backend
        self.showSteps = showSteps
        self.onCompleted = onCompleted
        notes = order.resolutionNotes ?? ""
    }

    var id: String { order.id }

    private var trimmed: String { notes.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSubmit: Bool { !trimmed.isEmpty && trimmed.count <= Self.maxLength && !isSaving }

    var isTooLong: Bool { trimmed.count > Self.maxLength }

    func submit() async {
        guard canSubmit else { return }
        isSaving = true
        errorMessage = nil
        isMissingSteps = false
        defer { isSaving = false }
        do {
            let completed = try await AdminWorkOrdersAPI(api: backend.api).complete(order.id, resolutionNotes: trimmed)
            onCompleted(completed)
            isDone = true
        } catch {
            if case .workOrder(.stepsIncomplete, _)? = error as? AriaError { isMissingSteps = true }
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }
}
