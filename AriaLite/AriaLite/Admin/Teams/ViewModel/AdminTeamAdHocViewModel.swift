//
//  AdminTeamAdHocViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "New ad-hoc team" (POST /v1/teams/ad-hoc): un team temporaneo con i membri scelti, fissati ai
//  giorni di turno indicati. Si scelgono fra le persone attive dell'azienda (`owner.people`); la risposta non si legge.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminTeamAdHocViewModel: Identifiable {
    let owner: AdminTeamsViewModel

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

    init(owner: AdminTeamsViewModel) {
        self.owner = owner
    }

    // MARK: - Membri

    /// Le persone si caricano una volta sola dal proprietario; `owner.loadPeople()` dice se l'elenco è arrivato, così
    /// un'azienda senza persone non passa per un errore.
    private(set) var isLoadingPeople = false
    private(set) var peopleFailed = false

    func loadPeople() async {
        guard !isLoadingPeople else { return }
        isLoadingPeople = true
        defer { isLoadingPeople = false }
        peopleFailed = !(await owner.loadPeople())
    }

    /// Solo le persone attive hanno senso in un team; ricerca per nome o email.
    var candidates: [AdminTeamPerson] {
        let q = memberQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return owner.people
            .filter { $0.isActive }
            .filter { q.isEmpty || $0.displayName.localizedStandardContains(q) || $0.email.localizedStandardContains(q) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    func isSelected(_ person: AdminTeamPerson) -> Bool { selectedIds.contains(person.id) }

    func toggle(_ person: AdminTeamPerson) {
        if !selectedIds.insert(person.id).inserted { selectedIds.remove(person.id) }
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
            try await owner.api.createAdHoc(body)
        } catch {
            if let failure = AdminTeamsFailure.from(error, action: .write, backend: owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
        await owner.refresh()
        return true
    }
}
