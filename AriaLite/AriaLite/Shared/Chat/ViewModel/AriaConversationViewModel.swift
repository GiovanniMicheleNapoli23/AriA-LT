//
//  AriaConversationViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica della conversazione riusabile: la chat del chiamante, oppure una propria con il contesto
//  del passo (che viaggia col primo messaggio); la voce dal vivo; il collegamento al server se manca.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaConversationViewModel {
    let backend: AriaBackend
    /// Chat del chiamante (la schermata tiene quella principale); nil = una chat propria con il contesto del passo.
    private let agentChat: AriaAgentChat?
    /// Contesto già scritto (ordine e passo di un lavoro Aria): viaggia col primo messaggio.
    private let contextText: String?

    // MARK: - State

    private(set) var ownChat: AriaAgentChat?
    let voice = AriaVoiceViewModel()
    var showConnection = false

    init(backend: AriaBackend, agentChat: AriaAgentChat?, contextText: String?) {
        self.backend = backend
        self.agentChat = agentChat
        self.contextText = contextText
    }

    // MARK: - Derived

    var isConnected: Bool { backend.isReady }
    var chat: AriaAgentChat? { agentChat ?? ownChat }

    // MARK: - Actions

    /// Senza chat del chiamante se ne crea una propria, con il contesto del passo (modo A della guida).
    func makeOwnChatIfNeeded() {
        guard agentChat == nil, ownChat == nil else { return }
        let context = contextText.map { "[Work order context]\n\($0)" }
        ownChat = AriaAgentChat(backend: backend, context: context)
    }

    func connect() {
        showConnection = true
    }
}
