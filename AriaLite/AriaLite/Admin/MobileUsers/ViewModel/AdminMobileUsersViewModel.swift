//
//  AdminMobileUsersViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Mobile Users, come la pagina /mobile-users della web: posti della licenza, elenco degli operatori
//  con filtro per stato e ricerca. Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  L'elenco arriva intero dal server (niente pagine): stato e ricerca filtrano qui. Azioni in +Actions.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMobileUsersViewModel {
    let backend: AriaBackend

    private(set) var operators: [AdminMobileUser] = []
    private(set) var seats: AdminMobileUserSeats?
    private(set) var isLoading = false
    /// L'elenco è arrivato almeno una volta per questa azienda.
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?

    // MARK: Filtri

    var searchText = ""
    /// `nil`: tutti gli stati.
    var statusFilter: AdminMobileUserStatus?

    // MARK: Azioni (vedi +Actions)

    /// Operatori con una richiesta in corso.
    var busyUserIds: Set<String> = []
    var actionError: String?
    var actionNotice: String?
    var pendingConfirmation: AdminMobileUserConfirmation?

    // MARK: Fogli (nuovo operatore)

    /// Il foglio "Invite new operator", aperto quando c'è.
    var inviteForm: AdminMobileUserInviteViewModel?
    /// Il foglio "Add existing user", aperto quando c'è.
    var picker: AdminMobileUserPickerViewModel?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesto l'elenco: l'azienda (la vista ci appende un `.task`).
    var loadKey: String { backend.activeCompanyId ?? "-" }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var visibleOperators: [AdminMobileUser] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return operators
            .filter { statusFilter == nil || $0.knownStatus == statusFilter }
            .filter {
                query.isEmpty || ([$0.name, $0.email] + $0.specialties).contains { $0.localizedStandardContains(query) }
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var statusFilterLabel: String { statusFilter?.label ?? String(localized: "All") }

    /// Gli stati che hanno almeno un operatore, per il menu del filtro (con il numero accanto).
    var presentStatuses: [AdminMobileUserStatus] {
        AdminMobileUserStatus.allCases.filter { status in operators.contains { $0.knownStatus == status } }
    }

    func count(for status: AdminMobileUserStatus) -> Int { operators.filter { $0.knownStatus == status }.count }

    var subtitle: String {
        let count = visibleOperators.count
        guard operators.count > count else { return String(localized: "\(count) operators") }
        return String(localized: "\(count) of \(operators.count) operators")
    }

    /// Posti usati e totali, "3 of 10 seats used".
    var seatsText: String? {
        seats.map { String(localized: "\($0.used) of \($0.total) seats used") }
    }

    /// Chi è già operatore (anche invitato o sospeso): non si può promuovere due volte.
    var existingEmails: Set<String> { Set(operators.map { $0.email.lowercased() }) }
    var existingIds: Set<String> { Set(operators.map(\.id)) }

    /// "3 open · 2 h 30 min": gli ordini aperti dell'operatore e il tempo che ci vuole; vuoto se non ne ha.
    func workLoadText(of user: AdminMobileUser) -> String {
        guard user.openCount > 0 else { return String(localized: "No open work orders") }
        let open = String(localized: "\(user.openCount) open")
        guard user.openMinutes > 0 else { return open }
        let time = Duration.seconds(user.openMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return "\(open) · \(time)"
    }

    func user(id: String) -> AdminMobileUser? { operators.first { $0.id == id } }
    func isBusy(_ user: AdminMobileUser) -> Bool { busyUserIds.contains(user.id) }

    // MARK: Caricamento

    func load() async {
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        // Altra azienda: l'elenco vecchio non vale, non si mostra mentre arriva il nuovo.
        let key = loadKey
        if key != loadedKey {
            operators = []
            seats = nil
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminMobileUsersAPI.list(companyId: companyId))
            guard key == loadKey, !Task.isCancelled else { return }
            operators = response.operators
            seats = response.seats
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
        } catch {
            if key == loadKey, let message = AdminMobileUserFailure.message(for: error, backend: backend) {
                errorMessage = message
            }
        }
    }

    func makeDetailViewModel(userId: String) -> AdminMobileUserDetailViewModel {
        AdminMobileUserDetailViewModel(list: self, userId: userId)
    }

    func startInviting() { inviteForm = AdminMobileUserInviteViewModel(backend: backend) }
    func startPicking() { picker = AdminMobileUserPickerViewModel(list: self) }

    /// Un operatore nuovo o cambiato (dalla risposta del server): sostituisce la riga o la aggiunge.
    func apply(_ user: AdminMobileUser) {
        if let index = operators.firstIndex(where: { $0.id == user.id }) {
            operators[index] = user
        } else {
            operators.append(user)
        }
    }

    func removeLocally(id: String) {
        operators.removeAll { $0.id == id }
    }

    /// Dopo un "Add" o un "Invite": la riga nuova subito, poi i posti dal server.
    func didAdd(_ user: AdminMobileUser) async {
        apply(user)
        await load()
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        operators = []
        seats = nil
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        searchText = ""
        statusFilter = nil
        busyUserIds = []
        actionError = nil
        actionNotice = nil
        pendingConfirmation = nil
        inviteForm = nil
        picker = nil
    }
}
