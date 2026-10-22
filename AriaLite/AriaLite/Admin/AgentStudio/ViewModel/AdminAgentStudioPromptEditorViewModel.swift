//
//  AdminAgentStudioPromptEditorViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La modifica del prompt di sistema di un agente: salva il testo come override dell'azienda (PUT)
//  o torna al prompt di base (DELETE). Gli avvisi del server sul testo salvato si mostrano sotto.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioPromptEditorViewModel {
    let backend: AriaBackend
    let name: String

    private(set) var prompt: AdminAgentStudioAgentPrompt?
    var text: String
    private(set) var warnings: [String] = []
    private(set) var isSaving = false
    private(set) var isResetting = false
    private(set) var savedAt: Date?
    var showsResetConfirmation = false
    var actionError: String?

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    @ObservationIgnored private let onSaved: (AdminAgentStudioAgentPrompt) -> Void

    init(backend: AriaBackend, name: String, prompt: AdminAgentStudioAgentPrompt?,
         onSaved: @escaping (AdminAgentStudioAgentPrompt) -> Void) {
        self.backend = backend
        self.name = name
        self.prompt = prompt
        self.text = prompt?.effectivePrompt ?? ""
        self.onSaved = onSaved
    }

    var isBusy: Bool { isSaving || isResetting }

    var hasChanges: Bool { text != (prompt?.effectivePrompt ?? "") }

    var canSave: Bool {
        hasChanges && !isBusy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canReset: Bool { (prompt?.isOverridden ?? false) && !isBusy }

    var characterCount: String {
        let count = text.count
        return String(localized: "\(count) characters")
    }

    func discardChanges() {
        text = prompt?.effectivePrompt ?? ""
    }

    func save() async {
        guard canSave, let companyId = backend.activeCompanyId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let response = try await backend.api.call(
                AdminAgentStudioAPI.saveAgentPrompt(companyId: companyId, agent: name, prompt: text))
            warnings = response.warnings
            if let saved = response.prompt { applySaved(saved) }
            savedAt = .now
        } catch {
            actionError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }

    func resetToBase() async {
        guard canReset, let companyId = backend.activeCompanyId else { return }
        isResetting = true
        defer { isResetting = false }
        do {
            let restored = try await backend.api.call(AdminAgentStudioAPI.resetAgentPrompt(companyId: companyId, agent: name)).value
            warnings = []
            applySaved(restored)
            savedAt = .now
        } catch {
            actionError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }

    private func applySaved(_ saved: AdminAgentStudioAgentPrompt) {
        prompt = saved
        text = saved.effectivePrompt
        onSaved(saved)
    }
}
