//
//  AriaVoiceViewModel.swift
//  Aria_v1.0
//
//  ViewModel @Observable per la sessione vocale nativa Aria Engine.
//  Fa da bridge tra AriaRealtimeSession (delegate) e SwiftUI.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaVoiceViewModel: AriaRealtimeSessionDelegate {

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

    @ObservationIgnored
    private let session = AriaRealtimeSession()

    init() {
        session.delegate = self
    }

    // MARK: - Actions

    func connect() {
        guard !isConnected, !isConnecting else { return }
        isConnecting = true
        error = nil

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
        session.stop()
        isConnected = false
        isConnecting = false
    }

    func toggleConnection() {
        isConnected ? disconnect() : connect()
    }

    var isMuted: Bool {
        get { session.isMuted }
        set { session.isMuted = newValue }
    }

    // MARK: - AriaRealtimeSessionDelegate

    nonisolated func session(_ session: AriaRealtimeSession, didReceiveTranscript text: String, from speaker: AriaRealtimeSession.Speaker) {
        Task { @MainActor in
            switch speaker {
            case .assistant: self.assistantTranscript = text
            case .user:      self.userTranscript = text
            }
        }
    }

    nonisolated func session(_ session: AriaRealtimeSession, didChangeState state: AriaRealtimeSession.SessionState) {
        Task { @MainActor in
            self.isConnected  = (state == .connected)
            self.isOutputOnly = session.isOutputOnly
            if state == .connected    { self.isConnecting = false }
            if state == .disconnected {
                self.isConnecting = false
                self.isOutputOnly = false
                self.assistantTranscript = ""
                self.userTranscript = ""
            }
        }
    }

    nonisolated func session(_ session: AriaRealtimeSession, isSearchingDocuments: Bool) {
        Task { @MainActor in
            self.isSearchingDocs = isSearchingDocuments
        }
    }
}
