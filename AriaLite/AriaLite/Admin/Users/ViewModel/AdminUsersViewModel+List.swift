//
//  AdminUsersViewModel+List.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Quel che l'elenco di Users mostra e decide (§3): le righe già pronte, il pannello del tetto, i filtri.
//  Solo proprietà calcolate: lo stato sta in AdminUsersViewModel.
//

import Foundation

extension AdminUsersViewModel {
    // MARK: - Righe

    var items: [AdminUserListItem] {
        let viewer = viewer
        return visibleRows.map { AdminUserListItem($0, viewer: viewer) }
    }

    // MARK: - In alto (§3.4, §6.4)

    /// Il pannello dei titolari: dopo la prima lettura e se il server ha il tetto.
    var showsCapPanel: Bool { viewer.isOwner && hasLoaded && !seatsUnavailable }

    /// "Couldn't load your user limits." al posto dei numeri; Add user resta acceso.
    var showsCapFailure: Bool { showsCapPanel && seatsFailed }

    var seatsWording: AdminUsersSeatsWording? {
        guard showsCapPanel, !seatsFailed, let seatsInfo else { return nil }
        return AdminUsersSeatsWording(seatsInfo)
    }

    /// Add user è spento al tetto: la riga lo dice sotto l'avviso.
    var addIsPausedByCap: Bool { viewer.isOwner && !seatsFailed && capState != .open }

    // MARK: - Filtri (§3.3)

    var hasActiveFilters: Bool { !filters.isEmpty }

    /// Il filtro "Online" è dei titolari.
    var offersOnlineFilter: Bool { viewer.isOwner }

    var offersFilters: Bool { hasLoaded && !people.isEmpty }

    func clearFilters() {
        filters = AdminUserFilters()
    }

    func clearSearchAndFilters() {
        query = ""
        clearFilters()
    }

    // MARK: - Revoca (§6.3)

    func canRevoke(_ row: AdminUserRow) -> Bool { viewer.isOwner && row.isInvitation }

    /// L'avviso di conferma sta aperto finché c'è un invito da revocare.
    var isRevokeAlertPresented: Bool {
        get { invitationToRevoke != nil }
        set { if !newValue { invitationToRevoke = nil } }
    }

    func revokeTitle(for row: AdminUserRow) -> String {
        let email = Self.invitationLabel(row)
        return String(localized: "Revoke the invitation to \(email)?")
    }

    /// L'email dell'invito; senza, il nome che la riga mostra.
    static func invitationLabel(_ row: AdminUserRow) -> String { row.email ?? row.displayName }
}
