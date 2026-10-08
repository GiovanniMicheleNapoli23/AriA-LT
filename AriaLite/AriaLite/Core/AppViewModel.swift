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
    var checklistCompletions: [UUID: [UUID: Bool]] = [:]
    var fieldNotes: [UUID: [UUID: FieldNote]] = [:]
    var photoAttachments: [UUID: [PhotoAttachment]] = [:]
    var submissionStatus: SubmissionStatus = .idle
    var submittedWorkOrders: Set<UUID> = []
    var searchText: String = ""

    /// Connessione al backend Aria (chat reale). Indipendente dal login locale qui sotto.
    let backend: AriaBackend
    /// Chat principale: resta viva tra un cambio di sezione e l'altro.
    let mainChat: AriaAgentChat
    /// Conversazioni salvate: sidebar (Fissate / Recenti) e schermata Chat.
    let sessions: AriaSessionStore
    /// Lavori assegnati all'account Aria e disponibilità dell'operatore.
    let ariaWorkOrders: AriaWorkOrderStore

    /// L'operatore è entrato con un account Aria (utente mobile), non coi dati mock:
    /// se la sessione Aria finisce, finisce anche l'accesso all'app.
    private(set) var isAriaAccount = false

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
        mainChat = AriaAgentChat(backend: backend, remembersSession: true)
        sessions = AriaSessionStore(backend: backend)
        ariaWorkOrders = AriaWorkOrderStore(backend: backend)
        // La sessione dura 7 giorni: il link via email non si richiede a ogni avvio.
        if backend.isSignedIn, let account = backend.mobileAccount {
            loggedInUser = User(account)
            isAriaAccount = true
        } else if backend.isSignedIn, let account = backend.webAccount {
            loggedInUser = User(account)
            isAriaAccount = true
        }
        // La sessione salvata si apre con Face ID prima di mostrare l'app.
        if isAriaAccount, backend.needsUnlock { lock = .launch }
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
        guard isAriaAccount, loggedInUser != nil, backend.needsUnlock else { return }
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

    /// Passo 1: manda il link di accesso all'email (captcha Turnstile risolto nella schermata).
    func sendLoginLink(email: String, captcha: String) async -> LoginResult {
        AriaAuthTrace.step("login.sendLink", "server=\(backend.webURL.absoluteString)")
        do {
            try await backend.sendMagicLink(email: email, captcha: captcha)
            return .success
        } catch {
            AriaAuthTrace.failure("login.sendLink.failed", error)
            return AriaHTTP.isOffline(error) ? .offline : .failure(error.localizedDescription)
        }
    }

    /// Passo 2: il link incollato dall'operatore. È valido una volta sola e per 10 minuti.
    func completeLogin(with pasted: String) async -> LoginResult {
        guard let link = backend.magicLink(in: pasted) else {
            return .failure(String(localized: "This is not an Aria sign-in link. Copy the link from the email and try again."))
        }
        return await signIn(with: link)
    }

    /// Passo 2, toccando il link nell'email: iOS apre l'app con il link (Universal Link,
    /// o `aria://` dal pulsante della pagina web).
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
    /// a volte non funzionano:
    /// xcrun simctl launch --terminate-running-process booted com.giovanniMichele.AriaLite -AriaMagicLink "<link>"
    func signInWithLaunchLink() async {
        guard loggedInUser == nil, let raw = UserDefaults.standard.string(forKey: "AriaMagicLink"),
              let link = backend.magicLink(in: raw) else { return }
        openedLinkResult = await signIn(with: link)
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
        guard backend.isSignedIn, let account = backend.webAccount else {
            return .failure(backend.lastError ?? AriaError.signedOut.localizedDescription)
        }
        AriaAuthTrace.step("login.ok", "azienda=\(backend.activeCompanyId ?? "-") stabilimento=\(backend.activePlantId ?? "-")")
        loggedInUser = User(account)
        isAriaAccount = true
        return .success
    }

    /// Sessione Aria finita da sola (scaduta, account disattivato, altro dispositivo):
    /// un operatore entrato con l'account Aria torna al login.
    func ariaSessionEnded() {
        guard isAriaAccount, loggedInUser != nil, !backend.isSignedIn else { return }
        logout()
    }

    func logout() {
        isAriaAccount = false
        loggedInUser = nil
        lock = .none
        unlockError = nil
        checklistCompletions = [:]
        fieldNotes = [:]
        photoAttachments = [:]
        submissionStatus = .idle
        // Un altro operatore sullo stesso device non eredita la sessione Aria.
        mainChat.newConversation()
        sessions.reset()
        ariaWorkOrders.reset()
        Task { await backend.signOut() }
    }

    // MARK: - WorkOrders
    var filteredWorkOrders: [WorkOrder] {
        guard let user = loggedInUser else { return [] }
        let assigned = mockWorkOrders.filter { $0.assignedUserID == user.id }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return assigned }
        return assigned.filter { $0.title.lowercased().contains(query) }
    }

    var todayWorkOrders: [WorkOrder] {
        filteredWorkOrders.filter {
            Calendar.current.isDateInToday($0.scheduledDate)
        }
    }

    var pastWorkOrdersByDay: [(key: String, value: [WorkOrder])] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let past = filteredWorkOrders.filter { $0.scheduledDate < startOfToday }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = .autoupdatingCurrent

        let grouped = Dictionary(grouping: past) { formatter.string(from: $0.scheduledDate) }

        return grouped.sorted { lhs, rhs in
            let d1 = formatter.date(from: lhs.key) ?? .distantPast
            let d2 = formatter.date(from: rhs.key) ?? .distantPast
            return d1 > d2
        }
    }

    // MARK: - Checklist
    func toggleItem(workOrderID: UUID, itemID: UUID, current: Bool) {
        if checklistCompletions[workOrderID] == nil {
            checklistCompletions[workOrderID] = [:]
        }
        checklistCompletions[workOrderID]?[itemID] = !current
    }

    func isItemCompleted(_ item: ChecklistItem, in workOrderID: UUID) -> Bool {
        checklistCompletions[workOrderID]?[item.id] ?? item.isCompleted
    }

    // MARK: - Field Notes
    func upsertNote(workOrderID: UUID, itemID: UUID, text: String) {
        if fieldNotes[workOrderID] == nil { fieldNotes[workOrderID] = [:] }
        let note = FieldNote(
            id: fieldNotes[workOrderID]?[itemID]?.id ?? UUID(),
            checklistItemID: itemID,
            text: text,
            createdAt: Date()
        )
        fieldNotes[workOrderID]?[itemID] = note
    }

    // MARK: - Photos
    func addPhoto(_ photo: PhotoAttachment, to workOrderID: UUID) {
        if photoAttachments[workOrderID] == nil { photoAttachments[workOrderID] = [] }
        photoAttachments[workOrderID]?.append(photo)
    }

    func removePhoto(id: UUID, from workOrderID: UUID) {
        photoAttachments[workOrderID]?.removeAll { $0.id == id }
    }

    // MARK: - Submit
    func submitReport(for workOrder: WorkOrder) async {
        guard let user = loggedInUser else { return }
        submissionStatus = .sending

        let items = workOrder.checklist.map {
            ReportChecklistItem(
                id: $0.id,
                text: $0.text,
                isCompleted: isItemCompleted($0, in: workOrder.id)
            )
        }
        let notes = Array((fieldNotes[workOrder.id] ?? [:]).values)
        let photos = photoAttachments[workOrder.id] ?? []

        let report = WorkOrderReport(
            workOrderID: workOrder.id,
            technicianID: user.id,
            technicianName: user.name,
            submittedAt: Date(),
            checklistItems: items,
            fieldNotes: notes,
            photos: photos
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            _ = try encoder.encode(report)
            try await Task.sleep(for: .seconds(0.5))
            submittedWorkOrders.insert(workOrder.id)
            submissionStatus = .success
        } catch {
            submissionStatus = .failure(error.localizedDescription)
        }
    }
}

