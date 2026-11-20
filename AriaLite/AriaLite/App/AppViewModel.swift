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
    /// Il giro guidato dell'admin, obbligatorio: lo stato sta qui, la shell lo mostra sopra le sezioni.
    let setupTour: AriaSetupTourViewModel

    /// Sezioni della web: tutte per gli account della piattaforma, una parte per l'operatore (AriaSidebarSections).
    /// Si creano alla prima lettura (di solito quando la sezione si apre), non tutte all'avvio: la shell ne ha ~24 e
    /// l'app deve mostrare il primo fotogramma.
    /// Al logout si azzerano solo quelle già create (`resetters`); fa eccezione Documents, il cui archivio dei
    /// caricamenti sta su disco ed è di chi esce anche se la sezione non è mai stata aperta.
    @ObservationIgnored private(set) lazy var adminDocuments: AdminDocumentsViewModel = AdminDocumentsViewModel(backend: backend)
    @ObservationIgnored private(set) lazy var adminAgentStudio: AdminAgentStudioViewModel = track(AdminAgentStudioViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminMarketplace: AdminMarketplaceViewModel = track(AdminMarketplaceViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminExtractionReview: AdminExtractionReviewViewModel = track(AdminExtractionReviewViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminLearnedKnowledge: AdminLearnedKnowledgeViewModel = track(AdminLearnedKnowledgeViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminScenarioAnalysis: AdminScenarioAnalysisViewModel = track(AdminScenarioAnalysisViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminCrafted: AdminCraftedViewModel = track(AdminCraftedViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminWorkOrders: AdminWorkOrdersViewModel = track(AdminWorkOrdersViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminMaintenance: AdminMaintenanceViewModel = track(AdminMaintenanceViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminInspections: AdminInspectionsViewModel = track(AdminInspectionsViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminTaskboard: AdminTaskboardViewModel = track(AdminTaskboardViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminAssets: AdminAssetsViewModel = track(AdminAssetsViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminSpareParts: AdminSparePartsViewModel = track(AdminSparePartsViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminPurchaseOrders: AdminPurchaseOrdersViewModel = track(AdminPurchaseOrdersViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminVendors: AdminVendorsViewModel = track(AdminVendorsViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminAlarms: AdminAlarmsViewModel = track(AdminAlarmsViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminReports: AdminReportsViewModel = track(AdminReportsViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminUsage: AdminUsageViewModel = track(AdminUsageViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminUsageBilling: AdminUsageBillingViewModel = track(AdminUsageBillingViewModel(backend: backend, page: adminUsage)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminPlants: AdminPlantsViewModel = track(AdminPlantsViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminCategories: AdminCategoriesViewModel = track(AdminCategoriesViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminTeams: AdminTeamsViewModel = track(AdminTeamsViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminUsers: AdminUsersViewModel = track(AdminUsersViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private(set) lazy var adminRoles: AdminRolesViewModel = track(AdminRolesViewModel(backend: backend)) { $0.reset() }
    @ObservationIgnored private var resetters: [() -> Void] = []

    /// Registra un modello creato alla prima lettura, perché il logout lo azzeri.
    private func track<M: AnyObject>(_ model: M, reset: @escaping (M) -> Void) -> M {
        resetters.append { reset(model) }
        return model
    }

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

    /// La presentazione dell'app prima del login (AriaOnboardingView): solo finché non la si è vista una volta.
    private(set) var showsOnboarding = false
    @ObservationIgnored private let onboarding = AriaOnboardingProgress()

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
        setupTour = AriaSetupTourViewModel()
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
        // Chi aveva già un accesso conosce l'app: uscendo non si ritrova la presentazione.
        if loggedInUser != nil { onboarding.markSeen() }
        showsOnboarding = !onboarding.isSeen
    }

    // MARK: - Dopo il primo fotogramma

    /// Lavoro che non serve a disegnare la prima schermata: ritrovare i caricamenti di documenti lasciati
    /// dall'esecuzione precedente (li fa Documents, che si crea qui alla prima lettura). Lo chiama la radice a
    /// fotogramma mostrato.
    func resumeBackgroundWork() {
        _ = adminDocuments
    }

    // MARK: - Sidebar

    /// Pull-to-refresh della sidebar: sezioni (diritti) e conversazioni si rileggono solo quando lo chiede l'utente
    /// o succede qualcosa, mai a intervalli.
    func refreshSidebar() async {
        await backend.refreshMembership()
        await sessions.load()
    }

    // MARK: - Presentazione

    /// Finita, saltata o superata da un accesso: non torna più da sola, si rivede dal profilo.
    func finishOnboarding() {
        onboarding.markSeen()
        showsOnboarding = false
    }

    // MARK: - Face ID

    /// Chiede Face ID (o il codice del telefono) e riapre l'app. Annullare lascia l'app chiusa.
    func unlock() async {
        guard lock != .none, !isUnlocking else { return }
        AriaAuthTrace.step("unlock.start", "\(lock)")
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
        AriaAuthTrace.step("unlock.cleared")
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
        finishOnboarding()
    }
    #endif

    // MARK: - Iscrizione

    /// Profilo, Azienda, Stabilimento e Piano fatti (o già fatti sulla web): la shell, col nome scritto al passo Profilo.
    /// L'iscrizione in corso, con l'account di chi la sta facendo. Vive qui e non nella vista: tutto si scrive alla
    /// fine, e la bozza non deve perdersi se la schermata viene ricreata. Un altro account (sessione scaduta e nuovo
    /// accesso) non la eredita mai.
    @ObservationIgnored private var signUpDraft: (account: String, model: AriaSignUpViewModel)?

    func signUpModel() -> AriaSignUpViewModel {
        let account = backend.mobileAccount?.id ?? ""
        if let signUpDraft, signUpDraft.account == account { return signUpDraft.model }
        let model = AriaSignUpViewModel(app: self)
        signUpDraft = (account, model)
        return model
    }

    func signUpFinished() {
        guard !backend.isSigningUp, let account = backend.mobileAccount else { return }
        signUpDraft = nil
        loggedInUser = User(account)
    }

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
        // Un link toccato nell'email mentre la presentazione è aperta la chiude.
        finishOnboarding()
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
        signUpDraft = nil
        lock = .none
        unlockError = nil
        // Un altro operatore sullo stesso device non eredita la sessione Aria.
        mainChat.newConversation()
        AriaTaskProgressStore.shared.forgetAll()
        sessions.reset()
        ariaWorkOrders.reset(keepOfflineWork: keepOfflineWork)
        adminDocuments.reset()
        resetters.forEach { $0() }
        // File scaricati, report esportati e foto in cache non restano per chi entra dopo.
        AriaLocalFiles.removeTemporaryDocuments()
        URLCache.shared.removeAllCachedResponses()
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
