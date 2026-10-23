//
//  AppViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import CryptoKit
import Foundation

@Observable
class AppViewModel {
    var loggedInUser: User? = nil

    /// Connessione al backend Aria: chat, lavori e account.
    let backend: AriaBackend
    /// Chat principale: resta viva tra un cambio di sezione e l'altro.
    let mainChat: AriaAgentChat
    /// Conversazioni salvate: sidebar (Fissate / Recenti) e schermata Chat.
    let sessions: AriaSessionStore
    /// Lavori assegnati all'account Aria e disponibilità dell'operatore.
    let ariaWorkOrders: AriaWorkOrderStore
    /// Notifiche push dei lavori assegnati.
    let notifications = AriaPushNotifications.shared

    /// Sezioni della web, per gli account della piattaforma (non operatori).
    let adminDocuments: AdminDocumentsViewModel
    let adminAgentStudio: AdminAgentStudioViewModel
    let adminMarketplace: AdminMarketplaceViewModel
    let adminExtractionReview: AdminExtractionReviewViewModel
    let adminLearnedKnowledge: AdminLearnedKnowledgeViewModel
    let adminScenarioAnalysis: AdminScenarioAnalysisViewModel
    let adminCrafted: AdminCraftedViewModel
    let adminWorkOrders: AdminWorkOrdersViewModel
    let adminMaintenance: AdminMaintenanceViewModel
    let adminInspections: AdminInspectionsViewModel
    let adminTaskboard: AdminTaskboardViewModel
    let adminAssets: AdminAssetsViewModel
    let adminSpareParts: AdminSparePartsViewModel
    let adminPurchaseOrders: AdminPurchaseOrdersViewModel
    let adminVendors: AdminVendorsViewModel
    let adminAlarms: AdminAlarmsViewModel
    let adminReports: AdminReportsViewModel
    let adminLLMUsage: AdminLLMUsageViewModel
    let adminPlants: AdminPlantsViewModel
    let adminCategories: AdminCategoriesViewModel
    let adminTeams: AdminTeamsViewModel
    let adminMembers: AdminMembersViewModel
    let adminMobileUsers: AdminMobileUsersViewModel

    /// Operatore o account della piattaforma: decide le sezioni della sidebar.
    var accountKind: AriaAccountKind { backend.accountKind }

    /// L'app chiusa a chiave con Face ID.
    enum SessionLock: Equatable {
        case none
        /// Avvio con una sessione salvata: la sessione è ancora nel Keychain, l'app non si mostra.
        case launch
        /// Ritorno dal background: l'app resta sotto com'era, coperta finché Face ID non la riapre.
        case resume
    }

    private(set) var lock: SessionLock = .none
    private(set) var isUnlocking = false
    /// Face ID non è andato (non un annullamento): il messaggio sotto il pulsante.
    private(set) var unlockError: String?
    /// Il prompt parte da solo una volta per chiusura; dopo un annullamento resta il pulsante.
    @ObservationIgnored private var didPromptUnlock = false

    /// Accesso da un link aperto dal sistema (email toccata): la schermata di login mostra l'attesa…
    private(set) var isOpeningLink = false
    /// …e l'esito, che poi azzera.
    var openedLinkResult: LoginResult?

