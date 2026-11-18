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
    /// La presentazione dell'app, rivista dal profilo.
    var showsOnboarding = false
    /// Il foglio "AI Operational Credits".
    var showsCredits = false
    /// La card dei crediti: stato, testo e rilettura del saldo.
    let credits: AriaCreditsViewModel

    init(user: User, app: AppViewModel) {
        self.user = user
        self.app = app
        self.credits = AriaCreditsViewModel(backend: app.backend)
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

    /// Il ruolo nell'azienda attiva: quello dei diritti per chi ne ha uno ("Technician"), altrimenti per un admin
    /// "Owner" o "Admin", se il server lo dice.
    var roleLabel: String {
        if backend.rights.isRoleBased, let role = backend.access?.role?.name, !role.isEmpty { return role }
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

    // MARK: Crediti

    /// Il foglio dei crediti è alto di più della sola lista: il profilo si alza un poco quando la card c'è.
    var detentFraction: Double {
        (showsAvailability ? 0.72 : 0.67) + (credits.isVisible ? 0.08 : 0)
    }

    /// Tocco sulla card: i dettagli, o un nuovo tentativo se il saldo non si legge.
    func creditsTapped() {
        if credits.isFailed { credits.retry() } else { showsCredits = true }
    }

    // MARK: Server

    var isOnline: Bool { backend.isReady }

    // MARK: Giro guidato

    /// Il giro guidato c'è solo per chi ha dei passi (admin con le sezioni dei passi).
    var showsSetupTour: Bool { app.setupTour.hasSteps }

    /// Rifà "Primi passi con AriA" dall'intro: un replay, con la X, che non cambia lo stato di completamento.
    func replaySetupTour() { app.setupTour.replay() }

    // MARK: Uscita

    /// Lavoro fatto offline non ancora partito: uscendo si perde, quindi si chiede prima.
    func logoutTapped() {
        if app.unsyncedChanges > 0 { confirmingLogout = true } else { app.logout() }
    }

    func logout() { app.logout() }

    var unsyncedChanges: Int { app.unsyncedChanges }
}
