//
//  AriaVoiceViewModel.swift
//  Aria_v1.0
//
//  ViewModel @Observable per la sessione vocale nativa Aria Engine.
//  Fa da bridge tra AriaRealtimeSession (delegate) e SwiftUI.
//
//  AriaRealtimeSession usa API AVFoundation disponibili solo da iOS 27 (audio engine
//  strutturato, AVAudioSession async). Questo ViewModel resta invece utilizzabile fino a
//  iOS 18: la sessione vera si crea solo dentro connect(), tenuta come `Any?` (come
//  AriaLanguageModel per Apple Intelligence); prima di iOS 27, connect() fallisce con un
//  messaggio chiaro invece di offrire un microfono che non funzionerebbe.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaVoiceViewModel {

    // MARK: - State

    var isConnected = false
    var isConnecting = false
    var isSearchingDocs = false
    /// True quando il mic non è disponibile (es. Teams/Meet attivo)
    var isOutputOnly = false
    var error: String?

    // Transcript live per mostrare cosa sta dicendo l'utente / l'AI
    var assistantTranscript = ""
    var userTranscript = ""

    // MARK: - Private

    /// `AriaRealtimeSession`, tenuta come `Any?` perché il suo tipo esiste solo da iOS 27.
    @ObservationIgnored
    private var sessionBox: Any?
    /// Il delegate è `weak` nella sessione: va tenuto vivo da qui.
    @ObservationIgnored
    private var bridgeBox: Any?

    // MARK: - Actions

    func connect() {
        guard !isConnected, !isConnecting else { return }
        guard #available(iOS 27.0, *) else {
            error = String(localized: "Voice requires iOS 27 or later. Use text chat instead.")
            return
        }
        isConnecting = true
        error = nil

        let bridge = AriaRealtimeBridge(owner: self)
        let session = AriaRealtimeSession()
        session.delegate = bridge
        bridgeBox = bridge
        sessionBox = session

        Task {
            do {
                try await session.start()
            } catch {
                self.error = error.localizedDescription
                self.isConnecting = false
            }
        }
    }

    func disconnect() {
        if #available(iOS 27.0, *), let session = sessionBox as? AriaRealtimeSession {
            session.stop()
        }
        isConnected = false
        isConnecting = false
    }

    func toggleConnection() {
        isConnected ? disconnect() : connect()
    }

    var isMuted: Bool {
        get {
            guard #available(iOS 27.0, *), let session = sessionBox as? AriaRealtimeSession else { return false }
            return session.isMuted
        }
        set {
            guard #available(iOS 27.0, *), let session = sessionBox as? AriaRealtimeSession else { return }
            session.isMuted = newValue
        }
    }
}

// MARK: - Bridge verso AriaRealtimeSessionDelegate (solo iOS 27+)

/// Riceve i callback della sessione e li applica al ViewModel: separato da `AriaVoiceViewModel`
/// perché il protocollo (come la sessione) esiste solo da iOS 27, mentre il ViewModel deve
/// restare utilizzabile su tutte le versioni.
@available(iOS 27.0, *)
private final class AriaRealtimeBridge: AriaRealtimeSessionDelegate {
    private weak var owner: AriaVoiceViewModel?

    init(owner: AriaVoiceViewModel) {
        self.owner = owner
    }

    nonisolated func session(_ session: AriaRealtimeSession, didReceiveTranscript text: String, from speaker: AriaRealtimeSession.Speaker) {
        Task { @MainActor in
            switch speaker {
            case .assistant: owner?.assistantTranscript = text
            case .user:      owner?.userTranscript = text
            }
        }
    }

    nonisolated func session(_ session: AriaRealtimeSession, didChangeState state: AriaRealtimeSession.SessionState) {
        Task { @MainActor in
            guard let owner else { return }
            owner.isConnected  = (state == .connected)
            owner.isOutputOnly = session.isOutputOnly
            if state == .connected    { owner.isConnecting = false }
            if state == .disconnected {
                owner.isConnecting = false
                owner.isOutputOnly = false
                owner.assistantTranscript = ""
                owner.userTranscript = ""
            }
        }
    }

    nonisolated func session(_ session: AriaRealtimeSession, isSearchingDocuments: Bool) {
        Task { @MainActor in
            owner?.isSearchingDocs = isSearchingDocuments
        }
    }
}
