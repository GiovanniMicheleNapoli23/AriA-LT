//
//  AdminRoleDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il dettaglio di un ruolo e le sue pagine figlie (una sezione, le persone): stato attivo, dati del ruolo, righe
//  delle sezioni, rinomina. Le regole stanno in AdminRolesViewModel; qui lo stato della schermata (nome in modifica)
//  e i testi già pronti.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminRoleDetailViewModel {
    let roleId: String
    let owner: AdminRolesViewModel

    /// Il foglio della rinomina è aperto. Scrivibile perché `.sheet(isPresented:)` lo lega; alla chiusura la vista chiama
    /// `cancelRenaming()` per togliere l'errore.
    var isRenaming = false
    var nameDraft = "" {
        didSet {
            if nameDraft.count > AdminRoleCreateViewModel.nameLimit {
                nameDraft = String(nameDraft.prefix(AdminRoleCreateViewModel.nameLimit))
            }
            if nameDraft != oldValue { nameError = nil }
        }
    }
    private(set) var nameError: String?
    private(set) var isSavingName = false

    init(roleId: String, owner: AdminRolesViewModel) {
        self.roleId = roleId
        self.owner = owner
    }

    var role: AdminRole? { owner.role(id: roleId) }

    // MARK: - Intestazione

    var mayChange: Bool { role.map(owner.mayChange) ?? false }
    var mayDelete: Bool { role.map(owner.mayDelete) ?? false }
    var isBusy: Bool { role.map(owner.isBusy) ?? true }
    var isOwn: Bool { role.map(owner.isOwn) ?? false }

    // MARK: - Dati del ruolo

    /// Acceso o in pausa (interruttore "Attivo").
    var isActive: Bool { role?.enabled ?? false }

    func setActive(_ active: Bool) {
        guard let role, mayChange, !isBusy else { return }
        Task { await owner.setEnabled(role, active) }
    }

    var statusText: String {
        isActive ? String(localized: "roles.status.active", defaultValue: "Active") : String(localized: "Paused")
    }

    var toggleTitle: String { String(localized: "roles.status.active", defaultValue: "Active") }

    var peopleCountText: String { (role?.holders ?? 0).formatted() }

    var levelText: String { role?.set == .high ? String(localized: "High role") : String(localized: "Low role") }

    /// Chi l'ha creato: "Il tuo admin" sul proprio ruolo, poi il nome; `nil` per i ruoli iniziali.
    var createdByText: String? {
        guard let role else { return nil }
        if isOwn { return String(localized: "Your admin") }
        return role.createdByName.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Sotto le prime righe: cosa succede in pausa (se c'è l'interruttore) e le note sul ruolo.
    var footerText: String? {
        guard let role else { return nil }
        var lines: [String] = []
        if mayChange {
            lines.append(String(localized: "When paused, people with this role keep only the chat and the screens everyone has."))
        }
        if role.isDefault {
            lines.append(String(localized: "This is the default role for new members. Choose another default before deleting it."))
        }
        if isOwn { lines.append(String(localized: "Set by your admin. You can't change your own role.")) }
        if role.exceedsOwner { lines.append(String(localized: "Holds sections its owner role lacks.")) }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    // MARK: - Rinomina

    func startRenaming() {
        guard let role, mayChange else { return }
        nameDraft = role.name
        nameError = nil
        isRenaming = true
    }

    func cancelRenaming() {
        isRenaming = false
        nameError = nil
    }

    var canSaveName: Bool {
        !isSavingName && !isBusy && !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Lo stesso nome chiude il campo e basta.
    func saveName() async {
        guard let role, canSaveName else { return }
        let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name != role.name else {
            isRenaming = false
            return
        }
        isSavingName = true
        defer { isSavingName = false }
        switch await owner.rename(role, to: name) {
        case .done: isRenaming = false
        case .nameTaken: nameError = AriaAccessRefusal.roleNameTaken.localized
        case .failed, .hasMembers: break
        }
    }

    func askDelete() {
        guard let role else { return }
        owner.askDelete(role)
    }

    // MARK: - Sezioni

    var sectionGroups: [AdminRoleSectionGroup] { role.map(owner.sectionGroups(for:)) ?? [] }

    /// La riga di una sezione riletta ogni volta: `nil` se il ruolo o la sezione non ci sono più.
    func sectionRow(_ section: String) -> AdminRoleSectionRow? {
        sectionGroups.lazy.flatMap(\.rows).first { $0.section == section }
    }

    /// Sotto l'interruttore "Accesso" della pagina di una sezione.
    func accessFooter(for row: AdminRoleSectionRow) -> String {
        if !row.isOn { return String(localized: "Turn on access to choose what they may do.") }
        if row.showsLookOnlyHint { return String(localized: "View only. Turn on below what they may change.") }
        return String(localized: "People with this role can open \(row.title).")
    }

    /// La pagina di una sezione mostra le azioni solo a sezione accesa e con azioni nel catalogo.
    func showsActions(_ row: AdminRoleSectionRow) -> Bool { row.isOn && !row.chips.isEmpty }

    func setSection(_ section: String, on: Bool) {
        guard let role else { return }
        Task { await owner.setSection(section, on: on, in: role) }
    }

    func toggleAction(_ action: String, in section: String) {
        guard let role else { return }
        Task { await owner.toggleAction(action, in: section, of: role) }
    }

    // MARK: - Persone

    enum People: Equatable {
        case loading
        case failed
        case empty
        case loaded([AdminRoleHolder])
    }

    var people: People {
        switch owner.holders[roleId] {
        case nil, .loading?: .loading
        case .failed?: .failed
        case .loaded(let list)?: list.isEmpty ? .empty : .loaded(list)
        }
    }

    func loadPeople() async { await owner.loadHolders(of: roleId) }

    func name(_ holder: AdminRoleHolder) -> String {
        holder.name.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Unnamed person")
    }

    /// Aprire la scheda della persona: un admin sempre; chi ha un ruolo solo se il ruolo concede Members.
    var canOpenPerson: Bool { owner.isAdmin || owner.backend.rights.has(.members) }

    func personRoute(_ holder: AdminRoleHolder) -> AdminRolesViewModel.Route { .person(holder.userId) }

    func isBusy(_ holder: AdminRoleHolder) -> Bool { owner.busyPeople.contains(holder.userId) }

    func remove(_ holder: AdminRoleHolder) {
        guard let role else { return }
        Task { await owner.assign(userId: holder.userId, name: holder.name, to: nil, from: role) }
    }

    func addPeople() {
        guard let role else { return }
        owner.startAddingPeople(to: role)
    }
}
