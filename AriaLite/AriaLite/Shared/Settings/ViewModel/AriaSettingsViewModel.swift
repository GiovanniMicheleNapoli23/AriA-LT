//
//  AriaSettingsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Le impostazioni: chi è entrato e con che ruolo (operatore o admin, lo dice /v1/me), crediti e disponibilità,
//  dove lavora (azienda e sito, si cambiano da qui), il server Aria, le guide, la versione e l'uscita. L'aspetto
//  (AriaAppearance) si ricorda sul telefono, fuori da qui. La disponibilità è solo degli operatori: a un admin
//  l'assegnazione automatica non manda lavori.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaSettingsViewModel {
    let user: User
    let app: AppViewModel

    var confirmingLogout = false
    /// La presentazione dell'app, rivista dalle impostazioni.
    var showsOnboarding = false
    /// La riga dei crediti: stato, testo e rilettura del saldo.
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

    /// Come è entrato: lo decide il backend (GET /v1/me), non il link usato.
    var accountType: String {
        (account?.kind ?? (isAdmin ? .admin : .operator)) == .admin
            ? String(localized: "Platform account") : String(localized: "Operator")
    }

    // MARK: Dove

    private var activeCompany: AriaCompany? { backend.companies.first { $0.id == backend.activeCompanyId } }

    var companyName: String? { activeCompany?.name }

    var plantName: String? { backend.activePlantName }

    /// Le aziende in cui si può entrare dall'app.
    var companies: [AriaCompany] { backend.companies.filter { $0.appAccess != false } }

    var activeCompanyId: String? { backend.activeCompanyId }

    var plants: [AriaPlant] { backend.plants }

    var activePlantId: String? { backend.activePlantId }

    /// Aziende o siti in lettura (la lista si vuota e si riempie cambiando azienda).
    var isLoadingWorkspace: Bool { backend.isLoading }

    func selectCompany(_ id: String) {
        guard id != activeCompanyId else { return }
        Task { await backend.selectCompany(id) }
    }

    func selectPlant(_ id: String) {
        guard id != activePlantId else { return }
        Task { await backend.selectPlant(id) }
    }

    /// La scelta del menu "Company" nella lista: cambiandola si rileggono siti e diritti.
    var companySelection: String? {
        get { activeCompanyId }
        set { if let newValue { selectCompany(newValue) } }
    }

    /// La scelta del menu "Site" nella lista.
    var plantSelection: String? {
        get { activePlantId }
        set { if let newValue { selectPlant(newValue) } }
    }

    // MARK: Disponibilità

    var showsAvailability: Bool { !isAdmin }

    private var workOrders: AriaWorkOrderStore { app.ariaWorkOrders }

    var availability: AriaAvailability { workOrders.availability }

    var isUpdatingAvailability: Bool { workOrders.isUpdatingAvailability }

    func setAvailability(_ value: AriaAvailability) {
        Task { await workOrders.setAvailability(value) }
    }

    /// Cosa comporta la scelta: `available` dura 12 ore dall'ultimo invio.
    var availabilityCaption: String {
        switch availability {
        case .available:
            if let at = workOrders.profile?.availabilityAt {
                let expiry = at.addingTimeInterval(12 * 3600)
                return String(localized: "Receiving new tasks until \(expiry.formatted(date: .omitted, time: .shortened))")
            }
            return String(localized: "Receiving new tasks")
        case .busy: return String(localized: "No new tasks while you are busy")
        case .offDuty: return String(localized: "No new tasks while you are off duty")
        }
    }

    // MARK: Server

    var isOnline: Bool { backend.isReady }

    // MARK: Versione

    /// "AriA 1.4 (212)", in fondo alla lista.
    var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        return ["AriA \(version)", build.map { "(\($0))" }].compactMap { $0 }.joined(separator: " ")
    }

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
