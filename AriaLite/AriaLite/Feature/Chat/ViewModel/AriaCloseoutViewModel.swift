//
//  AriaCloseoutViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica della chiusura intervento: anteprima senza scrivere niente, modulo precompilato dalla
//  proposta, conferma che scrive l'ordine (ARIA, e MaintainX se collegato) o archivia solo il report,
//  e gli errori del server (valori che MaintainX non ha, nessuna procedura da chiudere).
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaCloseoutViewModel {
    let chat: AriaAgentChat
    let choice: AriaCloseoutChoice

    // MARK: - State

    private(set) var proposal: AriaCloseoutProposal?
    var request = AriaCloseoutRequest()
    private(set) var result: AriaCloseoutResult?
    private(set) var archive: AriaReportArchive?
    private(set) var busy = false
    private(set) var error: String?
    /// I valori accettati che il server ha mandato con un 422 (`detail.valid`), per campo: i picker si rifanno da qui.
    private(set) var validChoices: [String: [String]] = [:]

    init(chat: AriaAgentChat, choice: AriaCloseoutChoice) {
        self.chat = chat
        self.choice = choice
    }

    // MARK: - Derived

    var isDone: Bool { result != nil || archive != nil }
    var canConfirm: Bool { !busy && chat.canCloseOut && (!choice.workOrder || proposal != nil) }
    /// Solo il report non ha niente da approvare: si archivia alla conferma.
    var isReportOnly: Bool { !choice.workOrder }
    var isLoadingPreview: Bool { choice.workOrder && proposal == nil && error == nil && !isDone }
    var isOperator: Bool { chat.isOperator }

    var categoryOptions: [String]? {
        guard let options = validChoices["category"] ?? proposal?.categoryOptions, !options.isEmpty else { return nil }
        return options
    }

    var locationOptions: [String]? {
        guard let locations = validChoices["location"] ?? proposal?.locationOptions?.map(\.name), !locations.isEmpty else { return nil }
        return locations
    }

    /// Dove verrà scritto l'ordine, con i nomi dei sistemi.
    var targetsText: String? {
        guard let targets = proposal?.targets, !targets.isEmpty else { return nil }
        return targets.map { $0 == "aria" ? "ARIA" : $0 == "maintainx" ? "MaintainX" : $0 }.joined(separator: " + ")
    }

    /// Un operatore non vede gli ordini dei colleghi (la lista arriva vuota) e non può spostarli.
    var conflicts: [AriaCloseoutProposal.Conflict]? {
        guard !chat.isOperator, let conflicts = proposal?.conflicts, !conflicts.isEmpty else { return nil }
        return conflicts
    }

    var assigneeCandidates: [AriaCloseoutProposal.Candidate] { proposal?.assignee?.candidates ?? [] }

    /// L'operatore può solo prendere il lavoro per sé: la preselezione della proposta, se è un altro.
    var proposedAssigneeName: String? {
        guard chat.isOperator, let me = chat.operatorId, let preselected = proposal?.assignee?.selected,
              preselected != me else { return nil }
        return assigneeCandidates.first(where: { $0.id == preselected })?.name
    }

    var canAssignToMe: Bool { chat.isOperator && chat.operatorId != nil }

    var assignedToMe: Bool {
        get { request.assigneeId != nil && request.assigneeId == chat.operatorId }
        set { request.assigneeId = newValue ? chat.operatorId : nil }
    }

    var priority: String {
        get { request.priority ?? "medium" }
        set { request.priority = newValue }
    }

    var conflictChoice: String {
        get { request.conflictChoice ?? "file" }
        set { request.conflictChoice = newValue }
    }

    func text(_ key: WritableKeyPath<AriaCloseoutRequest, String?>) -> String {
        request[keyPath: key] ?? ""
    }

    func setText(_ key: WritableKeyPath<AriaCloseoutRequest, String?>, _ value: String) {
        request[keyPath: key] = value
    }

    // MARK: - Actions

    private func base() -> AriaCloseoutRequest {
        var body = AriaCloseoutRequest(workOrder: choice.workOrder, report: choice.report)
        body.assigneeId = choice.assigneeId
        body.priority = choice.priority
        body.dueDate = choice.dueDate
        return body
    }

    func loadPreview() async {
        // Solo il report non ha niente da approvare: si archivia alla conferma.
        guard choice.workOrder else { request = base(); return }
        do {
            let preview = try await chat.closeout(base())
            guard let p = preview.proposal else {
                error = String(localized: "The server didn't return a proposal.")
                return
            }
            proposal = p
            var body = base()
            body.title = p.title
            body.priority = choice.priority ?? p.priority
            body.category = p.category
            body.dueDate = choice.dueDate ?? p.dueDate
            body.assigneeId = choice.assigneeId ?? p.assignee?.selected
            if chat.isOperator, body.assigneeId != chat.operatorId { body.assigneeId = nil }
            body.startDate = p.startDate
            body.recurrenceType = p.recurrenceType
            body.recurrenceInterval = p.recurrenceInterval
            request = body
        } catch {
            show(error)
        }
    }

    func confirm() async {
        busy = true
        defer { busy = false }
        do {
            if choice.workOrder {
                var body = request
                body.confirm = true
                for key in [\AriaCloseoutRequest.category, \.location, \.assigneeId, \.notes] where body[keyPath: key] == "" {
                    body[keyPath: key] = nil
                }
                // Riprovare dopo un errore a metà non crea un secondo ordine: il server rende quello già fatto.
                let written = try await chat.closeout(body)
                result = written
                chat.appendCloseoutSummary(written)
            } else {
                archive = try await chat.archiveReport()
            }
            error = nil
        } catch {
            show(error)
        }
    }

    private func show(_ error: any Error) {
        switch error as? AriaError {
        case .invalidChoice(let field, let valid, let message)?:
            // Categoria o location che MaintainX non ha: niente è stato scritto, si sceglie dalla lista vera.
            validChoices[field] = valid
            if field == "category", let value = request.category, !valid.contains(value) { request.category = nil }
            if field == "location", let value = request.location, !valid.contains(value) { request.location = nil }
            self.error = message
        case .http(404, _)?:
            self.error = String(localized: "There's no procedure to close out in this chat.")
        default:
            self.error = error.localizedDescription
        }
    }
}
