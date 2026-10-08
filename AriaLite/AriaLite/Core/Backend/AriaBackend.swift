//
//  AriaBackend.swift
//  AriaLite
//
//  Stato della connessione al backend Aria: login, azienda e stabilimento attivi.
//  È separato dal login locale (mock) dell'app: la chat usa il backend solo
//  quando `isReady`, altrimenti ricade sul motore locale.
//  Si entra con username + password dell'utente mobile sull'host di accesso (AriaAuth),
//  poi l'azienda arriva da GET /v1/companies sull'host API.
//
import Foundation
import Observation

@Observable
final class AriaBackend {
    private(set) var api: AriaAPIClient
    private(set) var isSignedIn: Bool
    private(set) var companies: [AriaCompany] = []
    private(set) var plants: [AriaPlant] = []
    private(set) var activeCompanyId: String?
    private(set) var activePlantId: String?
    private(set) var isLoading = false
    var lastError: String?
    /// Utente mobile collegato (login con username); `nil` da scollegati o con un accesso dalla web (magic link).
    private(set) var mobileAccount: AriaMobileAccount?
    /// Utente della web collegato col magic link; `nil` da scollegati o con un utente mobile.
    private(set) var webAccount: AriaWebAccount?
    /// Email a cui è stato mandato il link di accesso, finché il link è valido (10').
    /// Sta qui e non nello sheet: l'utente chiude lo sheet per andare a copiare il link.
    private(set) var pendingLinkEmail: String?
    /// Che link è partito: quello dell'app si tocca nell'email, quello della web si incolla.
    private(set) var pendingLinkDelivery: AriaLinkDelivery?

    @ObservationIgnored private var didBootstrap = false

    init() {
        let api = Self.makeClient(.current)
        self.api = api
        isSignedIn = api.auth.hasStoredSession
        activeCompanyId = UserDefaults.standard.string(forKey: "aria.company_id")
        activePlantId = UserDefaults.standard.string(forKey: "aria.plant_id")
        if isSignedIn, api.auth.isMobileSession,
           let saved = UserDefaults.standard.data(forKey: Self.mobileAccountKey) {
            mobileAccount = try? JSONDecoder().decode(AriaMobileAccount.self, from: saved)
        }
        if isSignedIn, !api.auth.isMobileSession,
           let saved = UserDefaults.standard.data(forKey: Self.webAccountKey) {
            webAccount = try? JSONDecoder().decode(AriaWebAccount.self, from: saved)
        }
        if let sentAt = UserDefaults.standard.object(forKey: Self.linkSentAtKey) as? Date,
           sentAt.timeIntervalSinceNow > -Self.linkLifetime {
            pendingLinkEmail = UserDefaults.standard.string(forKey: Self.linkEmailKey)
            pendingLinkDelivery = UserDefaults.standard.string(forKey: Self.linkDeliveryKey)
                .flatMap(AriaLinkDelivery.init(rawValue:)) ?? .web
        }
    }

    private static let linkEmailKey = "aria.magic_link_email"
    private static let linkDeliveryKey = "aria.magic_link_delivery"
    private static let linkSentAtKey = "aria.magic_link_sent_at"
    private static let linkLifetime: TimeInterval = 10 * 60

    private static let mobileAccountKey = "aria.mobile_account"
    private static let webAccountKey = "aria.web_account"

    /// La chat può parlare col backend: serve una sessione e uno stabilimento (`plant_id` è obbligatorio).
    var isReady: Bool { isSignedIn && activePlantId != nil }

    /// Host dei dati (/v1).
    var serverURL: URL { api.config.apiBaseURL }
    /// Host di accesso: solo login, token e logout.
    var authURL: URL { api.config.authBaseURL }
    /// Web app: solo per aprire i link relativi delle risposte.
    var webURL: URL { api.config.webBaseURL }

    var activePlantName: String? { plants.first { $0.id == activePlantId }?.name }

    private static func makeClient(_ config: AriaConfig) -> AriaAPIClient {
        AriaAPIClient(config: config, auth: AriaAuth(config: config), context: AriaContext())
    }

    // MARK: Login con username (utenti mobili)

