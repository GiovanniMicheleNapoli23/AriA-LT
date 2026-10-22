//
//  AriaAgentMessageView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Un messaggio della chat, nello stesso ordine della web (agent-message-body):
//  strumenti, fonti, ragionamento, testo, conoscenza usata, card, immagini,
//  eventi CMMS, checklist, azioni, proposte di memoria, approvazione, errore,
//  barra (copia, leggi, voto, rigenera) e chip di follow-up.
//  La logica sta in AriaAgentMessageViewModel.
//

import SwiftUI

struct AriaAgentMessageView: View {
    let message: AriaAgentMessage
    var isLast: Bool
    /// Per l'animazione "hero" dalla sfera della chat vuota a quella sotto l'ultima risposta.
    var orbNamespace: Namespace.ID? = nil

    @Environment(\.openURL) private var openURL
    @State private var model: AriaAgentMessageViewModel

    /// Un view model per messaggio: la lista è un `ForEach` per id, quindi nasce e muore con il messaggio.
    init(message: AriaAgentMessage, chat: AriaAgentChat, webBase: URL, isLast: Bool, orbNamespace: Namespace.ID? = nil) {
        self.message = message
        self.isLast = isLast
        self.orbNamespace = orbNamespace
        _model = State(initialValue: AriaAgentMessageViewModel(chat: chat, webBase: webBase))
    }

    var body: some View {
        if message.role == .user {
            userBubble
        } else {
            assistant
        }
    }

    // MARK: Utente

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 55)
            Text(message.text)
                .font(.callout)
                .foregroundStyle(Color.liteOnAccent)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .textSelection(.enabled)
        }
    }

    // MARK: Assistente

    /// Come Claude: il testo occupa tutta la larghezza e il blob di Aria sta sotto l'ultima risposta.
    private var assistant: some View {
        let actions = model.artifactActions { openURL($0) }
        return VStack(alignment: .leading, spacing: 10) {
            if !message.toolCalls.isEmpty { AriaMessageActivityStrip(calls: message.toolCalls) }
            if !message.sources.isEmpty { AriaMessageSources(sources: message.sources, isExpanded: $model.showSources) }
            if !message.reasoning.isEmpty { AriaMessageReasoning(text: message.reasoning, isExpanded: $model.showReasoning) }

            if !message.displayText.isEmpty {
                // Senza bolla: la bolla è solo per i messaggi dell'operatore.
                AriaMarkdownView(text: message.displayText)
                    .padding(.top, 4)
            }

            if !message.memoryFactsUsed.isEmpty {
                AriaMessageFactsUsed(facts: message.memoryFactsUsed, isExpanded: $model.showFacts)
            }

            ForEach(message.artifacts.filter(\.isDeliverable)) { AriaArtifactView(artifact: $0, actions: actions) }
            ForEach(message.artifacts.filter { !$0.isDeliverable }) { AriaArtifactView(artifact: $0, actions: actions) }

            if !message.images.isEmpty { AriaMessageImages(images: message.images) }
            AriaMessageCMMSNotices(pipeline: message.pipeline) { type, id in
                if let url = model.url(for: model.entityPath(type: type, id: id)) { openURL(url) }
            }

            if let list = model.checklist(message) {
                AriaTaskChecklistCard(list: list, messageId: message.id, chat: model.chat,
                                      isLatest: model.isLatestChecklist(message))
            }

            let links = model.linkActions(message)
            if !links.isEmpty {
                AriaMessageActionBar(actions: links) { target in
                    if let url = model.url(for: target) { openURL(url) }
                }
            }

            if message.finished, !message.memoryLearned.isEmpty {
                Label(String(localized: "Aria learned \(message.memoryLearned.count) new facts"), systemImage: "brain")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.canConfirmMemory {
                ForEach(message.memoryProposals) { proposal in
                    AriaMemoryProposalCard(proposal: proposal, chat: model.chat) { accept, content in
                        model.confirmMemory(proposal, in: message, accept: accept, content: content)
                    }
                }
            }

            if model.showsLearningChip(message) {
                AriaLearningChip { model.openLearning(message) }
            }

            if let interrupt = model.pendingApproval(message) {
                AriaApprovalCard(interrupt: interrupt) { model.resume($0) }
            } else if let outcome = message.interruptOutcome {
                AriaInterruptOutcomeLine(outcome: outcome)
            }

            if let error = message.error {
                if message.errorIsOffline {
                    AriaOfflineNotice(style: .compact)
                } else {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if model.showsToolbar(message) {
                AriaMessageToolbar(model: model, message: message)
            }
            if model.showsFollowUps(message, isLast: isLast) {
                AriaMessageFollowUps(chips: model.followUps(message), isEnabled: !model.isStreaming) {
                    model.sendFollowUp($0)
                }
            }

            // La sfera chiude sempre l'ultima risposta e scende insieme al testo che cresce;
            // "Thinking" le sta accanto solo finché non arriva il testo.
            if isLast {
                HStack(spacing: 10) {
                    AriaOrb(mood: message.finished ? .idle : .thinking)
                        .ariaOrbHero(orbNamespace)
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 3)
                        .accessibilityHidden(true)
                    if model.isThinking(message) {
                        AriaThinkingText()
                            .transition(.opacity)
                    }
                }
                .padding(.top, 2)
                .animation(.easeInOut(duration: 0.25), value: model.isThinking(message))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaLinks(model.webBase)
        .sensoryFeedback(.success, trigger: model.copied) { _, new in new }
        .sensoryFeedback(.selection, trigger: message.vote)
        .sensoryFeedback(.impact(weight: .light), trigger: model.taps)
        .alert("What was wrong?", isPresented: $model.askingDownNote) {
            TextField("Optional note", text: $model.downNote)
            Button("Cancel", role: .cancel) { model.cancelDownNote() }
            Button("Send") { model.sendDownNote(message) }
        }
    }
}
