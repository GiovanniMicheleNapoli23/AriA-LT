//
//  AdminMemberDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un membro (GET /v1/members/{id} e /shifts): scheda aggiornata dal server e turni dei
//  prossimi giorni. "Assign shift" apre il modulo; togliere un turno chiede prima conferma.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemberDetailViewModel {
    let owner: AdminMembersViewModel
    private var backend: AriaBackend { owner.backend }

    /// Quanti giorni avanti si guardano i turni.
    static let horizonDays = 60

    // MARK: - State

    private(set) var member: AdminMember
    private(set) var shifts: [AdminMemberShift] = []
    private(set) var hasLoadedShifts = false
    private(set) var isLoading = false
    private(set) var failure: AdminMembersFailure?
    private(set) var shiftsFailure: AdminMembersFailure?
    private(set) var isRemoving = false

    /// Il modulo di assegnazione aperto (sheet).
    var assignForm: AdminMemberAssignShiftViewModel?
    /// "Togliere questo turno?" (conferma): il turno in questione.
    var shiftToRemove: AdminMemberShift?
    var isConfirmingRemoval: Bool {
        get { shiftToRemove != nil }
        set { if !newValue { shiftToRemove = nil } }
    }
    /// Errore di una modifica (alert).
    var actionError: String?
    var isShowingActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    init(member: AdminMember, owner: AdminMembersViewModel) {
        self.member = member
        self.owner = owner
    }

    // MARK: - Caricamento

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let fresh: Void = reloadMember()
        async let upcoming: Void = reloadShifts()
        _ = await (fresh, upcoming)
    }

    private func reloadMember() async {
        do {
            let fresh = try await AdminMembersAPI(api: backend.api).member(id: member.id)
            member = fresh
            owner.didRefresh(fresh)
            failure = nil
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    func reloadShifts() async {
        let window = AdminMemberDay.window(days: Self.horizonDays)
        do {
            let fresh = try await AdminMembersAPI(api: backend.api)
                .shifts(userId: member.id, from: window.from, to: window.to)
            shifts = fresh.sorted { ($0.shiftDate, $0.shiftType) < ($1.shiftDate, $1.shiftType) }
            hasLoadedShifts = true
            shiftsFailure = nil
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .read, backend: backend) {
                shiftsFailure = failure
            }
        }
    }

    // MARK: - Presentazione

    var workload: AdminMemberWorkload { member.workload }

    /// "Next 60 days": il titolo dell'elenco dei turni.
    var horizonText: String { String(localized: "Next \(Self.horizonDays) days") }

    // MARK: - Azioni

    func startAssigning() {
        assignForm = AdminMemberAssignShiftViewModel(member: member, owner: self)
    }

    /// Un turno assegnato: si rileggono turni e scheda (il team di oggi può essere cambiato).
    func didAssign() async {
        await load()
        await owner.refresh()
    }

    func confirmRemoval(of shift: AdminMemberShift) {
        shiftToRemove = shift
    }

    /// Il testo della conferma, con giorno e team del turno.
    func removalMessage(for shift: AdminMemberShift) -> String {
        String(localized: "\(member.displayName) will no longer be on \(shift.teamTitle) on \(shift.dateText).")
    }

    /// Toglie il turno, dopo la conferma. Un 404 vuol dire che non c'era già più.
    func remove(_ shift: AdminMemberShift) async {
        guard !isRemoving else { return }
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await AdminMembersAPI(api: backend.api).removeAssignment(id: shift.id)
        } catch {
            guard let failure = AdminMembersFailure.from(error, action: .write, backend: backend) else { return }
            guard failure.isNotFound else {
                actionError = failure.message
                return
            }
        }
        shifts.removeAll { $0.id == shift.id }
        await reloadMember()
        await owner.refresh()
    }
}
