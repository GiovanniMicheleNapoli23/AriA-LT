//
//  AriaAgentMessageViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica di un messaggio della chat: cosa mostrare (barra, follow-up, chip del Real-time Learning,
//  approvazione) e le azioni (copia, leggi, voto con nota, rigenera, apri un link, ricordi da confermare).
//  Il messaggio cambia a ogni pezzo in streaming: non si copia qui, arriva dalla vista a ogni lettura.
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class AriaAgentMessageViewModel {
    let chat: AriaAgentChat
    let webBase: URL

    // MARK: - State

    var showReasoning = false
    var showSources = false
    var showFacts = false
    private(set) var copied = false
    /// Tocchi che non mandano un turno (leggi ad alta voce, tieni/scarta un ricordo): l'invio lo segnala la chat.
    private(set) var taps = 0
    var downNote = ""
    var askingDownNote = false

    init(chat: AriaAgentChat, webBase: URL) {
        self.chat = chat
        self.webBase = webBase
    }

    // MARK: - Derived

    var isStreaming: Bool { chat.isStreaming }
    var canConfirmMemory: Bool { chat.canConfirmMemory }
    var canRegenerate: Bool { !chat.isStreaming && chat.pendingInterrupt == nil }

    /// Aria sta lavorando ma non ha ancora scritto niente.
    /// `displayText`: il testo già calcolato dalla vista (costa, lo si calcola una volta per body).
    func isThinking(_ message: AriaAgentMessage, displayText: String? = nil) -> Bool {
        !message.finished && (displayText ?? message.displayText).isEmpty
    }

    /// Con la domanda nella stessa risposta la checklist vive solo nel pannello in basso
    /// (AriaProcedureDock): in chat sarebbe un doppione.
    func checklist(_ message: AriaAgentMessage) -> AriaTaskList? {
        message.elicitation == nil ? message.taskList : nil
    }

    func isLatestChecklist(_ message: AriaAgentMessage) -> Bool {
        chat.latestTaskList?.messageId == message.id
    }

    /// Il pannello in fondo la pone già per l'ultima risposta: il chip serve per riaprirla da qui.
    func showsLearningChip(_ message: AriaAgentMessage) -> Bool {
        !chat.isStreaming && chat.canAnswerLearning(message) && chat.activeLearning?.messageId != message.id
    }

    /// Un'approvazione da decidere qui (il LOTO ha il suo foglio).
    func pendingApproval(_ message: AriaAgentMessage) -> AriaInterrupt? {
        guard let interrupt = message.interrupt, interrupt.kind != .loto, !chat.isStreaming else { return nil }
        return interrupt
    }

    func showsToolbar(_ message: AriaAgentMessage, displayText: String? = nil) -> Bool {
        guard message.finished else { return false }
        return !(displayText ?? message.displayText).isEmpty || !message.artifacts.isEmpty
    }

    func showsFollowUps(_ message: AriaAgentMessage, isLast: Bool) -> Bool {
        isLast && message.finished && message.interrupt == nil && chat.activeElicitation == nil
    }

    func followUps(_ message: AriaAgentMessage) -> [AriaChatCopy.FollowUp] {
        AriaChatCopy.followUps(for: message)
    }

    /// ui-action-bar della web: nessuna navigazione automatica, solo pulsanti (uno per destinazione).
    func linkActions(_ message: AriaAgentMessage) -> [AriaUIAction] {
        let unique = message.uiActions.reduce(into: [AriaUIAction]()) { list, action in
            if !list.contains(where: { $0.to == action.to }) { list.append(action) }
        }
        return unique.filter { $0.to != nil && ($0.action == "navigate" || $0.action == "open-external") }
    }

    func usageText(_ message: AriaAgentMessage) -> String? {
        guard let usage = message.usage, let input = usage.inputTokens, let output = usage.outputTokens else { return nil }
        return "↑\(input) ↓\(output)"
    }

    /// Le card mandano domande, comandi rapidi e link.
    func artifactActions(open: @escaping (URL) -> Void) -> AriaArtifactActions {
        AriaArtifactActions(
            ask: { [chat] in chat.send($0) },
            quick: { [chat] in chat.sendQuick(label: $0, tool: $1, args: $2) },
            open: { [weak self] path in if let url = self?.url(for: path) { open(url) } }
        )
    }

    /// Un link della risposta: relativo alla web app oppure assoluto, sempre filtrato da AriaURLPolicy.
    func url(for target: String) -> URL? {
        let url = URL(string: target).flatMap { $0.scheme == nil ? URL(string: target, relativeTo: webBase)?.absoluteURL : $0 }
        return url.flatMap(AriaURLPolicy.external)
    }

    /// Il percorso web di un'entità CMMS citata (es. work_order 12 → /work-orders/12).
    func entityPath(type: String, id: String) -> String {
        "/\(type.replacingOccurrences(of: "_", with: "-"))s/\(id)"
    }

    // MARK: - Actions

    func copy(_ message: AriaAgentMessage) {
        AriaPasteboard.copy(message.displayText)
        copied = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            self?.copied = false
        }
    }

    func readAloud(_ message: AriaAgentMessage) {
        AriaSpeech.shared.toggle(message.displayText)
        taps += 1
    }

    func voteUp(_ message: AriaAgentMessage) {
        chat.vote(message.id, .up)
    }

    /// Il pollice giù chiede una nota; se il voto c'è già, lo toglie.
    func voteDown(_ message: AriaAgentMessage) {
        if message.vote == .down { chat.vote(message.id, .down) } else { askingDownNote = true }
    }

    func sendDownNote(_ message: AriaAgentMessage) {
        let note = downNote.trimmingCharacters(in: .whitespacesAndNewlines)
        chat.vote(message.id, .down, note: note.isEmpty ? nil : note)
        downNote = ""
    }

    func cancelDownNote() {
        downNote = ""
    }

    func regenerate(_ message: AriaAgentMessage) {
        chat.regenerate(message.id)
    }

    func sendFollowUp(_ chip: AriaChatCopy.FollowUp) {
        chat.send(chip.prompt)
    }

    func openLearning(_ message: AriaAgentMessage) {
        chat.openLearning(message.id)
    }

    func resume(_ decision: AriaResumeDecision) {
        chat.resume(decision)
    }

    func confirmMemory(_ proposal: AriaMemoryProposal, in message: AriaAgentMessage, accept: Bool, content: String?) {
        taps += 1
        chat.confirmMemory(proposal, in: message.id, accept: accept, content: content)
    }
}
