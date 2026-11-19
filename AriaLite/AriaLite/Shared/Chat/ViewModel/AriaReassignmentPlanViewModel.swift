//
//  AriaReassignmentPlanViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La logica del piano di riassegnazione in chat: quali mosse sono applicate, rifiutate o in corso, "Applica
//  tutto" e gli errori. Vive nella cache di AriaAgentChat (per messaggio e artifact): la lista pigra della
//  chat ricrea le viste, lo stato resta.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaReassignmentPlanViewModel {
    let plan: AriaReassignmentPlan

    // MARK: - State

    private(set) var applied: Set<String> = []
    private(set) var dismissed: Set<String> = []
    private(set) var busy: Set<String> = []
    private(set) var isApplyingAll = false
    /// L'ultimo esito: un errore (rosso) o, dopo "Applica tutto", quante mosse sono andate a buon fine.
    private(set) var lastError: String?
    private(set) var summary: String?

    @ObservationIgnored private let backend: AriaBackend

    init(plan: AriaReassignmentPlan, backend: AriaBackend) {
        self.plan = plan
        self.backend = backend
    }

    // MARK: - Derived

    var visibleMoves: [AriaReassignmentPlan.Move] { plan.moves.filter { !dismissed.contains($0.woId) } }
    private var pendingMoves: [AriaReassignmentPlan.Move] { visibleMoves.filter { !applied.contains($0.woId) } }
    var pendingCount: Int { pendingMoves.count }

    /// Una richiesta è in corso: gli altri pulsanti aspettano.
    var isWorking: Bool { isApplyingAll || !busy.isEmpty }
    var isBalanced: Bool { plan.moves.isEmpty }
    var allDismissed: Bool { !plan.moves.isEmpty && visibleMoves.isEmpty }

    /// "Applica tutto": più di una mossa da fare e il diritto di riassegnare in blocco.
    var showsApplyAll: Bool { pendingCount > 1 && backend.rights.can(.bulkReassign, in: .workOrders) }
    /// "Accetta" è una modifica dell'ordine: serve il diritto sugli ordini di lavoro.
    var canAccept: Bool { backend.rights.has(.workOrders) }

    func isApplied(_ move: AriaReassignmentPlan.Move) -> Bool { applied.contains(move.woId) }
    func isBusy(_ move: AriaReassignmentPlan.Move) -> Bool { busy.contains(move.woId) }

    // MARK: - Actions

    func reject(_ move: AriaReassignmentPlan.Move) {
        guard !isWorking else { return }
        dismissed.insert(move.woId)
    }

    func accept(_ move: AriaReassignmentPlan.Move) {
        guard !isWorking, !applied.contains(move.woId) else { return }
        lastError = nil
        summary = nil
        busy.insert(move.woId)
        Task { [weak self] in
            guard let self else { return }
            if !(await apply(move)) {
                lastError = String(localized: "Couldn't reassign \(move.title). Try again.")
            }
            busy.remove(move.woId)
        }
    }

    /// Una mossa dopo l'altra; se una cade si va avanti, e alla fine si dice quante sono andate.
    func applyAll() {
        guard !isWorking, showsApplyAll else { return }
        let moves = pendingMoves
        lastError = nil
        summary = nil
        isApplyingAll = true
        Task { [weak self] in
            guard let self else { return }
            var done = 0
            for move in moves {
                busy.insert(move.woId)
                if await apply(move) { done += 1 }
                busy.remove(move.woId)
            }
            isApplyingAll = false
            let failed = moves.count - done
            summary = failed == 0
                ? String(localized: "Applied: \(done)")
                : String(localized: "Applied: \(done), failed: \(failed)")
        }
    }

    /// PATCH dell'ordine con la squadra proposta; `true` se è andata.
    private func apply(_ move: AriaReassignmentPlan.Move) async -> Bool {
        do {
            try await AdminWorkOrdersAPI(api: backend.api, rights: backend.rights).reassign(move.woId, toTeam: move.toTeamId)
            applied.insert(move.woId)
            return true
        } catch {
            backend.handle(error)
            return false
        }
    }
}
