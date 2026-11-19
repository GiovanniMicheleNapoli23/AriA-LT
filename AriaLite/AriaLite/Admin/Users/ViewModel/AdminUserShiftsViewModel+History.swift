//
//  AdminUserShiftsViewModel+History.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La cronologia (§4.3): GET /v1/members/{id}/shifts senza date, raggruppata per giorno, e la rimozione di un turno
//  di oggi o futuro (DELETE /v1/member-assignments/{id}, con `assign_shifts`).
//

import Foundation

extension AdminUserShiftsViewModel {
    /// Il giorno UTC di oggi, come testo `YYYY-MM-DD`.
    var todayKey: String { AdminMemberDay.utcToday() }

    func isToday(_ day: AdminUserShiftDay) -> Bool { day.isToday(todayKey) }

    /// Si può togliere un turno di oggi o futuro, e solo con `assign_shifts`.
    func canRemove(_ shift: AdminMemberShift) -> Bool {
        canAssignShifts && shift.shiftDate >= todayKey
    }

    func loadHistory() async {
        // Il cerchio gira solo la prima volta: dopo, la lista resta e si aggiorna da sola.
        if case .loaded = history {} else { history = .loading }
        do {
            let shifts = try await membersAPI.shifts(userId: userId)
            history = .loaded(AdminUserShiftDay.group(shifts))
        } catch {
            guard let failure = AdminUsersFailure.from(error, backend: owner.backend) else { return }
            if case .loaded = history {
                owner.show(failure.message, isError: true)
            } else {
                history = .failed(failure.message)
            }
            await owner.absorb(failure)
        }
    }

    // MARK: - Rimozione

    var isConfirmingRemoval: Bool {
        get { shiftToRemove != nil }
        set { if !newValue { shiftToRemove = nil } }
    }

    func requestRemoval(_ shift: AdminMemberShift) {
        guard canRemove(shift) else { return }
        shiftToRemove = shift
    }

    /// "Team A · Wed, 18 Nov": cosa si sta togliendo, per la conferma.
    func removalMessage(for shift: AdminMemberShift) -> String {
        "\(shift.teamTitle) · \(shift.dateText)"
    }

    func remove(_ shift: AdminMemberShift) async {
        shiftToRemove = nil
        guard canRemove(shift), !isRemoving else { return }
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await membersAPI.removeAssignment(id: shift.id)
        } catch {
            await report(error, as: String(localized: "Removal failed"))
            return
        }
        owner.show(String(localized: "Assignment removed"))
        await loadHistory()
        await reloadDetails()
    }
}
