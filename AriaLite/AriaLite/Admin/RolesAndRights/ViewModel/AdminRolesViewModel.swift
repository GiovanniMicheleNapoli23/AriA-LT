//
//  AdminRolesViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  La sezione Roles & Rights, come la pagina /roles della web (guida "Roles & Rights — the admin section in the
//  app", 12/11/2026). Vive in AppViewModel. Tutto dipende da chi guarda (AdminRolesViewer): owner e admin cambiano
//  ogni ruolo, chi ha un ruolo alto solo i ruoli base che il suo ruolo ha creato, entro quello che il suo ruolo ha.
//  Il server resta l'autorità: qui si nasconde o si spegne ciò che rifiuterebbe. Le scritture sono in +Writes.swift.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminRolesViewModel {
    let backend: AriaBackend

    enum Placeholder: Equatable {
        /// GET /v1/me, il catalogo o i ruoli non sono ancora arrivati (un /v1/me fallito resta qui).
        case loading
        /// Chi guarda non passa più le condizioni: la shell chiude la sezione.
        case noAccess
        /// Ruoli o catalogo falliti e niente a schermo: "Riprova" li chiede entrambi.
        case failed
        case empty
    }

    /// Le schermate sopra l'elenco (sul telefono l'elenco apre il dettaglio).
    enum Route: Hashable {
        case role(String)
        /// Le persone di un ruolo (id del ruolo).
        case people(String)
        /// Una sezione di un ruolo, con le sue azioni.
        case section(role: String, section: String)
        /// La scheda di un titolare del ruolo (Members): il percorso è tipizzato, quindi passa da qui.
        case person(String)
        /// La scelta del ruolo predefinito (owner e admin).
        case defaultRole

        /// Il ruolo a cui la schermata si riferisce (`nil` per la scheda di una persona).
        var roleId: String? {
            switch self {
            case .role(let id), .people(let id): id
            case .section(let id, _): id
            case .person, .defaultRole: nil
            }
        }
    }

    /// Le persone di un ruolo, o i candidati di "Aggiungi persone".
    enum People<Value: Equatable>: Equatable {
        case loading
        case failed
        case loaded(Value)
    }

    // MARK: - Stato

    private(set) var catalog: [AdminRoleCatalogSection] = []
    @ObservationIgnored private var catalogLoaded: (companyId: String, at: Date)?
    var roles: [AdminRole] = []
    /// Azienda per cui `roles` è stato letto.
    private(set) var loadedCompanyId: String?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    /// I ruoli con una scrittura in corso, o la rilettura che la segue: i loro comandi sono spenti.
    var busyRoleIds: Set<String> = []
    /// Le persone a cui si sta dando o togliendo un ruolo.
    var busyPeople: Set<String> = []
    var isSettingDefault = false

    var path: [Route] = []
    private(set) var toast: AdminRolesToast?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    /// Chi ha ciascun ruolo, letto aprendo la scheda Persone.
    var holders: [String: People<[AdminRoleHolder]>] = [:]
    /// Le persone a cui chi guarda può dare un ruolo: lette solo con "Aggiungi persone" aperto.
    var candidates: People<[AdminRoleCandidate]>?

    var createForm: AdminRoleCreateViewModel?
    var deleteForm: AdminRoleDeleteViewModel?
    var addPeople: AdminRoleAddPeopleViewModel?
    @ObservationIgnored private var details: [String: AdminRoleDetailViewModel] = [:]

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: niente dati dell'azienda precedente.
    func reset() {
        catalog = []
        catalogLoaded = nil
        roles = []
        loadedCompanyId = nil
        isLoading = false
        loadFailed = false
        busyRoleIds = []
        busyPeople = []
        isSettingDefault = false
        path = []
        toastTask?.cancel()
        toast = nil
        holders = [:]
        candidates = nil
        createForm = nil
        deleteForm = nil
        addPeople = nil
        details = [:]
    }

    // MARK: - Chi guarda

    var viewer: AdminRolesViewer? { AdminRolesViewer(access: backend.access) }

    var isAdmin: Bool { viewer?.isAdmin == true }
    /// Un ruolo alto: "Nuovo ruolo base", nessun livello da scegliere, niente riga Owner né ruolo predefinito.
    var isHighHolder: Bool { viewer?.ownRoleId != nil }

    func isOwn(_ role: AdminRole) -> Bool { role.id == viewer?.ownRoleId }

    /// Chi guarda può cambiare il ruolo: il server lo dice (`editable`), mai il proprio; owner e admin ogni ruolo,
    /// un ruolo alto solo i ruoli base che il suo ruolo ha creato.
    func mayChange(_ role: AdminRole) -> Bool {
        guard role.editable, let viewer, !isOwn(role) else { return false }
        switch viewer {
        case .admin: return true
        case .high(let roleId, _): return role.set == .low && role.ownerRoleId == roleId
        }
    }

    /// Il ruolo predefinito non si elimina: niente "Elimina ruolo".
    func mayDelete(_ role: AdminRole) -> Bool { mayChange(role) && !role.isDefault }

    func isBusy(_ role: AdminRole) -> Bool { busyRoleIds.contains(role.id) }

    func role(id: String) -> AdminRole? { roles.first { $0.id == id } }

    // MARK: - Caricamento

    /// Cambia quando va riletto tutto: l'azienda o chi guarda. Senza chi guarda non si chiede niente.
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(viewer?.key ?? "none")" }

    var hasLoaded: Bool { loadedCompanyId != nil && loadedCompanyId == backend.activeCompanyId }

    /// All'apertura della sezione e quando cambia chi guarda: il catalogo (tenuto 5') e i ruoli.
    func load(forceCatalog: Bool = false) async {
        guard viewer != nil, let api = rolesAPI, let companyId = backend.activeCompanyId else { return }
        if loadedCompanyId != companyId {
            // Un'altra azienda: niente di quella prima.
            path = []
            loadFailed = false
            holders = [:]
            candidates = nil
            details = [:]
        }
        isLoading = true
        defer { isLoading = false }
        let catalogFresh = !forceCatalog && catalogLoaded?.companyId == companyId
            && (catalogLoaded?.at.timeIntervalSinceNow ?? -.infinity) > -Self.catalogLifetime
        do {
            async let freshRoles = api.roles()
            if !catalogFresh {
                let sections = try await api.catalog()
                guard companyId == backend.activeCompanyId else { return }
                catalog = sections
                catalogLoaded = (companyId, .now)
            }
            let fetched = try await freshRoles
            guard companyId == backend.activeCompanyId else { return }
            apply(fetched, companyId: companyId)
            loadFailed = false
        } catch {
            guard companyId == backend.activeCompanyId else { return }
            if AdminRolesFailure.message(for: error, about: .role, backend: backend) != nil { loadFailed = true }
        }
    }

    /// Il catalogo cambia di rado: la web lo tiene 5 minuti.
    nonisolated static let catalogLifetime: TimeInterval = 5 * 60

    /// Rilettura dopo una scrittura (o un rifiuto): se fallisce resta quello che c'è a schermo.
    func reloadRoles() async {
        guard viewer != nil, let api = rolesAPI, let companyId = backend.activeCompanyId else { return }
        guard let fetched = try? await api.roles(), companyId == backend.activeCompanyId else { return }
        apply(fetched, companyId: companyId)
    }

    private func apply(_ fetched: [AdminRole], companyId: String) {
        roles = fetched
        loadedCompanyId = companyId
        let ids = Set(fetched.map(\.id))
        // Il ruolo a schermo non c'è più (eliminato qui o altrove): si torna all'elenco.
        if path.contains(where: { $0.roleId.map { !ids.contains($0) } ?? false }) {
            path = []
        }
        if let form = deleteForm, !ids.contains(form.roleId) { deleteForm = nil }
        if let form = addPeople, !ids.contains(form.roleId) { addPeople = nil }
        holders = holders.filter { ids.contains($0.key) }
        details = details.filter { ids.contains($0.key) }
        deleteForm?.rolesDidChange()
    }

    var placeholder: Placeholder? {
        guard backend.access != nil else { return .loading }
        guard viewer != nil else { return .noAccess }
        guard hasLoaded else { return loadFailed ? .failed : .loading }
        return roles.isEmpty ? .empty : nil
    }

    // MARK: - Elenco

    /// Solo owner e admin scelgono il ruolo predefinito.
    var showsDefaultRole: Bool { isAdmin }

    /// Il ruolo di chi ha un ruolo alto, in cima e solo da guardare.
    var ownRole: AdminRole? { viewer?.ownRoleId.flatMap(role(id:)) }

    var highRoles: [AdminRole] { isAdmin ? roles.filter { $0.set == .high } : [] }

    /// Per un ruolo alto: i ruoli base che il suo ruolo ha creato (il server non manda altro).
    var lowRoles: [AdminRole] { roles.filter { $0.set == .low && !isOwn($0) } }

    func peopleCount(_ role: AdminRole) -> String {
        role.holders == 1 ? String(localized: "1 person") : String(localized: "\(role.holders) people")
    }

    /// La riga sotto il nome: le persone e l'origine, separate da " · ".
    func subtitle(_ role: AdminRole) -> String {
        [peopleCount(role), origin(of: role)].compactMap { $0 }.joined(separator: " · ")
    }

    /// A destra del nome: "Predefinito", "In pausa", o entrambi; `nil` se niente.
    func status(_ role: AdminRole) -> String? {
        let parts = [role.isDefault ? String(localized: "Default") : nil,
                     role.enabled ? nil : String(localized: "Paused")].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Mettere in pausa o riattivare dall'elenco (scorrimento e menu): chi guarda può cambiarlo e non c'è una scrittura in corso.
    func canTogglePause(_ role: AdminRole) -> Bool { mayChange(role) && !isBusy(role) }

    /// "Elimina" dall'elenco (scorrimento e menu): come `mayDelete`, ma non mentre c'è una scrittura in corso.
    func canAskDelete(_ role: AdminRole) -> Bool { mayDelete(role) && !isBusy(role) }

    func pauseTitle(_ role: AdminRole) -> String {
        role.enabled ? String(localized: "Pause") : String(localized: "Resume")
    }

    func pauseSymbol(_ role: AdminRole) -> String { role.enabled ? "pause.fill" : "play.fill" }

    func togglePause(_ role: AdminRole) {
        guard canTogglePause(role) else { return }
        Task { await setEnabled(role, !role.enabled) }
    }

    /// "impostato dal tuo admin" sul proprio ruolo, poi chi l'ha creato, poi "Ruolo iniziale".
    func origin(of role: AdminRole) -> String? {
        if isOwn(role) { return String(localized: "set by your admin") }
        if let name = role.createdByName, !name.isEmpty { return String(localized: "by \(name)") }
        return role.seedKey != nil ? String(localized: "Starting role") : nil
    }

    // MARK: - Ruolo predefinito

    var currentDefault: AdminRole? { roles.first(where: \.isDefault) }

    /// I ruoli base attivi, più quello predefinito anche se in pausa.
    var defaultOptions: [AdminRole] { roles.filter { $0.set == .low && ($0.enabled || $0.isDefault) } }

    func pickerLabel(_ role: AdminRole) -> String {
        role.enabled ? role.name : String(localized: "\(role.name) (paused)")
    }

    /// Il valore a destra di "Ruolo predefinito": il ruolo di ora o "Nessuno".
    var defaultValueText: String { currentDefault.map(pickerLabel) ?? String(localized: "None") }

    /// Toccare il ruolo che è già predefinito non manda niente.
    func chooseDefault(_ role: AdminRole) {
        guard !role.isDefault, !isSettingDefault else { return }
        Task { await setDefault(role.id) }
    }

    var defaultFooter: String {
        currentDefault == nil ? String(localized: "New members join with no role.")
            : String(localized: "People who join the company get this role.")
    }

    // MARK: - Sezioni di un ruolo

    /// Le nove sezioni "solo da guardare": accese senza azioni, si possono solo consultare.
    nonisolated static let lookOnlySections: Set<String> = [
        "teams", "members", "plants", "locations", "categories", "vendors", "meters", "reports", "agent_prompts",
    ]

    func sectionGroups(for role: AdminRole) -> [AdminRoleSectionGroup] {
        let canChange = mayChange(role) && !isBusy(role)
        // "Non incluso nel tuo ruolo" solo per un ruolo alto, e solo su un ruolo che può cambiare.
        let marks = isHighHolder && mayChange(role)
        let sections = catalog.filter { role.set == .high || !$0.highOnly }
        let order = AdminRoleGroup.allCases.map(Optional.some) + [nil]
        return order.compactMap { group in
            let rows = sections.filter { $0.group == group }.map { entry in
                row(for: entry, in: role, canChange: canChange, marks: marks)
            }
            return rows.isEmpty ? nil : AdminRoleSectionGroup(group: group, title: AdminRoleNames.group(group), rows: rows)
        }
    }

    private func row(for entry: AdminRoleCatalogSection, in role: AdminRole, canChange: Bool,
                     marks: Bool) -> AdminRoleSectionRow {
        let on = role.grants[entry.section]
        let held = viewer?.holds(entry.section) ?? false
        let chips: [AdminRoleActionChip] = on == nil ? [] : entry.actions.map { action in
            let isOn = on?.contains(action) == true
            let actionHeld = viewer?.holds(entry.section, action: action) ?? false
            return AdminRoleActionChip(action: action, title: AdminRoleNames.action(action), isOn: isOn,
                                       isEnabled: canChange && (actionHeld || isOn),
                                       notInYourRole: marks && !actionHeld)
        }
        let onActions = entry.actions.filter { on?.contains($0) == true }
        let lookOnly = on != nil && Self.lookOnlySections.contains(entry.section) && !entry.actions.isEmpty
            && !entry.actions.contains { on?.contains($0) == true }
        return AdminRoleSectionRow(section: entry.section, title: AdminRoleNames.section(entry.section), isOn: on != nil,
                                   isEnabled: canChange && (held || on != nil), notInYourRole: marks && !held,
                                   chips: chips, showsLookOnlyHint: lookOnly, hasActions: !entry.actions.isEmpty,
                                   summary: AdminRoleNames.summary(isOn: on != nil, onActions: onActions,
                                                                   total: entry.actions.count))
    }

    // MARK: - Dettaglio

    /// Uno per ruolo e tenuto: scheda scelta e rinomina restano mentre l'elenco si rilegge.
    func detail(for roleId: String) -> AdminRoleDetailViewModel {
        if let cached = details[roleId] { return cached }
        let detail = AdminRoleDetailViewModel(roleId: roleId, owner: self)
        details[roleId] = detail
        return detail
    }

    // MARK: - Avvisi

    func show(_ text: String, isError: Bool = false) {
        toastTask?.cancel()
        let toast = AdminRolesToast(text: text, isError: isError)
        self.toast = toast
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(isError ? 4 : 2.5))
            guard !Task.isCancelled, self?.toast?.id == toast.id else { return }
            self?.toast = nil
        }
    }
}

/// Un avviso in alto: una conferma ("Night shift creato") o un rifiuto del server.
struct AdminRolesToast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isError: Bool
}
