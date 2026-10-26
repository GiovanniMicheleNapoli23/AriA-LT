//
//  AriaSettingsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Il profilo nelle impostazioni: chi è entrato e con che ruolo (operatore o admin, lo dice /v1/me),
//  dove lavora (azienda e impianto), il server Aria e l'uscita. La disponibilità è solo degli operatori:
//  a un admin l'assegnazione automatica non manda lavori.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaSettingsViewModel {
    let user: User
    let app: AppViewModel

    var showsConnection = false
    var confirmingLogout = false

    init(user: User, app: AppViewModel) {
        self.user = user
        self.app = app
    }

    private var backend: AriaBackend { app.backend }
    private var account: AriaMobileAccount? { backend.mobileAccount }

    // MARK: Chi

    var name: String {
        let name = account?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? user.name : name
    }

    /// Le iniziali di nome e cognome ("GN"); una sola lettera se il nome è una parola.
    var initials: String {
        let words = name.split(whereSeparator: \.isWhitespace)
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var email: String? {
        let email = account?.email ?? user.username
        return email.contains("@") ? email : nil
    }

    var isAdmin: Bool { backend.isAdmin }

    /// Per un admin il ruolo nell'azienda attiva ("Owner", "Admin"), se il server lo dice.
    var roleLabel: String {
        guard isAdmin else { return String(localized: "Operator") }
        switch activeCompany?.myRole?.lowercased() {
        case "owner": return String(localized: "Owner")
        case "member": return String(localized: "Member")
        default: return String(localized: "Admin")
        }
    }

    var roleSymbol: String { isAdmin ? "person.badge.shield.checkmark.fill" : "wrench.and.screwdriver.fill" }

    // MARK: Dove

    private var activeCompany: AriaCompany? { backend.companies.first { $0.id == backend.activeCompanyId } }

    var companyName: String? { activeCompany?.name }

    var plantName: String? { backend.activePlantName }

    var showsWorkspace: Bool { companyName != nil || plantName != nil }

    var showsAvailability: Bool { !isAdmin }

    // MARK: Server

    var isOnline: Bool { backend.isReady }

    // MARK: Uscita

    /// Lavoro fatto offline non ancora partito: uscendo si perde, quindi si chiede prima.
    func logoutTapped() {
        if app.unsyncedChanges > 0 { confirmingLogout = true } else { app.logout() }
    }

    func logout() { app.logout() }

    var unsyncedChanges: Int { app.unsyncedChanges }
}
