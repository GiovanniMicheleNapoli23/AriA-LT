//
//  AriaSignUpViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Tutta la logica dell'iscrizione dopo il link (contratto "Onboarding in the app", §3–6): quale passo tocca lo dice
//  sempre GET /v1/onboarding/status, riletto dopo ogni passo.
//  • Profilo: PATCH /v1/me con nome e ruolo obbligatori, telefono facoltativo, lingua del telefono.
//  • Azienda: slug dal nome con la regola della web, chiesto al server 400 ms dopo l'ultimo tasto; Continua solo con
//    lo slug libero. Un 403 (non si è più "nuova iscrizione") o un 500 (slug preso nel frattempo) si chiariscono
//    rileggendo lo stato: l'azienda può esserci già (risposta persa, o creata sulla web).
//  • Stabilimento: senza, la chat non risponde. Si chiede finché l'azienda non ne ha uno (GET /v1/plants con il suo
//    Company-Id); un elenco o una creazione rifiutati per i diritti (es. prima del piano) non bloccano: si passa al
//    Piano e l'avviso della chat lo offre.
//  • Piano: solo la demo gratuita, con la chiamata finale della web; una alla volta.
//  Finito, AriaBackend rilegge le aziende e ContentView mostra l'app. La vista mostra lo stato e passa le azioni.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaSignUpViewModel {
    let app: AppViewModel
    @ObservationIgnored private let slugDelay: Duration

    /// Il passo da mostrare; `nil` finché lo stato non è letto.
    private(set) var step: AriaSignUpStep?
    private(set) var isLoading = false
    /// Una chiamata di un passo in corso: il pulsante resta disattivato (due fine insieme manderebbero due email).
    private(set) var isSaving = false
    /// Messaggio sotto il modulo.
    private(set) var errorMessage: String?
    /// Il server non si raggiunge: l'avviso "offline" al posto dell'errore.
    private(set) var isOffline = false
    /// Da qui non si può creare l'azienda (es. un membro sospeso): l'avviso, poi si esce.
    private(set) var blockingMessage: String?

    // MARK: Profilo
    var name: String
    var jobRole: AriaJobRole?
    var phone = ""

    // MARK: Azienda
    private var companyNameText = ""
    private var slugText = ""
    /// Lo slug toccato a mano non segue più il nome.
    private var slugEdited = false
    var industry: AriaCompanyIndustry?
    var size: AriaCompanySize?
    private(set) var slugState: AriaSlugState = .idle
    @ObservationIgnored private var slugCheck: Task<Void, Never>?

    // MARK: Stabilimento
    var plantName = ""
    var plantCode = ""
    var plantLocation = ""
    /// L'azienda creata qui, o ritrovata riaprendo l'app: il Company-Id delle rotte degli stabilimenti.
    @ObservationIgnored private var companyId: String?
    /// Stabilimento creato, o rifiutato per i diritti: non si chiede (né si manda) più.
    @ObservationIgnored private var plantSettled = false

    init(app: AppViewModel, slugDelay: Duration = .milliseconds(400)) {
        self.app = app
        self.slugDelay = slugDelay
        name = app.backend.mobileAccount?.name ?? ""
    }

    private var api: AriaSignUpAPI { AriaSignUpAPI(api: app.backend.api) }

    // MARK: Stato

    /// L'email con cui ci si è iscritti, per ricordare con che account si sta creando l'azienda.
    var email: String { app.backend.mobileAccount?.email ?? "" }

    var stepCount: Int { AriaSignUpStep.allCases.count }

    var stepIndex: Int { step?.rawValue ?? 0 }

    var progressLabel: String {
        String(localized: "Step \(stepIndex + 1) of \(stepCount)")
    }

    /// Lo stato non si è letto: al posto del modulo, l'errore e "Riprova".
    var needsRetry: Bool { step == nil && !isLoading && (errorMessage != nil || isOffline) }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedCompanyName: String { companyName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSaveProfile: Bool { !trimmedName.isEmpty && jobRole != nil && !isSaving }

    var canCreateCompany: Bool { !trimmedCompanyName.isEmpty && slugState == .available && !isSaving }

    var canCreatePlant: Bool { !trimmed(plantName).isEmpty && !trimmed(plantCode).isEmpty && !isSaving }

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

    /// Legge lo stato e mostra il passo che tocca; a onboarding finito apre l'app.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        clearMessages()
        defer { isLoading = false }
        do {
            try await advance()
        } catch {
            fail(error, readsAccount: true)
        }
    }

    /// Rilegge lo stato e passa al passo che dice.
    private func advance() async throws {
        let status = try await api.status()
        let hasPlant = status.companyCreated && !status.onboardingComplete ? try await companyHasPlant() : true
        guard let next = AriaSignUpStep(status, hasPlant: hasPlant) else {
            await complete()
            return
        }
        step = next
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

    // MARK: Profilo

    func saveProfile() async {
        guard canSaveProfile, let jobRole else { return }
        begin()
        defer { isSaving = false }
        let phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = AriaProfileUpdate(name: trimmedName, jobRole: jobRole.rawValue, phone: phone.isEmpty ? nil : phone,
                                        preferredLocale: AriaSignUpLocale.current)
        do {
            app.backend.profileSaved(try await api.updateProfile(profile))
            // Chi è entrato in un'azienda altrui ha finito qui, come sulla web.
            try await advance()
        } catch {
            fail(error, readsAccount: true)
        }
    }

    // MARK: Azienda

    func createCompany() async {
        guard canCreateCompany else { return }
        let slug = normalizedSlug
        let company = AriaNewCompany(name: trimmedCompanyName, slug: slug, industry: industry?.rawValue, size: size?.rawValue)
        begin()
        defer { isSaving = false }
        do {
            companyId = try await api.createCompany(company).id
            try await advance()
        } catch AriaError.http(let status, _) where status == 403 || status == 500 {
            await recoverRefusedCompany(status: status, slug: slug)
        } catch {
            fail(error)
        }
    }

    /// 403 `operator_identity_forbidden` (non si è più una nuova iscrizione) o 500 (di solito lo slug preso fra il
    /// controllo e la creazione): prima di dire qualcosa si guarda se l'azienda c'è già.
    private func recoverRefusedCompany(status: Int, slug: String) async {
        do {
            let current = try await api.status()
            if current.companyCreated {
                try await advance()
                return
            }
            if status == 403 {
                blockingMessage = String(localized: "You can't create a company from the app with this account. Create it on the AriaPLT website, then sign in again.")
                return
            }
            if try await !api.checkSlug(slug).available {
                if slug == normalizedSlug { slugState = .taken }
                errorMessage = String(localized: "This short name is already taken. Choose another one.")
                return
            }
            errorMessage = String(localized: "Something went wrong. Try again.")
        } catch {
            fail(error)
        }
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
        slugCheck = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            let result: AriaSlugState
            do {
                result = try await api.checkSlug(slug).available ? .available : .taken
            } catch {
                result = .failed
            }
            guard !Task.isCancelled, let self, self.normalizedSlug == slug else { return }
            self.slugState = result
        }
    }

    // MARK: Stabilimento

    func createPlant() async {
        guard canCreatePlant else { return }
        begin()
        defer { isSaving = false }
        let location = trimmed(plantLocation)
        let plant = AdminPlantCreate(name: trimmed(plantName), code: trimmed(plantCode), description: nil,
                                     location: location.isEmpty ? nil : location)
        do {
            // Creato ma lo stato non si è riletto: "Riprova" rilegge soltanto, un secondo POST farebbe un doppione.
            if !plantSettled, let companyId = try await ownCompanyId() {
                try await api.createPlant(plant, companyId: companyId)
            }
            plantSettled = true
        } catch where !AriaHTTP.isOffline(error) {
            guard let failure = AdminPlantsFailure.from(error, action: .write, backend: app.backend) else { return }
            guard failure.isForbidden else {
                // Rifiutato (es. codice già usato): resta qui con il testo del server. L'azienda c'è già, mai indietro.
                errorMessage = failure.message
                return
            }
            // Chi ha appena creato l'azienda non deve restare fermo qui: l'avviso della chat offrirà di aggiungerlo.
            AriaAuthTrace.failure("signUp.plant.create.failed", error)
            plantSettled = true
        } catch {
            fail(error)
            return
        }
        do {
            try await advance()
        } catch {
            fail(error)
        }
    }

    /// L'azienda ha già uno stabilimento? Senza un'azienda propria (o con l'elenco rifiutato) si va avanti.
    private func companyHasPlant() async throws -> Bool {
        guard !plantSettled, let companyId = try await ownCompanyId() else { return true }
        do {
            return try await !api.plants(companyId: companyId).isEmpty
        } catch AriaError.signedOut {
            throw AriaError.signedOut
        } catch where AriaHTTP.isOffline(error) || error is CancellationError {
            throw error
        } catch {
            AriaAuthTrace.failure("signUp.plants.failed", error)
            return true
        }
    }

    /// Quella creata al passo Azienda; riaperta l'app, la propria con l'onboarding a metà.
    private func ownCompanyId() async throws -> String? {
        if let companyId { return companyId }
        let companies = try await api.companies()
        let own = companies.first { $0.myRole == "owner" && $0.onboardingCompleted == false }
            ?? companies.first { $0.myRole == "owner" }
        companyId = own?.id
        return companyId
    }

    // MARK: Piano

    /// La demo gratuita: piano sull'azienda, onboarding completo, email di benvenuto. `alreadyDone` vale come riuscito.
    func finish() async {
        guard canFinish else { return }
        begin()
        defer { isSaving = false }
        do {
            _ = try await app.backend.api.auth.finishOnboarding(plan: AriaSignUpAPI.freeDemoPlan)
            await complete()
        } catch AriaSignUpError.noCompany {
            // L'azienda non c'è (creata e poi tolta, o mai arrivata): si torna al passo Azienda, come la web.
            companyId = nil
            plantSettled = false
            step = .company
            errorMessage = AriaSignUpError.noCompany.localizedDescription
        } catch {
            fail(error)
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
}
