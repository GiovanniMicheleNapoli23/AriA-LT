//
//  AdminMemberAdHocTeamViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "New ad-hoc team" (POST /v1/teams/ad-hoc): un team temporaneo con i membri scelti, fissati ai
//  giorni di turno indicati. Si scelgono fra i membri attivi dell'elenco; la risposta non si legge.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemberAdHocTeamViewModel: Identifiable {
    let owner: AdminMembersViewModel

    // MARK: - Campi

    var name = ""
    var notes = ""
    var shiftType: AdminMemberShiftType = .full
    /// I giorni di turno scelti (calendario a selezione multipla).
    var days: Set<DateComponents> = []
    var memberQuery = ""
    private(set) var selectedIds: Set<String> = []

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(owner: AdminMembersViewModel) {
        self.owner = owner
    }

    // MARK: - Membri

    /// Solo i membri attivi hanno senso in un team; ricerca per nome o email.
    var candidates: [AdminMember] {
        let q = memberQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return owner.members
            .filter { $0.isActive }
            .filter { q.isEmpty || [$0.fullName, $0.email].contains { $0?.localizedStandardContains(q) == true } }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    func isSelected(_ member: AdminMember) -> Bool { selectedIds.contains(member.id) }

    func toggle(_ member: AdminMember) {
        if !selectedIds.insert(member.id).inserted { selectedIds.remove(member.id) }
    }

    var selectedCountText: String { String(localized: "\(selectedIds.count) selected") }

    // MARK: - Giorni

    /// Il primo giorno selezionabile: oggi.
    var dayRange: PartialRangeFrom<Date> { Calendar.current.startOfDay(for: .now)... }

    var daysSummary: String? {
        guard !days.isEmpty else { return nil }
        let dates = days.compactMap { Calendar.current.date(from: $0) }.sorted()
        return dates.map { $0.formatted(.dateTime.day().month(.abbreviated)) }.joined(separator: ", ")
    }

    // MARK: - Salvataggio

    var canSave: Bool { !isSaving && !trimmed(name).isEmpty && !selectedIds.isEmpty }

    var hasChanges: Bool { !trimmed(name).isEmpty || !selectedIds.isEmpty || !days.isEmpty }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// `true` se creato: il modulo si può chiudere.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        guard !trimmed(name).isEmpty else {
            errorMessage = String(localized: "Name is required.")
            return false
        }
        guard !selectedIds.isEmpty else {
            errorMessage = String(localized: "Pick at least one member.")
            return false
        }
        let shiftDays = days.compactMap { Calendar.current.date(from: $0) }.map(AdminMemberDay.string(from:)).sorted()
        let note = trimmed(notes)
        let body = AdminMemberAdHocTeamCreate(
            name: trimmed(name), description: note.isEmpty ? nil : note, plantId: owner.backend.activePlantId,
            userIds: selectedIds.sorted(), shiftDates: shiftDays, shiftType: shiftType.rawValue
        )
        isSaving = true
        defer { isSaving = false }
        do {
            try await AdminMembersAPI(api: owner.backend.api).createAdHocTeam(body)
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .write, backend: owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
        await owner.didCreateAdHocTeam()
        return true
    }
}
