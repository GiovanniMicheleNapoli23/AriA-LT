//
//  AdminAgentStudioPromptsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I prompt di sistema degli agenti per l'azienda attiva (GET /v1/companies/{id}/agent-prompts):
//  quali agenti hanno un testo personalizzato e quali usano quello di base. L'editor è
//  AdminAgentStudioPromptEditorViewModel e rimanda qui il prompt salvato.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioPromptsViewModel {
    let backend: AriaBackend

    private(set) var prompts: [AdminAgentStudioAgentPrompt] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    @ObservationIgnored private var loadedKey: String?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    var loadKey: String { backend.activeCompanyId ?? "-" }

    func load() async {
        let key = loadKey
        if key != loadedKey {
            prompts = []
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AdminAgentStudioFailure.noCompanyMessage
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await backend.api.call(AdminAgentStudioAPI.agentPrompts(companyId: companyId)).items
            guard key == loadKey else { return }
            prompts = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            errorMessage = nil
            hasLoaded = true
        } catch {
            guard key == loadKey, let message = AdminAgentStudioFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    var overriddenCount: Int { prompts.count { $0.isOverridden } }

    func prompt(named name: String) -> AdminAgentStudioAgentPrompt? {
        prompts.first { $0.name == name }
    }

    /// Un prompt salvato o ripristinato nell'editor.
    func apply(_ prompt: AdminAgentStudioAgentPrompt) {
        if let index = prompts.firstIndex(where: { $0.name == prompt.name }) {
            prompts[index] = prompt
        } else {
            prompts.append(prompt)
        }
    }

    func makeEditor(name: String) -> AdminAgentStudioPromptEditorViewModel {
        AdminAgentStudioPromptEditorViewModel(backend: backend, name: name, prompt: prompt(named: name)) { [weak self] in
            self?.apply($0)
        }
    }

    func reset() {
        prompts = []
        errorMessage = nil
        isLoading = false
        hasLoaded = false
        loadedKey = nil
    }
}
