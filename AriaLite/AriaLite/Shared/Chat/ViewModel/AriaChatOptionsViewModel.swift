//
//  AriaChatOptionsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica del menu "···" della chat: gli step della procedura (corrente e precedenti), il report in
//  Word, la chiusura intervento e la fine procedura.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaChatOptionsViewModel {
    let chat: AriaAgentChat
    /// Chi apre il foglio sa presentare la chiusura intervento.
    let offersCloseOut: Bool

    // MARK: - State

    var confirmingEnd = false
    private(set) var report: AriaReportFile?
    private(set) var preparingReport = false
    private(set) var reportError: String?

    init(chat: AriaAgentChat, offersCloseOut: Bool) {
        self.chat = chat
        self.offersCloseOut = offersCloseOut
    }

    // MARK: - Derived

    /// Dal più recente: il primo è lo step corrente.
    var steps: [(messageId: String, list: AriaTaskList)] { chat.sessionTaskLists }
    var currentStep: (messageId: String, list: AriaTaskList)? { steps.first }
    var previousSteps: [(messageId: String, list: AriaTaskList)] { Array(steps.dropFirst()) }

    var canDownloadReport: Bool { chat.canDownloadReport }
    var canPrepareReport: Bool { !preparingReport && !chat.isStreaming }

    var canCloseOut: Bool { offersCloseOut && chat.canCloseOut }
    var isCloseOutEnabled: Bool { !chat.messages.isEmpty && !chat.isStreaming }

    var canEndProcedure: Bool { !steps.isEmpty }
    var isEndProcedureEnabled: Bool { !chat.isStreaming && chat.pendingInterrupt == nil }

    var showsSessionActions: Bool { canCloseOut || canEndProcedure }

    // MARK: - Actions

    func prepareReport() async {
        preparingReport = true
        defer { preparingReport = false }
        reportError = nil
        do {
            report = try await chat.reportDocument()
        } catch AriaError.http(404, _) {
            // La chat non ha una procedura da riportare: la riga sparisce (`canDownloadReport`).
        } catch {
            reportError = error.localizedDescription
        }
    }

    func askToEndProcedure() {
        confirmingEnd = true
    }

    func endProcedure() {
        chat.endProcedure()
    }
}