private extension User {
    /// Utente dell'app per un account Aria. L'id Mongo (24 cifre esadecimali) diventa un UUID
    /// stabile, così lo stesso account ha lo stesso id anche dopo un riavvio.
    init(_ account: AriaMobileAccount) {
        let hex = account.id.lowercased()
        let stable: UUID? = hex.count == 24 && hex.allSatisfy(\.isHexDigit)
            ? UUID(uuidString: "00000000-\(hex.prefix(4))-\(hex.dropFirst(4).prefix(4))-\(hex.dropFirst(8).prefix(4))-\(hex.suffix(12))")
            : nil
        self.init(id: stable ?? UUID(), username: account.displayUsername ?? account.username, name: account.name)
    }
}

private extension User {
    /// Utente dell'app per l'accesso dalla web. L'id better-auth non è esadecimale: l'UUID si ricava
    /// da un hash, così lo stesso utente ha lo stesso id anche dopo un riavvio.
    init(_ account: AriaWebAccount) {
        let bytes = Array(SHA256.hash(data: Data(account.id.utf8)).prefix(16))
        let id = bytes.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
        let fallbackName = account.email.split(separator: "@").first.map(String.init) ?? account.email
        self.init(id: id, username: account.email, name: account.name.isEmpty ? fallbackName : account.name)
    }
}
