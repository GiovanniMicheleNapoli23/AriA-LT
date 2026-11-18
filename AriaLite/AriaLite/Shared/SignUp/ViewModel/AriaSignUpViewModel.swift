//
//  AriaSignUpViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Tutta la logica dell'iscrizione dopo il link (contratto "Onboarding in the app"; handover 18/11/26 §1). L'account
//  esiste già (lo crea il link); profilo, azienda, stabilimento e piano si compilano in bozza, passo per passo, con
//  "Indietro" sempre disponibile, e **si scrivono tutti alla fine**, con l'ultimo pulsante (`finish`), come il pulsante
//  unico della web (§1.4): PATCH /v1/me → rilettura dello stato → POST /v1/companies se manca → POST /v1/plants se
//  manca → POST /api/auth/onboarding/finish. Un errore riporta al passo che l'ha causato, con il messaggio lì; riprovando
//  non si rifà nulla di quello che è già riuscito. Quello che il server ha già (azienda, stabilimento) si mostra in sola
//  lettura: è l'unica cosa che "Indietro" non può cambiare.
//  • Chi si è (§1.2) lo dicono GET /v1/onboarding/status e GET /v1/me (`onboardingCompany`): owner o admin
//    dell'azienda in onboarding fanno tutti i passi; chi è entrato nell'azienda di un altro compila solo il profilo.
//  • Ogni controllo che non scrive (campi obbligatori, slug, sito web verificato) si fa uscendo dal passo, non alla fine:
//    la scrittura finale fallisce solo per ragioni del server.
//  • La bozza vive in memoria (il modello lo tiene AppViewModel): chiudere l'app a metà vuol dire ricominciare, con i
//    campi del profilo ripresi dal server.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaSignUpViewModel {
    let app: AppViewModel
    @ObservationIgnored private let slugDelay: Duration
    @ObservationIgnored private let slugTimeout: Duration

    /// Il passo da mostrare; `nil` finché lo stato non è letto.
    private(set) var step: AriaSignUpStep?
    private(set) var isLoading = false
    /// Una chiamata di un passo in corso: il pulsante resta disattivato (due fine insieme manderebbero due email).
    private(set) var isSaving = false
    /// Messaggio sotto il modulo. Lo scrivono solo questa classe e le sue estensioni (+Website).
    var errorMessage: String?
    /// Il server non si raggiunge: l'avviso "offline" al posto dell'errore.
    private(set) var isOffline = false
    /// Da qui non si può creare l'azienda (es. un membro sospeso): l'avviso, poi si esce.
    private(set) var blockingMessage: String?
    /// Membro entrato nell'azienda di un altro: solo il profilo, poi l'app (pulsante "Continua", niente passi).
    private(set) var memberOnly = false
    /// L'azienda l'ha creata questa schermata: chi l'ha creata non è mai "solo membro", qualunque cosa dica /v1/me.
    @ObservationIgnored private var createdCompanyHere = false
    /// L'azienda c'è già sul server (creata alla fine di un giro precedente, o di cui si è admin): sola lettura.
    private(set) var companyOnServer = false
    /// Nome e indirizzo dell'azienda già creata, per la sua scheda in sola lettura.
    private(set) var savedCompany: (name: String, slug: String)?
    /// L'azienda ha già uno stabilimento (o non si può crearlo per i diritti): il passo è in sola lettura.
    private(set) var plantOnServer = false
    /// Il nome dello stabilimento già creato, per la sua scheda.
    private(set) var savedPlantName: String?
    /// Lo stabilimento rifiutato per i diritti: non si chiede più, l'avviso della chat offrirà di aggiungerlo.
    private(set) var plantForbidden = false
    /// I campi del profilo si riempiono da /v1/me una volta sola: dopo vale quello che si scrive.
    @ObservationIgnored private var profilePrefilled = false

    // MARK: Profilo
    var name: String
    var jobRole: AriaJobRole?
    /// Il ruolo scritto sotto "Altro".
    var otherJobRole = ""
    var phone = ""

    // MARK: Azienda
    private var companyNameText = ""
    private var slugText = ""
    /// Lo slug toccato a mano non segue più il nome.
    private var slugEdited = false
    var industry: AriaCompanyIndustry?
    /// Il settore scritto sotto "Altro".
    var otherIndustry = ""
    var size: AriaCompanySize?
    private(set) var slugState: AriaSlugState = .idle
    @ObservationIgnored private var slugCheck: Task<Void, Never>?

    // MARK: Sito web (AriaSignUpViewModel+Website)
    /// Il sito come si vede nel campo; un "https://" incollato si toglie. Non si manda al backend: serve a
    /// dimostrare che l'azienda esiste, come sulla web.
    var website = "" {
        didSet { websiteEdited(from: oldValue) }
    }
    /// L'esito del controllo; lo scrive solo AriaSignUpViewModel+Website.
    var websiteStatus: AriaWebsiteStatus = .idle
    @ObservationIgnored var websiteCheck: Task<Void, Never>?
    @ObservationIgnored let websiteResolver: any AriaDomainResolving
    @ObservationIgnored let websiteDelay: Duration
    @ObservationIgnored let isOnline: () -> Bool
    @ObservationIgnored var websitePrefilled = false

    // MARK: Stabilimento
    var plantName = ""
    var plantCode = ""
    var plantLocation = ""
    /// L'azienda creata qui, o ritrovata riaprendo l'app: il Company-Id delle rotte degli stabilimenti.
    @ObservationIgnored private var companyId: String?

    /// `resolver` e `isOnline`: il DNS del telefono e lo stato della rete; i test li sostituiscono.
    init(app: AppViewModel, slugDelay: Duration = .milliseconds(400), slugTimeout: Duration = .seconds(8),
         websiteDelay: Duration = .milliseconds(500), resolver: (any AriaDomainResolving)? = nil,
         isOnline: (() -> Bool)? = nil) {
        self.app = app
        self.slugDelay = slugDelay
        self.slugTimeout = slugTimeout
        self.websiteDelay = websiteDelay
        // Il controllo usa l'host dell'API: se non risolve nemmeno quello, il DNS non risponde (non "dominio inesistente").
        websiteResolver = resolver ?? AriaSystemDomainResolver(controlHost: app.backend.serverURL.host() ?? "api.ariaplt.com")
        self.isOnline = isOnline ?? { AriaNetworkMonitor.shared.isOnline }
        name = app.backend.mobileAccount?.name ?? ""
    }

    private var api: AriaSignUpAPI { AriaSignUpAPI(api: app.backend.api) }

    // MARK: Stato

    /// L'email con cui ci si è iscritti, per ricordare con che account si sta creando l'azienda.
    var email: String { app.backend.mobileAccount?.email ?? "" }

    /// I passi di questa persona: il membro solo il profilo.
    var steps: [AriaSignUpStep] { memberOnly ? [.profile] : AriaSignUpStep.allCases }

    var stepCount: Int { steps.count }

    var stepIndex: Int { step.flatMap { steps.firstIndex(of: $0) } ?? 0 }

    /// "Indietro" c'è da ogni passo dopo il primo, tranne mentre si scrive.
    var canGoBack: Bool { stepIndex > 0 && !isSaving }

    /// L'ultimo passo: il suo pulsante scrive tutto.
    var isLastStep: Bool { step == steps.last }

    var progressLabel: String {
        String(localized: "Step \(stepIndex + 1) of \(stepCount)")
    }

    /// Lo stato non si è letto: al posto del modulo, l'errore e "Riprova".
    var needsRetry: Bool { step == nil && !isLoading && (errorMessage != nil || isOffline) }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedCompanyName: String { companyName.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Il ruolo che si manda: quello della lista, o il testo scritto sotto "Altro".
    var jobRoleValue: String {
        AriaOtherChoice.value(jobRole?.rawValue, isOther: jobRole == .other, otherText: otherJobRole)
    }

    /// Il settore che si manda: quello della lista, o il testo scritto sotto "Altro".
    var industryValue: String {
        AriaOtherChoice.value(industry?.rawValue, isOther: industry == .other, otherText: otherIndustry)
    }

    /// Lo slug va bene libero, o quando il controllo non ha risposto: la creazione lo ricontrolla (come la web).
    private var slugAccepted: Bool {
        normalizedSlug.count >= AriaSlug.minCheckLength && (slugState == .available || slugState == .failed)
    }

    var canSaveProfile: Bool { profileMissing.isEmpty && !isSaving }

    var canCreateCompany: Bool { (companyOnServer || companyMissing.isEmpty) && !isSaving }

    // MARK: Manca ancora

    private var profileMissing: [String] {
        var missing: [String] = []
        if trimmedName.isEmpty { missing.append(String(localized: "your name")) }
        if jobRoleValue.isEmpty { missing.append(String(localized: "your role")) }
        return missing
    }

    private var companyMissing: [String] {
        var missing: [String] = []
        if trimmedCompanyName.isEmpty { missing.append(String(localized: "the company name")) }
        if !websiteAccepted { missing.append(String(localized: "the company website")) }
        if !slugAccepted { missing.append(String(localized: "a free workspace address")) }
        if industryValue.isEmpty { missing.append(String(localized: "the industry")) }
        return missing
    }

    private var plantMissing: [String] {
        var missing: [String] = []
        if trimmed(plantName).isEmpty { missing.append(String(localized: "the site name")) }
        if trimmed(plantCode).isEmpty { missing.append(String(localized: "the site code")) }
        return missing
    }

    /// "Manca ancora: …" sotto il pulsante del passo, come sotto quello della web. `nil` quando non manca niente.
    var stillNeeded: String? {
        let missing: [String] = switch step {
        case .profile: profileMissing
        case .company: companyOnServer ? [] : companyMissing
        case .plant: plantOnServer ? [] : plantMissing
        case .plan, nil: []
        }
        guard !missing.isEmpty else { return nil }
        return String(localized: "Still needed: \(missing.joined(separator: ", ")).")
    }

    var canCreatePlant: Bool { (plantOnServer || plantMissing.isEmpty) && !isSaving }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canFinish: Bool { !isSaving }

    /// Il nome dell'azienda; finché lo slug non è stato toccato, lo slug lo segue.
    var companyName: String {
        get { companyNameText }
        set {
            companyNameText = newValue
            guard !slugEdited else { return }
            setSlug(AriaSlug.normalize(newValue))
        }
    }

    /// Lo slug come si vede nel campo: la regola della web si riapplica a ogni modifica.
    var slug: String {
        get { slugText }
        set {
            slugEdited = !newValue.isEmpty
            setSlug(AriaSlug.editing(newValue))
        }
    }

    /// Lo slug che si controlla e si manda.
    var normalizedSlug: String { AriaSlug.normalize(slugText) }

    // MARK: Caricamento

    /// Legge lo stato e mostra il primo passo che il server non ha; a onboarding finito apre l'app. Una seconda volta
    /// (la vista riappare) non tocca passo né campi.
    func load() async {
        guard step == nil, !isLoading else { return }
        isLoading = true
        clearMessages()
        defer { isLoading = false }
        do {
            let status = try await readServer()
            guard let first = AriaSignUpStep(status, hasPlant: plantOnServer, memberOnly: memberOnly) else {
                await complete()
                return
            }
            show(first)
        } catch {
            fail(error, readsAccount: true)
        }
    }

    /// Stato, chi si è e cosa il server ha già (azienda, stabilimento). `me`: la risposta di PATCH /v1/me appena
    /// arrivata (non si rilegge).
    @discardableResult
    private func readServer(me known: AriaMe? = nil) async throws -> AriaSignUpStatus {
        let status = try await api.status()
        guard !status.onboardingComplete else { return status }
        let me: AriaMe?
        if let known { me = known } else { me = try await readMe() }
        if let me { read(me, status: status) }
        // Creata qui vuol dire che c'è, anche se lo stato riletto è in ritardo: mai una seconda creazione.
        companyOnServer = (status.companyCreated && !memberOnly) || createdCompanyHere
        if companyOnServer, !memberOnly { try await readPlants() }
        return status
    }

    /// GET /v1/me. Senza risposta si prosegue come owner (come la web quando non legge lo stato): il server
    /// rifiuta comunque quello che non tocca, e il rifiuto si chiarisce rileggendo lo stato.
    private func readMe() async throws -> AriaMe? {
        do {
            return try await app.backend.me()
        } catch AriaError.signedOut {
            throw AriaError.signedOut
        } catch where error is CancellationError {
            throw error
        } catch {
            AriaAuthTrace.failure("signUp.me.failed", error)
            return nil
        }
    }

    /// Chi si è (§1.2) e, la prima volta, i campi del profilo con quello che il server ha già.
    private func read(_ me: AriaMe, status: AriaSignUpStatus) {
        let onboarding = me.onboardingCompany
        let runsCompany = onboarding?.runsCompany == true
        memberOnly = status.companyCreated && !runsCompany && !createdCompanyHere
        if runsCompany {
            if companyId == nil { companyId = onboarding?.id }
            if savedCompany == nil, let name = onboarding?.name {
                savedCompany = (name, onboarding?.slug ?? "")
            }
        }
        guard !profilePrefilled else { return }
        profilePrefilled = true
        if let saved = me.name?.trimmingCharacters(in: .whitespacesAndNewlines), !saved.isEmpty { name = saved }
        let role = AriaJobRole.choice(saved: me.jobRole)
        if role.role != nil {
            jobRole = role.role
            otherJobRole = role.otherText
        }
        if let saved = me.phone, !saved.isEmpty { phone = saved }
    }

    /// Gli stabilimenti dell'azienda già creata: se ce n'è uno, il passo è fatto. Un elenco rifiutato per i diritti
    /// non blocca (come prima): il passo si salta e l'avviso della chat offrirà di aggiungerlo.
    private func readPlants() async throws {
        guard !plantOnServer else { return }
        guard let companyId = try await ownCompanyId() else {
            // Nessuna azienda propria da cui crearlo: non si chiede, l'avviso della chat offrirà di aggiungerlo.
            plantOnServer = true
            plantForbidden = true
            return
        }
        do {
            let plants = try await api.plants(companyId: companyId)
            if let first = plants.first {
                plantOnServer = true
                savedPlantName = first.name
            }
        } catch AriaError.signedOut {
            throw AriaError.signedOut
        } catch where AriaHTTP.isOffline(error) || error is CancellationError {
            throw error
        } catch {
            AriaAuthTrace.failure("signUp.plants.failed", error)
            plantOnServer = true
            plantForbidden = true
        }
    }

    /// Onboarding finito: AriaBackend rilegge aziende, stabilimenti e diritti, e la shell prende il posto di questa
    /// schermata. Senza aziende (onboarding finito ma niente da usare) AriaBackend fa uscire, come prima.
    private func complete() async {
        await app.backend.bootstrap()
        if app.backend.isSigningUp {
            // Le aziende non si sono lette: si resta qui, con l'errore e "Riprova".
            errorMessage = app.backend.lastError ?? String(localized: "Something went wrong. Try again.")
        } else {
            app.signUpFinished()
        }
    }

    // MARK: Avanti e indietro

    private func show(_ next: AriaSignUpStep) {
        step = next
        if next == .company, !companyOnServer { prefillWebsite() }
    }

    /// Il pulsante del passo: controlla quello che si può controllare senza scrivere, poi il passo dopo. All'ultimo
    /// passo (il Piano; il Profilo per il membro) scrive tutto.
    func continueFromStep() async {
        guard let step, !isSaving else { return }
        clearMessages()
        if isLastStep {
            await finish()
            return
        }
        switch step {
        case .profile:
            guard canSaveProfile else { return }
        case .company:
            guard canCreateCompany else { return }
            if !companyOnServer {
                // Il sito si verifica qui, sul serio: alla fine si scrive e basta.
                isSaving = true
                let verified = await websiteVerifiedForSaving()
                isSaving = false
                guard verified else { return }
            }
        case .plant:
            guard canCreatePlant else { return }
        case .plan:
            return
        }
        if let index = steps.firstIndex(of: step), index + 1 < steps.count { show(steps[index + 1]) }
    }

    /// Un passo indietro: i campi restano come sono.
    func goBack() {
        guard canGoBack, let step, let index = steps.firstIndex(of: step) else { return }
        clearMessages()
        self.step = steps[index - 1]
    }

    // MARK: Azienda

    /// 403 `operator_identity_forbidden` (non si è più una nuova iscrizione), 409 o 500 (lo slug preso fra il
    /// controllo e la creazione): prima di dire qualcosa si guarda se l'azienda c'è già (risposta persa). `true`: c'è,
    /// si va avanti; `false`: si torna al passo Azienda con il perché.
    private func recoverRefusedCompany(status: Int, slug: String) async throws -> Bool {
        let current = try await readServer()
        if current.companyCreated { return true }
        step = .company
        if status == 403 {
            blockingMessage = String(localized: "You can't create a company from the app with this account. Create it on the AriaPLT website, then sign in again.")
            return false
        }
        let taken = status == 409 ? true : try await !api.checkSlug(slug).available
        if taken {
            if slug == normalizedSlug { slugState = .taken }
            errorMessage = String(localized: "This workspace address is already taken. Choose another one.")
        } else {
            errorMessage = String(localized: "Something went wrong. Try again.")
        }
        return false
    }

    /// Lo slug non si è potuto controllare: si richiede subito.
    func retrySlugCheck() {
        scheduleSlugCheck(after: .zero)
    }

    private func setSlug(_ value: String) {
        let before = normalizedSlug
        slugText = value
        guard normalizedSlug != before else { return }
        scheduleSlugCheck(after: slugDelay)
    }

    /// Si chiede al server solo da 2 caratteri, 400 ms dopo l'ultimo tasto; una risposta per uno slug ormai cambiato
    /// non conta.
    private func scheduleSlugCheck(after delay: Duration) {
        slugCheck?.cancel()
        let slug = normalizedSlug
        guard slug.count >= AriaSlug.minCheckLength else {
            slugState = .idle
            return
        }
        slugState = .checking
        let api = api
        let timeout = slugTimeout
        slugCheck = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            let result: AriaSlugState
            do {
                let available = try await Self.withTimeout(timeout) { try await api.checkSlug(slug).available }
                result = available ? .available : .taken
            } catch {
                result = .failed
            }
            guard !Task.isCancelled, let self, self.normalizedSlug == slug else { return }
            self.slugState = result
        }
    }

    // MARK: Stabilimento

    /// Quella creata al passo Azienda, o l'`onboardingCompany` di /v1/me; altrimenti, riaperta l'app, quella di cui si
    /// è owner o admin con l'onboarding a metà.
    private func ownCompanyId() async throws -> String? {
        if let companyId { return companyId }
        let companies = try await api.companies()
        let runs: (AriaCompany) -> Bool = { $0.myRole == "owner" || $0.myRole == "admin" }
        let own = companies.first { runs($0) && $0.onboardingCompleted == false }
            ?? companies.first { $0.myRole == "owner" }
        companyId = own?.id
        // Il nome per la scheda in sola lettura, se /v1/me non l'ha dato.
        if savedCompany == nil, let own { savedCompany = (own.name, "") }
        return companyId
    }

    // MARK: Piano

    /// Il listino pubblico per la card della demo: durata, limiti, altri piani. Senza (oggi in prod non è
    /// pubblicato, o non risponde) la card mostra solo le sue parole e il pulsante resta attivo.
    private(set) var priceList: AriaPriceListState = .loading

    /// Una volta per schermata, al massimo 10 s come la web: un listino lento non tiene ferma la card.
    func loadPriceList() async {
        guard priceList == .loading else { return }
        let api = api
        do {
            let list = try await Self.withTimeout(.seconds(10)) { try await api.priceList() }
            priceList = AriaPriceListState(list)
        } catch where Task.isCancelled {
            // La card è sparita prima della risposta: alla prossima apertura si richiede.
            return
        } catch {
            AriaAuthTrace.failure("signUp.priceList.failed", error)
            priceList = .failed
        }
    }

    // MARK: Scrittura finale

    private var profileUpdate: AriaProfileUpdate {
        let phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return AriaProfileUpdate(name: trimmedName, jobRole: jobRoleValue, phone: phone.isEmpty ? nil : phone,
                                 preferredLocale: AriaSignUpLocale.current)
    }

    /// L'ultimo pulsante: scrive tutto, in ordine, saltando quello che il server ha già (§1.4). Un errore riporta al
    /// passo che l'ha causato, con il messaggio lì; riprovando si riparte da quello che manca. Una alla volta: due
    /// chiamate finali insieme manderebbero due email di benvenuto.
    func finish() async {
        guard canFinish else { return }
        // Prima di scrivere, la bozza dev'essere completa: un passo saltato (si è ripartiti più avanti e /v1/me non ha
        // risposto) manderebbe un profilo vuoto sopra quello salvato. Si torna al primo passo incompleto.
        if let incomplete = firstIncompleteStep {
            show(incomplete)
            return
        }
        begin()
        defer { isSaving = false }
        var stage = AriaSignUpStep.profile
        do {
            // 1 · Il profilo (rifarlo non fa danni), poi lo stato riletto: dice cosa manca davvero.
            let me = try await api.updateProfile(profileUpdate)
            app.backend.profileSaved(me)
            let status = try await readServer(me: me)
            // Il membro di un'azienda altrui finisce qui, come sulla web.
            if status.onboardingComplete || (memberOnly && status.profileComplete) {
                await complete()
                return
            }
            // 2 · L'azienda, se il server non l'ha.
            stage = .company
            if !companyOnServer {
                guard try await createCompany() else { return }
                // Il rifiuto si è chiarito: si è membri dell'azienda di un altro, e per loro finisce qui.
                if memberOnly {
                    await complete()
                    return
                }
            }
            // 3 · Lo stabilimento, se l'azienda non ne ha.
            stage = .plant
            if !plantOnServer {
                guard try await createPlant() else { return }
            }
            // 4 · Il piano: prova gratuita, onboarding completo, email di benvenuto. `alreadyDone` vale come riuscito.
            stage = .plan
            _ = try await app.backend.api.auth.finishOnboarding(plan: AriaSignUpAPI.freeDemoPlan)
            await complete()
        } catch AriaSignUpError.noCompany {
            // L'azienda non c'è (creata e poi tolta, o mai arrivata): si torna al passo Azienda, come la web.
            companyId = nil
            createdCompanyHere = false
            companyOnServer = false
            savedCompany = nil
            plantOnServer = false
            savedPlantName = nil
            show(.company)
            errorMessage = AriaSignUpError.noCompany.localizedDescription
        } catch AriaError.http where stage == .plan {
            // Un rifiuto senza codice noto: il testo della web.
            errorMessage = AriaSignUpError.finishFailed.localizedDescription
        } catch {
            if step != stage, !AriaHTTP.isOffline(error) { step = stage }
            fail(error, readsAccount: stage == .profile)
        }
    }

    /// Il primo passo della bozza che non si può ancora scrivere; `nil`: tutto pronto.
    private var firstIncompleteStep: AriaSignUpStep? {
        if !profileMissing.isEmpty { return .profile }
        guard !memberOnly else { return nil }
        if !companyOnServer, !companyMissing.isEmpty { return .company }
        if !plantOnServer, !plantMissing.isEmpty { return .plant }
        return nil
    }

    /// POST /v1/companies. Il sito si è verificato uscendo dal passo Azienda; se non lo è più, si ricontrolla.
    private func createCompany() async throws -> Bool {
        if websiteStatus != .verified {
            guard await websiteVerifiedForSaving() else {
                step = .company
                return false
            }
        }
        let slug = normalizedSlug
        let company = AriaNewCompany(name: trimmedCompanyName, slug: slug, industry: industryValue, size: size?.rawValue)
        do {
            companyId = try await api.createCompany(company).id
            createdCompanyHere = true
            companyOnServer = true
            savedCompany = (trimmedCompanyName, slug)
            return true
        } catch AriaError.http(let status, _) where [403, 409, 500].contains(status) {
            return try await recoverRefusedCompany(status: status, slug: slug)
        }
    }

    /// POST /v1/plants con il Company-Id dell'azienda appena creata. Prima si rilegge l'elenco: una risposta persa e
    /// un nuovo tentativo farebbero "codice già usato". Rifiutato per i diritti: si va avanti (l'avviso della chat
    /// offrirà di aggiungerlo); rifiutato per altro (es. codice già usato): si torna al passo con il testo del server.
    private func createPlant() async throws -> Bool {
        try await readPlants()
        guard !plantOnServer else { return true }
        guard let companyId = try await ownCompanyId() else { return true }
        let location = trimmed(plantLocation)
        let plant = AdminPlantCreate(name: trimmed(plantName), code: trimmed(plantCode), description: nil,
                                     location: location.isEmpty ? nil : location)
        do {
            try await api.createPlant(plant, companyId: companyId)
            plantOnServer = true
            savedPlantName = plant.name
            return true
        } catch where !AriaHTTP.isOffline(error) && !(error is CancellationError) {
            if case .signedOut? = error as? AriaError { throw error }
            guard let failure = AdminPlantsFailure.from(error, action: .write, backend: app.backend) else { return false }
            if failure.isForbidden {
                AriaAuthTrace.failure("signUp.plant.create.failed", error)
                plantOnServer = true
                plantForbidden = true
                return true
            }
            step = .plant
            errorMessage = failure.message
            return false
        }
    }

    // MARK: Uscita

    func signOut() {
        slugCheck?.cancel()
        app.logout()
    }

    /// L'avviso "crea l'azienda sulla web" è stato letto: si esce.
    func dismissBlockingMessage() {
        blockingMessage = nil
        signOut()
    }

    // MARK: Errori

    private func begin() {
        isSaving = true
        clearMessages()
    }

    private func clearMessages() {
        errorMessage = nil
        isOffline = false
    }

    /// Sessione finita: si torna al login (ContentView). 404 su stato o profilo: l'account è stato cancellato, si esce.
    private func fail(_ error: any Error, readsAccount: Bool = false) {
        if case .signedOut? = error as? AriaError {
            app.backend.handle(error)
            return
        }
        if readsAccount, case .http(let status, _)? = error as? AriaError, status == 404 {
            signOut()
            return
        }
        if AriaHTTP.isOffline(error) {
            isOffline = true
        } else {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Tempo massimo

    /// Una chiamata che dura al massimo `timeout` (lo slug 8 s, il listino 10 s, come la web): poi conta come fallita.
    private nonisolated static func withTimeout<T: Sendable>(
        _ timeout: Duration, _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CancellationError()
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw CancellationError() }
            return first
        }
    }
}
