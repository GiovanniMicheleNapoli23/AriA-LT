//
//  AriaBackend.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Stato della connessione al backend Aria: login, azienda e stabilimento attivi.
//  La chat e i lavori usano il backend solo quando `isReady`.
//  Si entra con un link via email, senza password (AriaAuth): l'app chiede insieme il link
//  dell'operatore e il magic link della web, e completa l'accesso con quello che arriva.
//  Poi l'azienda arriva da GET /v1/companies.
//
import Foundation
import Observation

/// Esito dell'invio dei link di accesso: almeno uno è partito.
nonisolated struct AriaLinkDelivery: Sendable, Equatable {
    /// Link dell'operatore accettato (202 anche per un indirizzo che non è di un operatore).
    let mobileSent: Bool
    /// Magic link della web accettato.
    let webSent: Bool
    /// L'altro link non è partito per un motivo che l'utente può risolvere (captcha non pronto, troppi
    /// tentativi): una nota sotto "controlla l'email", non un errore.
    let note: String?
}

/// Il link di accesso non corrisponde alla richiesta fatta da questo dispositivo.
nonisolated enum AriaSignInError: LocalizedError, Sendable {
    /// Nessun link chiesto da qui (negli ultimi 15'): un link altrui aprirebbe l'account di chi lo manda.
    case noPendingRequest
    /// Il link è di un account diverso da quello a cui è stato chiesto.
    case accountMismatch

    var errorDescription: String? {
        switch self {
        case .noPendingRequest:
            String(localized: "Request a sign-in link from this device first, then open the link from that email.")
        case .accountMismatch:
            String(localized: "This link belongs to a different account than the one you requested. Request a new link.")
        }
    }
}

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
    /// L'operatore collegato; `nil` da scollegati.
    private(set) var mobileAccount: AriaMobileAccount?
    /// `membership` di GET /v1/me per l'azienda attiva: `restricted == false` è un owner o un admin con i diritti
    /// pieni, `true` la sessione dell'app di un membro. `nil`: non ancora letta, o un backend senza il campo.
    private(set) var membership: AriaMeMembership?
    /// `access` di GET /v1/me per l'azienda attiva: ruolo, sezioni e azioni. `nil`: non ancora letto, o un backend
    /// precedente ai ruoli (vale tutto come prima).
    private(set) var access: AriaAccess?
    /// Email a cui è stato mandato il link di accesso, finché il link è valido (15').
    /// Sta qui e non nello sheet: l'utente chiude lo sheet per andare a copiare il link.
    private(set) var pendingLinkEmail: String?

    /// Funzioni a cui il backend ha risposto 403 `operation_forbidden` (release senza la rotta per l'operatore):
    /// si nascondono fino al prossimo avvio, senza riprovare, o finché la sessione non comincia a seguire il ruolo.
    private(set) var unavailableFeatures: Set<AriaServerFeature> = []
    /// Capacità della dettatura e vocabolario dell'azienda: si chiedono una volta per sessione.
    @ObservationIgnored private var dictationSupport: Task<AriaDictationSupport, Never>?

    @ObservationIgnored private var didBootstrap = false
    /// Rilegge i diritti quando il client li segnala vecchi (AriaContext.observe).
    @ObservationIgnored private var accessListener: Task<Void, Never>?

    init() {
        let api = Self.makeClient(.current)
        self.api = api
        activeCompanyId = UserDefaults.standard.string(forKey: "aria.company_id")
        activePlantId = UserDefaults.standard.string(forKey: "aria.plant_id")
        Self.forgetKeychainIfReinstalled(api.auth)
        Self.moveMobileAccountToKeychain()
        let saved = AriaKeychain.get(Self.mobileAccountKey)
            .flatMap { try? JSONDecoder().decode(AriaMobileAccount.self, from: Data($0.utf8)) }
        // Una sessione (dell'operatore o della web) senza il suo profilo è di una versione precedente
        // o di un accesso non completato: non vale, si rifà l'accesso col link.
        // Il Keychain si interroga una volta: dopo `forgetStoredSession` il login salvato non c'è più.
        var hasStoredLogin = api.auth.hasStoredLogin
        if hasStoredLogin, saved == nil {
            api.auth.forgetStoredSession()
            hasStoredLogin = false
        }
        isSignedIn = api.auth.hasStoredSession(knowingLogin: hasStoredLogin)
        mobileAccount = isSignedIn ? saved : nil
        if let sentAt = UserDefaults.standard.object(forKey: Self.linkSentAtKey) as? Date,
           sentAt.timeIntervalSinceNow > -Self.linkLifetime {
            pendingLinkEmail = UserDefaults.standard.string(forKey: Self.linkEmailKey)
        }
        listenForAccessChanges()
    }

    private static let linkEmailKey = "aria.magic_link_email"
    private static let linkSentAtKey = "aria.magic_link_sent_at"
    private static let linkLifetime: TimeInterval = 15 * 60

    /// Chiave nuova: il profilo salvato dalle versioni con l'username ha un'altra forma.
    /// Sta nel Keychain (nome ed email non vanno nei backup), senza Face ID: serve all'avvio.
    private static let mobileAccountKey = "aria.operator_account"

    private static let installMarkerKey = "aria.install_marker"

    /// Il Keychain sopravvive alla disinstallazione, UserDefaults no: senza il marcatore è una prima
    /// installazione o una reinstallazione, e le credenziali rimaste non sono di chi usa il telefono ora.
    /// Un profilo ancora in UserDefaults è invece un aggiornamento: la sessione resta.
    private static func forgetKeychainIfReinstalled(_ auth: AriaAuth) {
        guard !UserDefaults.standard.bool(forKey: installMarkerKey) else { return }
        if UserDefaults.standard.data(forKey: mobileAccountKey) == nil {
            auth.forgetStoredSession()
            auth.forgetDeveloperToken()
            AriaKeychain.delete(mobileAccountKey)
        }
        UserDefaults.standard.set(true, forKey: installMarkerKey)
    }

    /// Le versioni precedenti tenevano il profilo in UserDefaults: lo si sposta nel Keychain.
    private static func moveMobileAccountToKeychain() {
        guard let data = UserDefaults.standard.data(forKey: mobileAccountKey) else { return }
        AriaKeychain.set(String(decoding: data, as: UTF8.self), for: mobileAccountKey)
        UserDefaults.standard.removeObject(forKey: mobileAccountKey)
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// La chat può parlare col backend: serve una sessione e uno stabilimento (`plant_id` è obbligatorio).
    var isReady: Bool { isSignedIn && activePlantId != nil }

    /// Operatore (task e calendario) o account della piattaforma (le sezioni della web).
    var accountKind: AriaAccountKind { mobileAccount?.kind ?? .operator }
    var isAdmin: Bool { accountKind == .admin }

    /// Il layout dell'operatore (Task, Calendario, Chat): un operatore, o la sessione dell'app di un membro
    /// (`membership.restricted`, vero per ogni membro anche quando la sessione segue il ruolo).
    var usesOperatorLayout: Bool { accountKind == .operator || membership?.restricted == true }

    /// Cosa può fare nell'azienda attiva: senza blocco `access`, in un'azienda "legacy" e per owner e admin, tutto.
    var rights: AriaRights { AriaRights(access: access) }

    /// Chi ha fatto l'accesso, secondo il backend (GET /v1/me, aperta a tutti gli account).
    func me() async throws -> AriaMe {
        try await api.get("v1/me", companyScoped: false)
    }

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

    // MARK: Login con il link

    private func setMobileAccount(_ account: AriaMobileAccount?) {
        mobileAccount = account
        if let json = account.flatMap({ try? JSONEncoder().encode($0) }) {
            AriaKeychain.set(String(decoding: json, as: UTF8.self), for: Self.mobileAccountKey)
        } else {
            AriaKeychain.delete(Self.mobileAccountKey)
        }
    }

    /// Passo 1: manda insieme il link dell'operatore e, con un captcha Turnstile, il magic link della web.
    /// Solo quello del tipo di account giusto spedisce un'email (request-link risponde 202 a ogni indirizzo).
    /// Basta che uno parta; se non parte nessuno vale l'errore dell'operatore (i suoi messaggi su rete
    /// e 429 sono i più chiari). Senza `captcha` parte solo il link dell'operatore.
    @discardableResult
    func sendSignInLink(email: String, captcha: String? = nil) async throws -> AriaLinkDelivery {
        let email = Self.normalized(email)
        let auth = api.auth
        async let mobileFailure = Self.failure { try await auth.requestLink(email: email) }
        async let webFailure = Self.failure {
            guard let captcha else { throw AriaError.captchaRejected }
            try await auth.requestWebLink(email: email, captcha: captcha)
        }
        let (mobile, web) = await (mobileFailure, webFailure)
        if let mobile, web != nil { throw mobile }

        setPendingLink(email)
        let delivery = AriaLinkDelivery(mobileSent: mobile == nil, webSent: web == nil,
                                        note: mobile.map(\.localizedDescription) ?? web.flatMap(Self.webNote))
        AriaAuthTrace.step("link.sent", "operatore=\(delivery.mobileSent) web=\(delivery.webSent)")
        return delivery
    }

    /// L'errore di un invio, o `nil` se è andato.
    private nonisolated static func failure(_ send: @Sendable () async throws -> Void) async -> (any Error)? {
        do {
            try await send()
            return nil
        } catch {
            return error
        }
    }

    /// Il magic link della web non è partito: lo si dice solo se l'utente può farci qualcosa.
    /// Altri rifiuti (es. un indirizzo senza account della web) non dicono nulla a un operatore.
    private static func webNote(_ error: any Error) -> String? {
        switch error as? AriaError {
        case .captchaRejected?, .tooManyAttempts?: error.localizedDescription
        default: nil
        }
    }

    /// Torna al passo dell'email (per chiedere un nuovo link).
    func cancelPendingLink() {
        setPendingLink(nil)
    }

    private func setPendingLink(_ email: String?) {
        pendingLinkEmail = email
        UserDefaults.standard.set(email, forKey: Self.linkEmailKey)
        UserDefaults.standard.set(email == nil ? nil : Date.now, forKey: Self.linkSentAtKey)
    }

    /// Il link di accesso contenuto in un testo incollato, se c'è.
    func magicLink(in text: String) -> AriaSignInLink? {
        api.auth.magicLink(in: text)
    }

    /// Il link di accesso in un URL aperto dal sistema.
    func signInLink(from url: URL) -> AriaSignInLink? {
        api.auth.signInLink(from: url)
    }

    /// Passo 2: il link contro una sessione, poi l'azienda. Link dell'operatore: la verifica restituisce
    /// l'operatore. Magic link della web: chi è (e se è un operatore o un account della piattaforma)
    /// lo dice GET /v1/me.
    /// Il link vale solo per l'email a cui l'accesso è stato chiesto da questo dispositivo: senza
    /// questo vincolo un link con il token di un altro account (`aria://` lo apre chiunque) farebbe
    /// entrare l'utente nell'account di chi lo manda.
    func completeSignIn(with link: AriaSignInLink) async throws {
        // Nessuna richiesta da qui: si rifiuta senza chiamare il server, il token non si consuma.
        guard let requested = pendingLinkEmail else { throw AriaSignInError.noPendingRequest }
        let account: AriaMobileAccount
        switch link {
        case .mobile:
            account = try await api.auth.completeSignIn(with: link)
        case .web(let url):
            try await api.auth.completeWebSignIn(with: url)
            do {
                account = try await me().account
            } catch {
                // Sessione aperta ma account sconosciuto: non resta nel Keychain senza profilo.
                AriaAuthTrace.failure("webLink.me.failed", error)
                await api.auth.discardSession()
                throw error
            }
        }
        guard Self.normalized(account.email) == Self.normalized(requested) else {
            // Account diverso: la sessione appena aperta si chiude sul server e la richiesta resta in attesa.
            await api.auth.signOut()
            throw AriaSignInError.accountMismatch
        }
        setPendingLink(nil)
        setMobileAccount(account)
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

    #if DEBUG
    /// Solo sviluppo: token copiato dall'host di accesso (GET /api/aria/token).
    func useDeveloperToken(_ token: String) async throws {
        try await api.auth.useDeveloperToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
        // Il token è di un account qualsiasi: chi è (operatore o admin) lo dice GET /v1/me.
        setMobileAccount(try await me().account)
        isSignedIn = true
        await bootstrap()
    }

    /// Solo UI test: parte da zero, senza la sessione che un test precedente ha lasciato nel Keychain
    /// (che all'avvio chiederebbe Face ID).
    func discardSavedSessionForUITests() {
        api.auth.forgetStoredSession()
        api.auth.forgetDeveloperToken()
        setMobileAccount(nil)
        isSignedIn = false
    }

    /// Solo UI test: entra come operatore con una sessione già emessa; il profilo è `operatorProfile` di GET /v1/me.
    func useSessionToken(_ token: String) async throws {
        try await api.auth.useSessionToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
        let account = try await me().account
        guard account.kind == .operator else { throw AriaError.signedOut }
        setMobileAccount(account)
        isSignedIn = true
        await bootstrap()
    }
    #endif

    func signOut() async {
        await api.auth.signOut()
        await api.context.setCompany(nil)
        await api.context.setPlant(nil)
        isSignedIn = false
        didBootstrap = false
        setMobileAccount(nil)
        membership = nil
        access = nil
        await api.context.setAccess(version: nil, followsRole: false)
        companies = []
        plants = []
        activeCompanyId = nil
        activePlantId = nil
        lastError = nil
        unavailableFeatures = []
        dictationSupport = nil
    }

    // MARK: Funzioni che il server può non avere ancora

    func isAvailable(_ feature: AriaServerFeature) -> Bool { !unavailableFeatures.contains(feature) }

    /// Da chiamare con l'errore di una funzione: se è `operation_forbidden` la funzione sparisce.
    /// Restituisce `true` in quel caso, così chi chiama non mostra un errore.
    @discardableResult
    func markUnavailable(_ feature: AriaServerFeature, ifRefused error: any Error) -> Bool {
        guard case .notOnPhone? = error as? AriaError else { return false }
        unavailableFeatures.insert(feature)
        return true
    }

    /// Cambia server (DEBUG). Da scollegati: i token di un server non valgono sull'altro.
    /// Il link dell'email porta l'host di accesso: va riconosciuto con quello in uso.
    #if DEBUG
    func setServers(api apiURL: URL?, auth authURL: URL?) {
        guard !isSignedIn else { return }
        AriaConfig.saveServers(api: apiURL, auth: authURL)
        api = Self.makeClient(.current)
        listenForAccessChanges()
    }
    #endif

    // MARK: Azienda / stabilimento

    func bootstrapIfNeeded() async {
        guard isSignedIn, !didBootstrap, !isLoading else { return }
        await bootstrap()
    }

    /// GET /v1/companies dà l'azienda, il cui `id` è il Company-Id di tutte le altre
    /// chiamate. Un operatore ne ha esattamente una (`myRole` "member"); se ce ne fossero
    /// più di una si tiene quella salvata, altrimenti la prima di cui è owner, altrimenti la prima.
    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let listed: [AriaCompany] = try await api.get("v1/companies", companyScoped: false)
            // Solo quelle aperte all'app; un backend senza `appAccess` le lascia tutte.
            companies = listed.filter { $0.appAccess != false }
            // Operatore senza aziende: la membership non è più attiva, è come essere scollegati.
            if companies.isEmpty, api.auth.isMobileSession {
                await api.auth.discardSession()
                throw AriaError.signedOut
            }
            let pick = companies.first { $0.id == activeCompanyId }
                ?? companies.first { $0.myRole == "owner" }
                ?? companies.first
            try await loadPlants(for: pick?.id)
            await refreshMembership()
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
        await refreshMembership()
    }

    /// 403 `operation_forbidden`: l'accesso a quest'azienda è cambiato (guida "one account", §11). Si rileggono
    /// le aziende, quella persa sparisce e se ne sceglie un'altra, poi `membership`; un operatore senza aziende
    /// esce come in `bootstrap`.
    func reloadCompanies() async {
        guard isSignedIn, !isLoading else { return }
        await bootstrap()
    }

    /// Rilegge `membership` e `access` per l'azienda attiva (all'avvio, al cambio di azienda, al ritorno in primo
    /// piano e quando il client segnala diritti vecchi): chi ha perso un diritto lo vede subito, senza rifare
    /// l'accesso. Senza rete restano gli ultimi letti; un rifiuto li toglie.
    func refreshMembership() async {
        guard isSignedIn, let companyId = activeCompanyId else {
            membership = nil
            access = nil
            await api.context.setAccess(version: nil, followsRole: false)
            return
        }
        do {
            let me: AriaMe = try await api.get("v1/me")
            guard companyId == activeCompanyId else { return }
            let followed = rights.followsRole
            let changed = me.access != access || me.membership != membership
            membership = me.membership
            access = me.access
            if changed { traceRights() }
            // La sessione ha cominciato (o smesso) a seguire il ruolo: le funzioni nascoste per un
            // `operation_forbidden` dell'operatore si riprovano con i limiti nuovi.
            if rights.followsRole != followed { unavailableFeatures = [] }
            await api.context.setAccess(version: me.access?.version, followsRole: rights.followsRole)
        } catch {
            guard companyId == activeCompanyId, !(error is CancellationError), !AriaHTTP.isOffline(error) else { return }
            AriaAuthTrace.failure("me.membership.failed", error)
            membership = nil
            access = nil
            // Il client non si riarma: la stessa versione nuova non fa ripartire una lettura che fallisce.
        }
    }

    /// Solo DEBUG: sezioni, switch e pulsanti nella console (categoria "rights").
    private func traceRights() {
        #if DEBUG
        let sidebar = AriaSidebarSections.groups(operatorLayout: usesOperatorLayout, rights: rights)
            .flatMap { $0.items.map { String(localized: $0.title) } }
        AriaRightsTrace.dump(rights, operatorLayout: usesOperatorLayout, sidebar: sidebar)
        #endif
    }

    /// Un segnale da fuori del client (l'ultimo evento `permission_denied` di uno stream, un errore della chat che
    /// comincia con `permission_denied:`): i diritti si rileggono come dopo un 403.
    func accessMayHaveChanged() {
        api.context.accessMayHaveChanged()
    }

    /// Ogni quanto si rileggono i diritti con l'app aperta: 30", come la web e il contratto Roles & Rights del 10/11.
    nonisolated static let accessWatchInterval: Duration = .seconds(30)

    /// Rilegge i diritti a intervalli finché il task che la chiama non finisce (AriaShellView, solo con l'app attiva).
    /// L'header `X-Access-Version` e i 403 arrivano solo con una chiamata: su una schermata ferma un diritto tolto
    /// o ridato dall'admin non si vedrebbe fino al ritorno in primo piano.
    func watchAccess(every interval: Duration = AriaBackend.accessWatchInterval) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            await refreshMembership()
        }
    }

    private func listenForAccessChanges() {
        accessListener?.cancel()
        let signals = api.context.accessSignals
        accessListener = Task { [weak self] in
            for await _ in signals {
                guard let self else { return }
                await self.refreshMembership()
            }
        }
    }

    func selectPlant(_ id: String?) async {
        await api.context.setPlant(id)
        activePlantId = id
    }

    /// Dopo una modifica agli stabilimenti (sezione Plants): l'elenco condiviso si richiede al server.
    func reloadPlants() async throws {
        try await loadPlants(for: activeCompanyId)
    }

    private func loadPlants(for companyId: String?) async throws {
        // Il vocabolario della dettatura è dell'azienda: con un'altra si richiede.
        if companyId != activeCompanyId {
            dictationSupport = nil
            membership = nil
            access = nil
            await api.context.setAccess(version: nil, followsRole: false)
        }
        await api.context.setCompany(companyId)
        activeCompanyId = companyId
        if companyId == nil {
            plants = []
        } else {
            do {
                plants = try await api.get("v1/plants")
            } catch AriaError.http where api.auth.isMobileSession {
                // Elenco non disponibile: i lavori non hanno bisogno dello stabilimento, la chat sì.
                plants = []
            }
        }
        await selectPlant(plants.first { $0.id == activePlantId }?.id ?? plants.first?.id)
    }

    // MARK: Chat

    /// I chip di una chat vuota (GET /v1/chat/suggestions, nella lingua dell'app). Vuoto da scollegati, se il
    /// server non ne ha o non risponde: i chip semplicemente non ci sono. Un 403 `operation_forbidden` li
    /// nasconde per il resto della sessione.
    func suggestions() async -> [String] {
        guard isSignedIn, isAvailable(.suggestions) else { return [] }
        do {
            return try await AriaChatAPI(api: api).suggestions()
        } catch {
            markUnavailable(.suggestions, ifRefused: error)
            return []
        }
    }

    /// Dettatura sul server e vocabolario dell'azienda, chiesti una volta (all'apertura del composer).
    /// Senza risposta vale `.unavailable`: resta il riconoscimento sul telefono, e si richiede la volta dopo.
    func dictation() async -> AriaDictationSupport {
        if let dictationSupport { return await dictationSupport.value }
        let audio = AriaAudioAPI(api: api)
        let task = Task<AriaDictationSupport, Never> {
            async let capabilities = audio.capabilities()
            async let vocabulary = audio.vocabulary()
            // Il vocabolario aiuta il riconoscitore sul telefono anche senza la dettatura sul server.
            let terms = (try? await vocabulary) ?? []
            guard let capabilities = try? await capabilities else {
                return AriaDictationSupport(capabilities: .unavailable, vocabulary: terms, fetched: false)
            }
            return AriaDictationSupport(capabilities: capabilities, vocabulary: terms)
        }
        dictationSupport = task
        let support = await task.value
        // Solo una risposta mancata si richiede la volta dopo; "dettatura spenta" detto dal server vale.
        if !support.fetched, dictationSupport == task { dictationSupport = nil }
        return support
    }

    func handle(_ error: any Error) {
        // Sessione ancora chiusa da Face ID: la schermata di sblocco è già davanti, niente da mostrare.
        if case .locked? = error as? AriaError { return }
        if case .signedOut? = error as? AriaError {
            isSignedIn = false
            didBootstrap = false
            setMobileAccount(nil)
        }
        lastError = error.localizedDescription
    }
}

/// Le funzioni della guida "operator member parity" (20/10/2026): su un backend precedente rispondono
/// 403 `operation_forbidden` e si nascondono.
nonisolated enum AriaServerFeature: Hashable, Sendable {
    case suggestions
    case contextMeter
    case dictation
    case memoryConfirm
    case factTranslation
    case closeout
    case report
}

/// Cosa sa fare la dettatura su questo server.
nonisolated struct AriaDictationSupport: Sendable, Equatable {
    let capabilities: AriaDictationCapabilities
    /// Codici e termini dell'azienda per il riconoscitore sul telefono.
    let vocabulary: [String]
    /// `false` se le capacità non sono arrivate (rete, backend senza la rotta): si richiedono la volta dopo.
    var fetched = true

    static let none = AriaDictationSupport(capabilities: .unavailable, vocabulary: [], fetched: false)

    var transcribes: Bool { capabilities.available }
    var polishes: Bool { capabilities.polish == true }
    /// La registrazione più grande che si manda (in byte); oltre resta il testo del telefono.
    var maxAudioBytes: Int? { capabilities.maxAudioMb.map { Int($0 * 1_000_000) } }
}