    init() {
        let backend = AriaBackend()
        self.backend = backend
        #if DEBUG
        // UI test: si riparte senza la sessione rimasta nel Keychain, che chiederebbe Face ID.
        if Self.uiTestSession != nil { backend.discardSavedSessionForUITests() }
        #endif
        mainChat = AriaAgentChat(backend: backend, remembersSession: true)
        sessions = AriaSessionStore(backend: backend)
        ariaWorkOrders = AriaWorkOrderStore(backend: backend)
        adminDocuments = AdminDocumentsViewModel(backend: backend)
        adminAgentStudio = AdminAgentStudioViewModel(backend: backend)
        adminMarketplace = AdminMarketplaceViewModel(backend: backend)
        adminExtractionReview = AdminExtractionReviewViewModel(backend: backend)
        adminLearnedKnowledge = AdminLearnedKnowledgeViewModel(backend: backend)
        adminScenarioAnalysis = AdminScenarioAnalysisViewModel(backend: backend)
        adminCrafted = AdminCraftedViewModel(backend: backend)
        adminWorkOrders = AdminWorkOrdersViewModel(backend: backend)
        adminMaintenance = AdminMaintenanceViewModel(backend: backend)
        adminInspections = AdminInspectionsViewModel(backend: backend)
        adminTaskboard = AdminTaskboardViewModel(backend: backend)
        adminAssets = AdminAssetsViewModel(backend: backend)
        adminSpareParts = AdminSparePartsViewModel(backend: backend)
        adminPurchaseOrders = AdminPurchaseOrdersViewModel(backend: backend)
        adminVendors = AdminVendorsViewModel(backend: backend)
        adminAlarms = AdminAlarmsViewModel(backend: backend)
        adminReports = AdminReportsViewModel(backend: backend)
        adminLLMUsage = AdminLLMUsageViewModel(backend: backend)
        adminPlants = AdminPlantsViewModel(backend: backend)
        adminCategories = AdminCategoriesViewModel(backend: backend)
        adminTeams = AdminTeamsViewModel(backend: backend)
        adminMembers = AdminMembersViewModel(backend: backend)
        adminMobileUsers = AdminMobileUsersViewModel(backend: backend)
        #if DEBUG
        // UI test: ogni avvio parte da una chat vuota, non dall'ultima conversazione (che può avere una procedura
        // aperta al posto della barra di scrittura).
        if Self.uiTestSession != nil { mainChat.newConversation() }
        #endif
        // La sessione resta salvata: il link via email non si richiede a ogni avvio.
        if backend.isSignedIn, let account = backend.mobileAccount {
            loggedInUser = User(account)
        }
        // La sessione salvata si apre con Face ID prima di mostrare l'app.
        if loggedInUser != nil, backend.needsUnlock { lock = .launch }
    }

    // MARK: - Face ID

    /// Chiede Face ID (o il codice del telefono) e riapre l'app. Annullare lascia l'app chiusa.
    func unlock() async {
        guard lock != .none, !isUnlocking else { return }
        isUnlocking = true
        unlockError = nil
        defer { isUnlocking = false }
        do {
            try await backend.unlock(reason: String(localized: "Unlock your Aria session"))
        } catch {
            AriaAuthTrace.failure("unlock.failed", error)
            if !AriaBiometrics.isCancellation(error) { unlockError = error.localizedDescription }
            return
        }
        // Sessione sparita dal Keychain: `backend.isSignedIn` è falso e ContentView torna al login.
        lock = .none
    }

    /// Il primo prompt parte da solo appena l'app è in primo piano, una volta per chiusura.
    func unlockAutomatically() async {
        guard lock != .none, !didPromptUnlock else { return }
        didPromptUnlock = true
        await unlock()
    }

    /// L'app va in background: al ritorno serve di nuovo Face ID.
    func lockForBackground() {
        guard loggedInUser != nil, backend.needsUnlock else { return }
        if lock == .none { lock = .resume }
        unlockError = nil
        didPromptUnlock = false
    }

    // MARK: - Auth

    enum LoginResult: Equatable {
        case success
        /// Il server di accesso non si raggiunge: le credenziali non c'entrano.
        case offline
        case failure(String)
    }

    // Il passo 1 (l'invio dei link) è di LoginViewModel: qui solo ciò che apre la sessione.

    /// Passo 2: il link incollato, dell'operatore (15') o della web (10'). Vale una volta sola.
    func completeLogin(with pasted: String) async -> LoginResult {
        guard let link = backend.magicLink(in: pasted) else {
            return .failure(String(localized: "This is not an Aria sign-in link. Copy the link from the email and try again."))
        }
        return await signIn(with: link)
    }

    /// Passo 2, con il link aperto dal sistema: il magic link della web (Universal Link: l'host lo apre nell'app
    /// grazie a `callbackURL=/?from=aria-ios`), `aria://sign-in#token=…`, o `/m/sign-in` se l'host lo permette.
    func open(_ url: URL) {
        guard let link = backend.signInLink(from: url) else { return }
        // Con un accesso già aperto il link non serve: per cambiare account si esce prima.
        guard loggedInUser == nil else {
            AriaAuthTrace.step("link.ignored", "accesso già aperto")
            return
        }
        guard !isOpeningLink else { return }
        isOpeningLink = true
        Task {
            openedLinkResult = await signIn(with: link)
            isOpeningLink = false
        }
    }

    #if DEBUG
    /// Solo sviluppo: il link arriva come argomento di avvio, perché gli appunti Mac ↔ simulatore
    /// a volte non funzionano. Vale l'una o l'altra forma del link (operatore o web):
    /// xcrun simctl launch --terminate-running-process booted com.giovanniMichele.AriaLite -AriaMagicLink "<link>"
    func signInWithLaunchLink() async {
        guard loggedInUser == nil, let raw = UserDefaults.standard.string(forKey: "AriaMagicLink"),
              let link = backend.magicLink(in: raw) else { return }
        openedLinkResult = await signIn(with: link)
    }

