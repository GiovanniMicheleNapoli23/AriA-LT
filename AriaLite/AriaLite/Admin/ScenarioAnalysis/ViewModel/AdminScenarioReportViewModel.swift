//
//  AdminScenarioReportViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il report .docx di una procedura (GET …/sessions/{id}/report.docx via AriaChatAPI.reportDocument),
//  nella lingua dell'app. Il file finisce in una cartella temporanea: la vista lo apre in anteprima o lo condivide.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioReportViewModel {
    enum State: Equatable {
        case idle
        case loading
        case ready(AriaReportFile)
        case failed(String)
    }

    let backend: AriaBackend
    let sessionId: String
    /// Sempre passata: senza, il server scrive il report della procedura in corso, non di questa.
    let episode: Int
    let title: String?
    let workOrderId: String?

    private(set) var state: State = .idle

    init(backend: AriaBackend, sessionId: String, episode: Int, title: String?, workOrderId: String? = nil) {
        self.backend = backend
        self.sessionId = sessionId
        self.episode = episode
        self.title = title
        self.workOrderId = workOrderId
    }

    var isLoading: Bool { state == .loading }

    var file: AriaReportFile? {
        if case .ready(let file) = state { return file }
        return nil
    }

    var errorMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    func download() async {
        guard !isLoading else { return }
        guard let companyId = backend.activeCompanyId else {
            state = .failed(AriaError.missingCompany.localizedDescription)
            return
        }
        state = .loading
        do {
            let file = try await AriaChatAPI(api: backend.api).reportDocument(
                companyId: companyId, sessionId: sessionId, locale: backend.api.context.locale,
                episode: episode, title: title, workOrderId: workOrderId)
            state = .ready(file)
        } catch {
            if let message = AdminScenarioFailure.message(for: error, backend: backend) {
                state = .failed(message)
            } else {
                state = .idle
            }
        }
    }
}
