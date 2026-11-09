//
//  AIChatViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica della schermata Chat: il titolo (quello del backend, o la prima domanda), il menu "···"
//  e la chiusura intervento che parte quando il menu si è chiuso, e lo storico da ricaricare a turno finito.
//

import Foundation
import Observation

@MainActor
@Observable
final class AIChatViewModel {
    let app: AppViewModel

    // MARK: - State

    var showingOptions = false
    var closeout: AriaCloseoutChoice?
    /// La chiusura intervento scelta dal menu "···": parte quando il menu si è chiuso (un foglio alla volta).
    private var closeOutAfterOptions = false

    init(app: AppViewModel) {
        self.app = app
    }

    // MARK: - Derived

    var chat: AriaAgentChat { app.mainChat }
    var backend: AriaBackend { app.backend }
    /// La chiusura intervento si offre solo con il backend pronto.
    var offersCloseOut: Bool { backend.isReady }

    /// Il titolo che il backend dà alla sessione; finché non arriva, la prima domanda dell'operatore.
    var title: String {
        guard backend.isReady, let first = chat.messages.first(where: { $0.role == .user })?.text else {
            return String(localized: "New chat")
        }
        if let saved = app.sessions.sessions.first(where: { $0.sessionId == chat.sessionId })?.title,
           !saved.isEmpty {
            return saved
        }
        return first
    }

    // MARK: - Actions

    func showOptions() {
        showingOptions = true
    }

    /// Dal menu "···": la chiusura si presenta dopo che il menu si è chiuso.
    func closeOutAfterOptionsDismiss() {
        closeOutAfterOptions = true
    }

    func optionsDismissed() {
        guard closeOutAfterOptions else { return }
        closeOutAfterOptions = false
        closeout = AriaCloseoutChoice(workOrder: true, report: false)
    }

    /// A turno finito il backend ha (ri)generato il titolo: si ricaricano le sessioni.
    func streamingChanged(_ streaming: Bool) {
        guard !streaming, backend.isReady else { return }
        Task { await app.sessions.load() }
    }
}