    /// Solo UI test: la sessione di un operatore (`set-auth-token`) arriva come variabile d'ambiente di avvio
    /// (`ARIA_UITEST_SESSION`), perché il link via email vale una volta sola e arriva in una casella di posta.
    private static var uiTestSession: String? {
        let raw = ProcessInfo.processInfo.environment["ARIA_UITEST_SESSION"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw?.isEmpty == false ? raw : nil
    }

    func signInForUITests() async {
        guard loggedInUser == nil, let token = Self.uiTestSession else { return }
        do {
            try await backend.useSessionToken(token)
        } catch {
            AriaAuthTrace.failure("uitest.session.failed", error)
            openedLinkResult = .failure(error.localizedDescription)
            return
        }
        guard backend.isSignedIn, let account = backend.mobileAccount else {
            openedLinkResult = .failure(backend.lastError ?? AriaError.signedOut.localizedDescription)
            return
        }
        loggedInUser = User(account)
    }
    #endif

    private func signIn(with link: AriaSignInLink) async -> LoginResult {
        do {
            try await backend.completeSignIn(with: link)
        } catch {
            AriaAuthTrace.failure("login.completeLink.failed", error)
            return AriaHTTP.isOffline(error) ? .offline : .failure(error.localizedDescription)
        }
        // Il link è andato a buon fine ma la sessione può essere già finita (nessuna azienda attiva).
        guard backend.isSignedIn, let account = backend.mobileAccount else {
            return .failure(backend.lastError ?? AriaError.signedOut.localizedDescription)
        }
        AriaAuthTrace.step("login.ok", "azienda=\(backend.activeCompanyId ?? "-") stabilimento=\(backend.activePlantId ?? "-")")
        loggedInUser = User(account)
        return .success
    }

    /// Sessione Aria finita da sola (scaduta, account disattivato, altro dispositivo):
    /// l'operatore torna al login.
    func ariaSessionEnded() {
        guard loggedInUser != nil, !backend.isSignedIn else { return }
        // Le modifiche ai lavori non ancora partite restano: rientrando, lo stesso operatore le manda.
        logout(keepOfflineWork: true)
    }

    /// Modifiche ai lavori fatte sul telefono e non ancora arrivate al server: uscendo si perdono.
    var unsyncedChanges: Int { ariaWorkOrders.pendingCount }

    func logout(keepOfflineWork: Bool = false) {
        loggedInUser = nil
        lock = .none
        unlockError = nil
        // Un altro operatore sullo stesso device non eredita la sessione Aria.
        mainChat.newConversation()
        AriaTaskProgressStore.shared.forgetAll()
        sessions.reset()
        ariaWorkOrders.reset(keepOfflineWork: keepOfflineWork)
        adminDocuments.reset()
        adminAgentStudio.reset()
        adminMarketplace.reset()
        adminExtractionReview.reset()
        adminLearnedKnowledge.reset()
        adminScenarioAnalysis.reset()
        adminCrafted.reset()
        adminWorkOrders.reset()
        adminMaintenance.reset()
        adminInspections.reset()
        adminTaskboard.reset()
        adminAssets.reset()
        adminSpareParts.reset()
        adminPurchaseOrders.reset()
        adminVendors.reset()
        adminAlarms.reset()
        adminReports.reset()
        adminLLMUsage.reset()
        adminPlants.reset()
        adminCategories.reset()
        adminTeams.reset()
        adminMembers.reset()
        adminMobileUsers.reset()
        Task {
            // Il token si toglie finché la sessione vale ancora: dopo il server non lo accetterebbe.
            await notifications.unregister()
            await backend.signOut()
        }
    }
}

private extension User {
    /// Utente dell'app per l'operatore Aria. L'UUID si ricava da un hash dell'id del server,
    /// così lo stesso operatore ha lo stesso id anche dopo un riavvio.
    init(_ account: AriaMobileAccount) {
        let bytes = Array(SHA256.hash(data: Data(account.id.utf8)).prefix(16))
        let id = bytes.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
        let fallbackName = account.email.split(separator: "@").first.map(String.init) ?? account.email
        self.init(id: id, username: account.email, name: account.name.isEmpty ? fallbackName : account.name)
    }
}
