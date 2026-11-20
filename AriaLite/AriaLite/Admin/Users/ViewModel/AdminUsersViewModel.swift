//
//  AdminUsersViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La sezione Users (contratto del 18/11/2026): l'elenco di tutti, i posti, i titolari, i ruoli per i selettori e,
//  per i titolari, il tetto del piano. Vive in AppViewModel. L'elenco non si rilegge a tempo: si legge entrando nella
//  sezione (se i dati hanno più di 45 secondi), tornando in primo piano, dopo ogni scrittura (§3.1, regola 5) e
//  tirando per aggiornare. "Online" si ricalcola sull'orologio nelle sole etichette (TimelineView), senza stato.
//  Ricerca e filtri sono sul telefono. Le decisioni stanno in AdminUsersRules.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminUsersViewModel {
    let backend: AriaBackend

    enum Placeholder: Equatable {
        case loading
        /// "Couldn't load the people of this workspace."
        case failed
        /// "No one here yet"
        case empty
        /// "No one matches these filters."
        case noMatches
    }

    // MARK: - Stato

    private(set) var page: AdminUsersPage?
    /// L'azienda per cui `page` è stata letta.
    private(set) var loadedCompanyId: String?
    private(set) var isLoading = false
    /// L'ultima lettura dell'elenco è fallita.
    private(set) var loadFailed = false
    /// L'elenco ha risposto 403: la sezione si chiude.
    private(set) var isClosed = false

    /// Il tetto del piano (solo titolari); `nil` finché non arriva o se la lettura è fallita.
    private(set) var seatsInfo: AdminUserSeatsInfo?
    /// "Couldn't load your user limits." (Add user resta acceso).
    private(set) var seatsFailed = false
    /// Il server non ha il pannello (403/404): niente pannello, Add user acceso.
    private(set) var seatsUnavailable = false

    /// I ruoli per i selettori (titolari e ruoli alti).
    private(set) var roles: [AdminRole] = []
    private(set) var hasLoadedRoles = false

    /// L'ora con cui si calcola "online" (filtro e schede): quella di adesso, non uno stato che invalida le righe.
    var now: Date { .now }

    /// Quando l'elenco è stato letto l'ultima volta: entrando di nuovo si rilegge solo se è vecchio.
    @ObservationIgnored private var freshness = AriaFreshness()

    /// Le schede aperte sopra l'elenco.
    var path: [AdminUserRoute] = []
    var query = ""
    var filters = AdminUserFilters()

    /// Il messaggio breve dopo un'azione ("{name} was removed."), come i toast della web: lo mette `show`.
    private(set) var notice: AdminUsersNotice?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?

    /// I fogli aperti dall'elenco (Add user) e la revoca da confermare: li gestisce +Actions.
    var addForm: AdminUserAddViewModel?
    var invitationToRevoke: AdminUserRow?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account o al cambio di azienda: non resta niente.
    func reset() {
        page = nil
        loadedCompanyId = nil
        freshness.invalidate()
        isLoading = false
        loadFailed = false
        isClosed = false
        seatsInfo = nil
        seatsFailed = false
        seatsUnavailable = false
        roles = []
        hasLoadedRoles = false
        path = []
        query = ""
        filters = AdminUserFilters()
        noticeTask?.cancel()
        notice = nil
        addForm = nil
        invitationToRevoke = nil
    }

    // MARK: - Chi guarda

    var viewer: AdminUsersViewer { AdminUsersViewer(backend: backend) }

    var entry: AdminUsersRules.Entry { AdminUsersRules.entry(backend.access) }

    var companyId: String? { backend.activeCompanyId }

    var api: AdminUsersAPI? {
        companyId.map { AdminUsersAPI(api: backend.api, companyId: $0) }
    }

    // MARK: - Caricamento

    /// Cambia quando va riletto tutto: l'azienda, e se chi guarda può aprire la sezione (cambiando azienda `access`
    /// torna `nil` e poi arriva: la lettura parte allora).
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(entry)" }

    var hasLoaded: Bool { page != nil && loadedCompanyId == backend.activeCompanyId }

    var people: [AdminUserRow] { hasLoaded ? page?.people ?? [] : [] }

    /// Entrando nella sezione: la prima volta, dopo un errore o una chiusura, o se i dati sono vecchi.
    func loadIfNeeded() async {
        if loadedCompanyId != backend.activeCompanyId { reset() }
        if needsRefresh { await refresh() }
    }

    /// Tornando in primo piano: rilegge solo se i dati hanno più di 45 secondi.
    func refreshIfStale() async {
        if needsRefresh { await refresh() }
    }

    private var needsRefresh: Bool {
        !hasLoaded || isClosed || entry == .hidden || freshness.isStale()
    }

    /// Rilegge l'elenco e, per un titolare, il tetto; i ruoli la prima volta che servono.
    func refresh() async {
        // Senza la sezione (§2) si chiude; finché /v1/me non risponde si aspetta.
        if entry == .hidden {
            isClosed = true
            path = []
            return
        }
        guard let api, entry == .open else { return }
        let company = companyId
        let viewer = viewer
        isLoading = true
        defer { isLoading = false }
        async let seats: Void = viewer.isOwner ? refreshSeats() : ()
        async let roleList: Void = hasLoadedRoles ? () : loadRoles()
        do {
            let fresh = try await api.list()
            guard company == backend.activeCompanyId else { return }
            page = fresh
            loadedCompanyId = company
            freshness.markLoaded()
            loadFailed = false
            isClosed = false
            dropStaleFilters()
            // La persona aperta non c'è più: si torna all'elenco.
            path.removeAll { route in !fresh.people.contains { $0.userId == route.userId } }
        } catch {
            if let failure = AdminUsersFailure.from(error, backend: backend) {
                // 403 (anche `permission_denied`), sessione chiusa, o un server senza la rotta (404, §9): si chiude.
                // Un errore di rete o un 5xx non chiude: `loadFailed` e l'elenco già letto restano com'erano.
                if failure.closesSection || failure.sessionEnded || failure.personGone || failure.reloadsRights {
                    isClosed = true
                    path = []
                }
                loadFailed = true
                await absorb(failure)
            }
        }
        _ = await (seats, roleList)
    }

    func refreshSeats() async {
        guard let api, viewer.isOwner else { return }
        do {
            seatsInfo = try await api.seats()
            seatsFailed = false
            seatsUnavailable = false
        } catch {
            switch error as? AriaError {
            case .http(403, _)?, .http(404, _)?, .notOnPhone?, .permissionDenied?:
                seatsUnavailable = true
                seatsInfo = nil
            default:
                if AdminUsersFailure.from(error) != nil { seatsFailed = true }
            }
        }
    }

    /// I ruoli servono a titolari e ruoli alti (selettori); un'azienda senza ruoli non ne ha.
    var needsRoles: Bool {
        let viewer = viewer
        return !viewer.legacy && viewer.kind != .otherHolder
    }

    func loadRoles() async {
        guard needsRoles, let companyId else { return }
        do {
            roles = try await AdminRolesAPI(api: backend.api, companyId: companyId).roles()
            hasLoadedRoles = true
        } catch {
            // Senza ruoli i selettori mostrano solo Owner e No role: il server resta l'autorità.
            _ = AdminUsersFailure.from(error, backend: backend)
        }
    }

    /// Dopo una scrittura: l'elenco (posti, titolari, righe); se toccava chi guarda, anche /v1/me (regola 5).
    func afterWrite(touchedSelf: Bool = false, rolesChanged: Bool = false) async {
        if rolesChanged { await loadRoles() }
        await refresh()
        if touchedSelf { await backend.refreshMembership() }
    }

    /// Cosa fare di un rifiuto oltre a dirlo: rileggere diritti, ruoli o tetto, o lasciare l'azienda.
    func absorb(_ failure: AdminUsersFailure) async {
        if failure.sessionEnded {
            await backend.leaveEndedWorkspace()
            return
        }
        if failure.reloadsRights { await backend.refreshMembership() }
        if failure.roleMissing { await loadRoles() }
        if failure.userLimitReached { await refreshSeats() }
    }

    // MARK: - Avvisi

    /// Mostra un avviso in alto per qualche secondo (il più recente sostituisce il precedente).
    func show(_ text: String, isError: Bool = false) {
        noticeTask?.cancel()
        let notice = AdminUsersNotice(text: text, isError: isError)
        self.notice = notice
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, self?.notice?.id == notice.id else { return }
            self?.notice = nil
        }
    }

    // MARK: - Righe

    func row(for userId: String) -> AdminUserRow? { people.first { $0.userId == userId } }

    var visibleRows: [AdminUserRow] {
        filters.apply(to: people, query: query, now: now)
    }

    func presence(of row: AdminUserRow) -> AdminUserPresence { AdminUserPresence(row.lastSeen, now: now) }

    /// I ruoli che compaiono fra le persone, per il filtro Ruolo (nascosto se nessuno ne ha uno).
    var roleFilterOptions: [AdminUserRole] {
        var seen = Set<String>()
        return people.compactMap(\.role).filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func dropStaleFilters() {
        if let roleId = filters.roleId, !roleFilterOptions.contains(where: { $0.id == roleId }) { filters.roleId = nil }
        if !viewer.isOwner { filters.online = nil }
    }

    var placeholder: Placeholder? {
        if !hasLoaded { return loadFailed ? .failed : .loading }
        if people.isEmpty { return .empty }
        return visibleRows.isEmpty ? .noMatches : nil
    }

    // MARK: - In alto (§3.4)

    /// "{used} of {total} seats used" per chi non è titolare.
    var seatsReadout: String? {
        guard !viewer.isOwner, let seats = page?.seats, hasLoaded else { return nil }
        return AdminUsersRules.seatsReadout(seats)
    }

    var capState: AdminUsersRules.CapState { AdminUsersRules.capState(seatsInfo) }

    var canAdd: Bool { viewer.isOwner && hasLoaded && capState == .open }
}

/// Un messaggio breve dopo un'azione; `isError` per un rifiuto.
nonisolated struct AdminUsersNotice: Equatable, Identifiable, Sendable {
    let id = UUID()
    let text: String
    var isError = false
}
