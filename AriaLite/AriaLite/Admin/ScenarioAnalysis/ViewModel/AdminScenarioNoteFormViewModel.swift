//
//  AdminScenarioNoteFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form "Add note": una nota dell'admin sulla traccia della procedura. Si aggiunge e non si modifica più
//  (è una prova di cosa si è detto e quando): una seconda opinione è una seconda nota.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioNoteFormViewModel: Identifiable {
    let backend: AriaBackend
    let review: AdminScenarioSessionReview
    @ObservationIgnored private let onSaved: (AdminScenarioFeedbackEvent) -> Void

    var note = ""
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(backend: AriaBackend, review: AdminScenarioSessionReview,
         onSaved: @escaping (AdminScenarioFeedbackEvent) -> Void) {
        self.backend = backend
        self.review = review
        self.onSaved = onSaved
    }

    var title: String { review.displayTitle }
    private var trimmed: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSave: Bool { !isSaving && !trimmed.isEmpty }

    /// `true` se salvata (la vista chiude il form).
    func save() async -> Bool {
        guard canSave else { return false }
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return false
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let event = try await backend.api.call(AdminScenarioAnalysisAPI.addNote(
                companyId: companyId, sessionId: review.sessionId, episode: review.episode, note: trimmed))
            onSaved(event)
            return true
        } catch {
            errorMessage = AdminScenarioFailure.message(for: error, backend: backend)
            return false
        }
    }
}