    /// Login completo (`acme.mario.rossi`), senza spazi attorno; maiuscole e minuscole non contano.
    func signIn(username: String, password: String) async throws {
        let account = try await api.auth.signIn(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        setMobileAccount(account)
        setWebAccount(nil)
        isSignedIn = true
        await bootstrap()
    }

    private func setWebAccount(_ account: AriaWebAccount?) {
        webAccount = account
        UserDefaults.standard.set(account.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.webAccountKey)
    }

    private func setMobileAccount(_ account: AriaMobileAccount?) {
        mobileAccount = account
        UserDefaults.standard.set(account.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.mobileAccountKey)
    }

    // MARK: Login con magic link (come la web)

    func sendMagicLink(email: String, captcha: String) async throws {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        let delivery = try await api.auth.sendMagicLink(email: email, captcha: captcha, locale: api.context.locale)
        setPendingLink(email, delivery: delivery)
    }

    /// Torna al passo dell'email (per chiedere un nuovo link).
    func cancelPendingLink() {
        setPendingLink(nil)
    }

    private func setPendingLink(_ email: String?, delivery: AriaLinkDelivery? = nil) {
        pendingLinkEmail = email
        pendingLinkDelivery = email == nil ? nil : delivery
        UserDefaults.standard.set(email, forKey: Self.linkEmailKey)
        UserDefaults.standard.set(pendingLinkDelivery?.rawValue, forKey: Self.linkDeliveryKey)
        UserDefaults.standard.set(email == nil ? nil : Date.now, forKey: Self.linkSentAtKey)
    }

    /// Il link di accesso contenuto in un testo incollato, se c'è.
    func magicLink(in text: String) -> AriaSignInLink? {
        api.auth.magicLink(in: text)
    }

    /// Il link di accesso in un URL aperto dal sistema (email toccata, pulsante della pagina web).
    func signInLink(from url: URL) -> AriaSignInLink? {
        api.auth.signInLink(from: url)
    }

    /// Un utente della web non è un utente mobile: niente account mobile, niente lavori.
    func completeSignIn(with link: AriaSignInLink) async throws {
        let email = pendingLinkEmail
        var account = try await api.auth.completeSignIn(with: link)
        setPendingLink(nil)
        setMobileAccount(nil)
        // Nome ed email per l'app; se la web non risponde basta l'email a cui è arrivato il link.
        if account == nil { account = await api.auth.fetchWebAccount() }
        setWebAccount(account ?? email.map { AriaWebAccount(id: $0, name: "", email: $0) })
        isSignedIn = true
        await bootstrap()
    }

    // MARK: Face ID

    /// Va aperta con Face ID prima di usarla: una sessione di 7 giorni salvata, su un telefono con un codice.
    var needsUnlock: Bool {
        isSignedIn && api.auth.hasStoredLogin && AriaBiometrics.isAvailable
    }

    /// Face ID, poi la sessione salvata in memoria. Se nel frattempo è sparita dal Keychain si torna al login.
    /// Annullare lancia l'errore di LocalAuthentication (vedi `AriaBiometrics.isCancellation`).
    func unlock(reason: String) async throws {
        guard try await api.auth.unlock(reason: reason) else {
            handle(AriaError.signedOut)
            return
        }
    }

    /// Solo sviluppo: token copiato dall'host di accesso (GET /api/aria/token).
    func useDeveloperToken(_ token: String) async throws {
        try await api.auth.useDeveloperToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
        setMobileAccount(nil)
        setWebAccount(nil)
        isSignedIn = true
        await bootstrap()
    }

    func signOut() async {
        await api.auth.signOut()
        await api.context.setCompany(nil)
        await api.context.setPlant(nil)
        isSignedIn = false
        didBootstrap = false
        setMobileAccount(nil)
        setWebAccount(nil)
        companies = []
        plants = []
        activeCompanyId = nil
        activePlantId = nil
        lastError = nil
    }

    /// Cambia server (DEBUG). Da scollegati: i token di un server non valgono sull'altro.
    /// L'host di accesso è un tunnel che cambia indirizzo: qui si aggiorna senza ricompilare.
    func setServers(api apiURL: URL?, auth authURL: URL?) {
        guard !isSignedIn else { return }
        AriaConfig.saveServers(api: apiURL, auth: authURL)
        api = Self.makeClient(.current)
    }

    // MARK: Azienda / stabilimento

    func bootstrapIfNeeded() async {
        guard isSignedIn, !didBootstrap, !isLoading else { return }
        await bootstrap()
    }

    /// Passo 3: GET /v1/companies dà l'azienda, il cui `id` è il Company-Id di tutte le altre
    /// chiamate. Un utente mobile ne ha esattamente una (`myRole` "member"); se ce ne fossero
    /// più di una si tiene quella salvata, altrimenti la prima di cui è owner, altrimenti la prima.
    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Un utente mobile le chiede al tunnel, che è l'host dei suoi lavori.
            companies = try await api.get("v1/companies", companyScoped: false,
                                          host: api.auth.isMobileSession ? .mobile : .data)
            // Utente mobile senza aziende: la membership non è più attiva, è come essere scollegati.
            if companies.isEmpty, api.auth.isMobileSession {
                await api.auth.discardSession()
                throw AriaError.signedOut
            }
            let pick = companies.first { $0.id == activeCompanyId }
                ?? companies.first { $0.myRole == "owner" }
                ?? companies.first
            try await loadPlants(for: pick?.id)
            didBootstrap = true
            lastError = nil
            AriaAuthTrace.step("bootstrap.ok", "aziende=\(companies.count) stabilimenti=\(plants.count)")
        } catch {
            AriaAuthTrace.failure("bootstrap.failed", error)
            handle(error)
        }
    }

    func selectCompany(_ id: String?) async {
        do { try await loadPlants(for: id) } catch { handle(error) }
    }

    func selectPlant(_ id: String?) async {
        await api.context.setPlant(id)
        activePlantId = id
    }

    private func loadPlants(for companyId: String?) async throws {
        await api.context.setCompany(companyId)
        activeCompanyId = companyId
        if companyId == nil {
            plants = []
        } else {
            do {
                plants = try await api.get("v1/plants")
            } catch AriaError.http where api.auth.isMobileSession {
                // Il tunnel non serve gli stabilimenti: i lavori non ne hanno bisogno, la chat sì.
                plants = []
            }
        }
        await selectPlant(plants.first { $0.id == activePlantId }?.id ?? plants.first?.id)
    }

    // MARK: Chat

    /// Suggerimenti iniziali della chat per lo stabilimento attivo (vuoto se non disponibili).
    func suggestions() async -> [String] {
        guard let plantId = activePlantId else { return [] }
        let response: AriaSuggestionsResponse? = try? await api.get("v1/chat/suggestions", query: [
            URLQueryItem(name: "plant_id", value: plantId),
            URLQueryItem(name: "locale", value: api.context.locale),
        ])
        return response?.suggestions ?? []
    }

    func handle(_ error: any Error) {
        // Sessione ancora chiusa da Face ID: la schermata di sblocco è già davanti, niente da mostrare.
        if case .locked? = error as? AriaError { return }
        if case .signedOut? = error as? AriaError {
            isSignedIn = false
            didBootstrap = false
            setMobileAccount(nil)
            setWebAccount(nil)
        }
        lastError = error.localizedDescription
    }
}
