//
//  SignUpTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Iscrizione dall'app (contratto "Onboarding in the app", 10/11/26): la regola dello slug della web, il passo che
//  tocca, il link d'iscrizione chiesto dall'app (captcha, email che deve combaciare), chi resta collegato senza aziende, la chiamata finale
//  sulla web e i passi del view model (Profilo, Azienda con i suoi rifiuti, Piano).
//

import Foundation
import Testing
@testable import AriaLite

// MARK: - Regole pure

@Suite("Sign-up rules")
struct SignUpRules {
    @Test(arguments: [
        ("Acme Srl", "acme-srl"),
        ("Ölwerk & Co.", "lwerk-co"),
        ("  --Hello__World--  ", "hello-world"),
        ("ACME 2026", "acme-2026"),
        ("---", ""),
    ])
    func slugFollowsTheWebRule(input: String, slug: String) {
        #expect(AriaSlug.normalize(input) == slug)
    }

    @Test func slugKeepsTheFirst32Characters() {
        let slug = AriaSlug.normalize(String(repeating: "abcdefghij", count: 4))
        #expect(slug.count == 32)
        #expect(slug == String(String(repeating: "abcdefghij", count: 4).prefix(32)))
    }

    @Test func whileTypingATrailingSeparatorStays() {
        #expect(AriaSlug.editing("acme ") == "acme-", "altrimenti non si separano due parole")
        #expect(AriaSlug.editing("acme-s") == "acme-s")
        #expect(AriaSlug.editing("acme") == "acme")
        #expect(AriaSlug.editing(" ") == "")
        #expect(AriaSlug.normalize(AriaSlug.editing("acme ")) == "acme", "si controlla e si manda la forma normalizzata")
    }

    @Test func theStepFollowsTheWebOrder() {
        func step(_ profile: Bool, _ company: Bool, _ plan: Bool, _ done: Bool, hasPlant: Bool = true) -> AriaSignUpStep? {
            AriaSignUpStep(AriaSignUpStatus(profileComplete: profile, companyCreated: company, planSelected: plan,
                                            onboardingComplete: done), hasPlant: hasPlant)
        }
        #expect(step(false, false, false, false) == .profile)
        #expect(step(true, false, false, false) == .company)
        #expect(step(true, true, false, false, hasPlant: false) == .plant, "senza stabilimento la chat non risponde")
        #expect(step(true, true, false, false) == .plan)
        #expect(step(true, true, true, false) == .plan, "planSelected da solo non chiude l'onboarding")
        #expect(step(false, false, false, true, hasPlant: false) == nil)
    }

    @Test func aMemberOfSomeoneElsesCompanyOnlyFillsTheProfile() {
        func step(_ profile: Bool) -> AriaSignUpStep? {
            AriaSignUpStep(AriaSignUpStatus(profileComplete: profile, companyCreated: true, planSelected: true,
                                            onboardingComplete: false), hasPlant: false, memberOnly: true)
        }
        #expect(step(false) == .profile)
        #expect(step(true) == nil, "col profilo fatto si entra: l'azienda e il piano non sono suoi")
    }

    @Test func aSavedRoleOutsideTheListOpensOther() {
        let listed = AriaJobRole.choice(saved: "technician")
        #expect(listed.role == .technician && listed.otherText.isEmpty)
        let typed = AriaJobRole.choice(saved: " Quality lead ")
        #expect(typed.role == .other && typed.otherText == "Quality lead")
        let bare = AriaJobRole.choice(saved: "other")
        #expect(bare.role == .other && bare.otherText.isEmpty)
        #expect(AriaJobRole.choice(saved: nil).role == nil)
        #expect(AriaOtherChoice.value("other", isOther: true, otherText: "  Packaging ") == "Packaging")
        #expect(AriaOtherChoice.value("energy", isOther: false, otherText: "x") == "energy")
        #expect(AriaOtherChoice.value("other", isOther: true, otherText: String(repeating: "a", count: 90)).count == 80)
        #expect(AriaOtherChoice.value(nil, isOther: false, otherText: "") == "")
    }

    @Test func onboardingCompanyRunsOnlyForOwnersAndAdmins() {
        #expect(AriaOnboardingCompany(id: "c1", name: nil, slug: nil, role: "admin").runsCompany)
        #expect(AriaOnboardingCompany(id: "c1", name: nil, slug: nil, role: "owner").runsCompany)
        #expect(!AriaOnboardingCompany(id: "c1", name: nil, slug: nil, role: "member").runsCompany)
        #expect(!AriaOnboardingCompany(id: nil, name: nil, slug: nil, role: "owner").runsCompany)
    }

    @Test func companySizesUseTheEnDash() {
        #expect(AriaCompanySize.allCases.map(\.rawValue) == ["1\u{2013}10", "11\u{2013}50", "51\u{2013}200", "201\u{2013}1000", "1000+"])
        #expect(!AriaCompanySize.allCases.contains { $0.rawValue.contains("-") })
    }
}

// MARK: - Backend e view model (rete finta)

extension BackendTests {
    @Suite("Sign-up")
    @MainActor
    struct SignUp {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        nonisolated static let fresh = #"{"profileComplete":false,"companyCreated":false,"planSelected":false,"onboardingComplete":false}"#
        nonisolated static let named = #"{"profileComplete":true,"companyCreated":false,"planSelected":false,"onboardingComplete":false}"#
        nonisolated static let owner = #"{"profileComplete":true,"companyCreated":true,"planSelected":false,"onboardingComplete":false}"#
        nonisolated static let done = #"{"profileComplete":true,"companyCreated":true,"planSelected":true,"onboardingComplete":true}"#

        /// Chi si iscrive: link d'iscrizione chiesto da qui, link verificato, nessuna azienda.
        private func newSignUp(status: Reply? = nil, on existing: AriaBackend? = nil) async throws -> AriaBackend {
            let backend = existing ?? AriaBackend()
            TestEnv.stubSignIn(companies: "[]")
            server.route("GET /v1/onboarding/status", status ?? .json(Self.fresh))
            server.route("POST /api/auth/mobile/sign-up-link", .json("{}", status: 202))
            try await backend.sendSignUpLink(email: "mario@acme.test", captcha: "CAPTCHA")
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            return backend
        }

        // MARK: Link e routing

        @Test func aNewSignUpStaysSignedInAndIsSentToOnboarding() async throws {
            let backend = try await newSignUp()

            #expect(backend.isSignedIn, "una lista vuota non fa uscire chi si è appena iscritto")
            #expect(backend.isSigningUp)
            #expect(AriaKeychain.exists("aria.mobile_session"))
            #expect(server.calls("GET /v1/plants").isEmpty, "niente stabilimenti prima dell'azienda")
            let status = try #require(server.calls("GET /v1/onboarding/status").first)
            #expect(status.header("company-id") == nil)
            #expect(backend.pendingLinkEmail == nil, "il link è stato usato")
        }

        @Test func theSignUpLinkCarriesTheCaptchaAndTheNormalisedEmail() async throws {
            server.route("POST /api/auth/mobile/sign-up-link", .json("{}", status: 202))
            let backend = AriaBackend()
            try await backend.sendSignUpLink(email: " New@Acme.test ", captcha: "CAPTCHA")
            let call = try #require(server.calls("POST /api/auth/mobile/sign-up-link").first)
            #expect(call.host == backend.authURL.host(), "sull'host della web")
            #expect(call.header("x-captcha-response") == "CAPTCHA")
            #expect(call.header("company-id") == nil)
            #expect(call.header("cookie") == nil, "con un cookie la web controllerebbe anche l'Origin")
            #expect(call.header("x-aria-locale") == backend.api.context.locale, "l'email arriva nella lingua dell'app")
            #expect(call.json?["email"] as? String == "new@acme.test")
            #expect(backend.pendingLinkEmail == "new@acme.test", "il passo 2 aspetta il link di questa email")
            #expect(server.calls("POST /api/auth/mobile/request-link").isEmpty, "a chi ha già l'app non arrivano due email")
        }

        @Test func aSignUpLinkForAnotherEmailIsRefused() async throws {
            TestEnv.stubSignIn(companies: "[]")
            server.route("POST /api/auth/mobile/sign-up-link", .json("{}", status: 202))
            let backend = AriaBackend()
            try await backend.sendSignUpLink(email: "someone.else@acme.test", captcha: "CAPTCHA")
            await #expect(throws: AriaSignInError.self) { try await backend.completeSignIn(with: AriaSignInLink(token: "t")) }
            #expect(!backend.isSignedIn)
            #expect(backend.pendingLinkEmail == "someone.else@acme.test")
        }

        @Test(arguments: [
            (400, #"{"code":"MISSING_RESPONSE","message":"x"}"#, false),
            (403, #"{"code":"VERIFICATION_FAILED","message":"x"}"#, false),
            (403, #"{"code":"SIGN_UP_DISABLED","message":"x"}"#, true),
            (404, #"{"message":"Not Found"}"#, true),
        ])
        func aRefusedSignUpLinkSaysWhy(status: Int, body: String, unavailable: Bool) async throws {
            server.route("POST /api/auth/mobile/sign-up-link", .json(body, status: status))
            let backend = AriaBackend()
            do {
                try await backend.sendSignUpLink(email: "new@acme.test", captcha: "CAPTCHA")
                Issue.record("nessun link deve risultare partito")
            } catch AriaError.signUpCheckFailed where !unavailable {
            } catch AriaError.signUpUnavailable where unavailable {
                // Una web senza la rotta d'iscrizione dell'app, o con l'iscrizione spenta (il 403 si distingue dal code).
            } catch {
                Issue.record("errore inatteso: \(error)")
            }
            #expect(backend.pendingLinkEmail == nil, "nessun link in arrivo")
        }

        @Test func aDeletedAccountIsSignedOut() async throws {
            let backend = try await newSignUp(status: .json(#"{"detail":"User not found"}"#, status: 404))
            #expect(!backend.isSignedIn)
            #expect(!backend.isSigningUp)
            #expect(!AriaKeychain.exists("aria.mobile_session"))
        }

        @Test func anUnreadStatusKeepsTheNewSignUpIn() async throws {
            let backend = try await newSignUp(status: .failing(.notConnectedToInternet))
            #expect(backend.isSignedIn, "una rete che cade non butta fuori chi si è appena iscritto")
            #expect(backend.isSigningUp, "la schermata dell'iscrizione riprova da sé")
        }

        @Test func anOwnerWithAnUnfinishedCompanyGoesBackToOnboarding() async throws {
            TestEnv.stubSignIn(companies: #"[{"id":"c9","name":"Acme","myRole":"owner","onboardingCompleted":false}]"#)
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(backend.isSigningUp)
            #expect(server.calls("GET /v1/plants").isEmpty)
        }

        @Test func aJoinedMemberNeverReadsTheStatus() async throws {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(!backend.isSigningUp)
            #expect(server.calls("GET /v1/onboarding/status").isEmpty, "su un backend vecchio risulterebbe a metà")
        }

        @Test func signingUpSurvivesARelaunchAndEndsWithSignOut() async throws {
            TestEnv.markInstalled()
            let backend = try await newSignUp()
            #expect(AriaBackend().isSigningUp, "riaperta l'app, niente shell nemmeno per un istante")
            await backend.signOut()
            #expect(!backend.isSigningUp)
            #expect(!AriaBackend().isSigningUp)
        }

        @Test func anOwnerWhoCameInWithTheAppLinkGetsTheAdminLayout() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            #expect(backend.accountKind == .operator, "il link dell'app parte da operatore")
            await TestEnv.grant(nil, to: backend, restricted: false)
            #expect(backend.accountKind == .admin, "lo dice GET /v1/me: niente operatorProfile, diritti pieni")
            #expect(!backend.usesOperatorLayout)
        }

        // MARK: Chiamata finale (web)

        @Test func finishSendsTheFreeDemoWithTheSession() async throws {
            let backend = try await newSignUp(status: .json(Self.owner))
            server.route("POST /api/auth/onboarding/finish", .json(#"{"onboardingComplete":true,"alreadyDone":true}"#))
            let alreadyDone = try await backend.api.auth.finishOnboarding(plan: AriaSignUpAPI.freeDemoPlan)
            #expect(alreadyDone)
            let call = try #require(server.calls("POST /api/auth/onboarding/finish").first)
            #expect(call.host == backend.authURL.host(), "sull'host della web, non dell'API")
            #expect(call.header("authorization") == "Bearer SESSION", "con la sessione, non con il JWT")
            #expect(call.json?["plan"] as? String == "free_demo")
        }

        @Test func aFinishBackendErrorIsNotAnOfflineHost() async throws {
            let backend = try await newSignUp(status: .json(Self.owner))
            server.route("POST /api/auth/onboarding/finish",
                         .json(#"{"code":"backend_error","message":"Could not finish onboarding. Try again in a moment."}"#, status: 502))
            await #expect(throws: AriaSignUpError.finishFailed) {
                try await backend.api.auth.finishOnboarding(plan: AriaSignUpAPI.freeDemoPlan)
            }
            server.route("POST /api/auth/onboarding/finish", .json(#"{"code":"no_company","message":"x"}"#, status: 409))
            await #expect(throws: AriaSignUpError.noCompany) {
                try await backend.api.auth.finishOnboarding(plan: AriaSignUpAPI.freeDemoPlan)
            }
        }

        // MARK: View model

        nonisolated static let acme = #"{"id":"c9","name":"Acme","myRole":"owner","onboardingCompleted":false}"#
        nonisolated static let acmeDone = #"[{"id":"c9","name":"Acme","myRole":"owner","onboardingCompleted":true}]"#
        nonisolated static let member = #"{"profileComplete":false,"companyCreated":true,"planSelected":true,"onboardingComplete":false}"#
        nonisolated static let meReply = #"{"id":"u1","name":"Maria Rossi","email":"mario@acme.test"}"#

        /// Il DNS è sempre finto (`resolver`): il sito che si apre dall'email (acme.test) si verifica da sé.
        private func model(status: String = SignUp.fresh, resolver: SignUpDomainStub = SignUpDomainStub(.found),
                           online: Bool = true) async throws -> AriaSignUpViewModel {
            let app = AppViewModel()
            _ = try await newSignUp(status: .json(status), on: app.backend)
            let model = AriaSignUpViewModel(app: app, slugDelay: .milliseconds(10), websiteDelay: .milliseconds(10),
                                            resolver: resolver, isOnline: { online })
            await model.load()
            return model
        }

        /// Un modello per chi rientra con un account già collegato (azienda nell'elenco, stato `status`).
        private func returning(companies: String, plants: Reply, status: String = SignUp.owner,
                               me: String? = nil) async throws -> AriaSignUpViewModel {
            TestEnv.stubSignIn(companies: companies, plants: plants)
            server.route("GET /v1/onboarding/status", .json(status))
            if let me { server.route("GET /v1/me", .json(me)) }
            let app = AppViewModel()
            try await TestEnv.requestLink(app.backend)
            try await app.backend.completeSignIn(with: AriaSignInLink(token: "t"))
            let model = AriaSignUpViewModel(app: app, websiteDelay: .milliseconds(10), resolver: SignUpDomainStub(.found),
                                            isOnline: { true })
            await model.load()
            return model
        }

        private func fillProfile(_ model: AriaSignUpViewModel) {
            model.name = "  Maria Rossi "
            model.jobRole = .maintenanceEngineer
        }

        /// Il passo Azienda pronto: nome, slug libero, settore, sito verificato.
        private func fillCompany(_ model: AriaSignUpViewModel, industry: AriaCompanyIndustry = .energy) async {
            server.route("GET /v1/companies/check-slug?slug=acme", .json(#"{"available":true,"slug":"acme"}"#))
            model.companyName = "Acme"
            model.industry = industry
            #expect(await TestEnv.waitUntil { model.slugState == .available })
            #expect(await TestEnv.waitUntil { model.websiteStatus == .verified })
        }

        private func fillPlant(_ model: AriaSignUpViewModel) {
            model.plantName = " Main plant "
            model.plantCode = " MAIN "
        }

        /// Da un iscritto nuovo fino al Piano, compilando tutto: nessuna scrittura per strada.
        private func walkToPlan(_ model: AriaSignUpViewModel) async {
            fillProfile(model)
            await model.continueFromStep()
            #expect(model.step == .company)
            await fillCompany(model)
            await model.continueFromStep()
            #expect(model.step == .plant)
            fillPlant(model)
            await model.continueFromStep()
            #expect(model.step == .plan)
        }

        /// Le risposte della scrittura finale di un owner nuovo, fino all'ingresso nell'app.
        private func stubFinalRun() {
            server.route("PATCH /v1/me", .json(Self.meReply))
            server.route("GET /v1/onboarding/status", .json(Self.named))
            server.route("POST /v1/companies", .json(Self.acme, status: 201))
            server.route("GET /v1/plants", .json("[]"), .json(#"[{"id":"p1","name":"Main plant","code":"MAIN"}]"#))
            server.route("POST /v1/plants", .json(#"{"id":"p1","name":"Main plant","code":"MAIN"}"#, status: 201))
            server.route("POST /api/auth/onboarding/finish", .json(#"{"onboardingComplete":true,"alreadyDone":false}"#))
            server.route("GET /v1/companies", .json(Self.acmeDone))
        }

        private var writes: [String] {
            server.calls.map { "\($0.method) \($0.path)" }.filter {
                ["PATCH /v1/me", "POST /v1/companies", "POST /v1/plants", "POST /api/auth/onboarding/finish"].contains($0)
            }
        }

        // MARK: Bozza e navigazione

        @Test func nothingIsWrittenUntilTheLastButton() async throws {
            let model = try await model()
            #expect(model.step == .profile)
            #expect(!model.canGoBack, "dal primo passo non si torna indietro")
            #expect(!model.canSaveProfile, "nome e ruolo sono obbligatori")
            await walkToPlan(model)
            model.goBack()
            model.goBack()
            #expect(model.step == .company)
            await model.continueFromStep()
            await model.continueFromStep()
            #expect(model.step == .plan)
            #expect(writes.isEmpty, "si scrive tutto alla fine")
        }

        @Test func backKeepsWhatWasTyped() async throws {
            let model = try await model()
            await walkToPlan(model)
            model.goBack()
            #expect(model.step == .plant)
            #expect(model.plantName == " Main plant ")
            model.goBack()
            #expect(model.companyName == "Acme")
            #expect(model.industry == .energy)
            #expect(model.website == "acme.test")
            model.goBack()
            #expect(model.step == .profile)
            #expect(model.jobRole == .maintenanceEngineer)
            #expect(!model.canGoBack)
        }

        @Test func aSecondLoadLeavesStepAndFields() async throws {
            let model = try await model()
            fillProfile(model)
            await model.continueFromStep()
            await model.load()
            #expect(model.step == .company)
            #expect(model.name == "  Maria Rossi ")
        }

        @Test func theLastButtonWritesEverythingInOrder() async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            await model.finish()

            #expect(writes == ["PATCH /v1/me", "POST /v1/companies", "POST /v1/plants", "POST /api/auth/onboarding/finish"])
            let patch = try #require(server.calls("PATCH /v1/me").first)
            #expect(patch.header("company-id") == nil)
            #expect(patch.json?["name"] as? String == "Maria Rossi")
            #expect(patch.json?["jobRole"] as? String == "maintenance_engineer")
            #expect(patch.json?["preferredLocale"] as? String == AriaSignUpLocale.current)
            #expect(patch.json?.keys.contains("phone") == false, "un telefono vuoto non si manda")
            let company = try #require(server.calls("POST /v1/companies").first)
            #expect(company.json?["slug"] as? String == "acme")
            #expect(company.json?["industry"] as? String == "energy")
            #expect(company.json?.keys.contains("size") == false, "senza scelta non si manda")
            #expect(company.json?.keys.contains("website") == false, "il backend non lo salva")
            #expect(company.json?.keys.contains("plan") == false)
            let plant = try #require(server.calls("POST /v1/plants").first)
            #expect(plant.header("company-id") == "c9", "l'azienda appena creata, non quella del contesto")
            #expect(plant.json?["name"] as? String == "Main plant")
            #expect(plant.json?["code"] as? String == "MAIN")
            #expect(plant.json?["location"] == nil, "un campo vuoto non si manda")
            #expect(server.calls("POST /api/auth/onboarding/finish").first?.json?["plan"] as? String == "free_demo")
            #expect(!model.memberOnly, "chi ha creato l'azienda non diventa solo membro")
            #expect(model.app.backend.mobileAccount?.name == "Maria Rossi")
            #expect(!model.app.backend.isSigningUp, "si entra nell'app")
        }

        @Test func anIncompleteDraftWritesNothingAndGoesToTheMissingStep() async throws {
            // Si riparte dall'Azienda (profilo fatto sul server) e /v1/me non risponde: il ruolo in bozza è vuoto.
            let model = try await model(status: Self.named)
            #expect(model.step == .company)
            #expect(model.canGoBack)
            stubFinalRun()
            await model.finish()
            #expect(writes.isEmpty, "un PATCH vuoto cancellerebbe il ruolo salvato")
            #expect(model.step == .profile)
        }

        @Test func theDraftSurvivesTheViewButNotTheAccount() async throws {
            let app = AppViewModel()
            _ = try await newSignUp(status: .json(Self.fresh), on: app.backend)
            let draft = app.signUpModel()
            #expect(app.signUpModel() === draft, "la vista ricreata ritrova la stessa bozza")
            app.logout()
            #expect(app.signUpModel() !== draft, "chi entra dopo non la eredita")
        }

        @Test func otherSendsTheTypedRoleAndIndustry() async throws {
            let model = try await model()
            model.name = "Maria"
            model.jobRole = .other
            #expect(!model.canSaveProfile, "con \"Altro\" serve il testo")
            #expect(model.stillNeeded?.contains(String(localized: "your role")) == true)
            model.otherJobRole = " Quality lead "
            await model.continueFromStep()
            await fillCompany(model, industry: .other)
            #expect(!model.canCreateCompany, "con \"Altro\" serve il settore scritto")
            model.otherIndustry = " Packaging "
            await model.continueFromStep()
            fillPlant(model)
            await model.continueFromStep()
            stubFinalRun()
            await model.finish()
            #expect(server.calls("PATCH /v1/me").first?.json?["jobRole"] as? String == "Quality lead")
            #expect(server.calls("POST /v1/companies").first?.json?["industry"] as? String == "Packaging")
        }

        @Test func theProfileOpensWithWhatTheServerHas() async throws {
            server.route("GET /v1/me", .json(#"{"id":"u1","name":"Maria","email":"mario@acme.test","jobRole":"Quality lead","phone":"+39 333"}"#))
            let model = try await model()
            #expect(model.name == "Maria")
            #expect(model.jobRole == .other)
            #expect(model.otherJobRole == "Quality lead")
            #expect(model.phone == "+39 333")
        }

        // MARK: Errori alla fine

        @Test func aFailedPlantGoesBackToItsStepAndTheRetryDoesNotRepeatTheCompany() async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            server.route("POST /v1/plants", .json(#"{"detail":"A plant with this code already exists"}"#, status: 409),
                         .json(#"{"id":"p1","name":"Main plant","code":"MAIN2"}"#, status: 201))
            await model.finish()
            #expect(model.step == .plant, "l'errore si mostra sul passo che l'ha causato")
            #expect(model.errorMessage == "A plant with this code already exists")
            #expect(model.canGoBack)
            model.goBack()
            #expect(model.companyOnServer, "l'azienda è già sul server: sola lettura")
            #expect(model.savedCompany?.name == "Acme")
            await model.continueFromStep()
            model.plantCode = "MAIN2"
            await model.continueFromStep()
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            server.route("GET /v1/plants", .json("[]"), .json("[]"), .json(#"[{"id":"p1","name":"Main plant","code":"MAIN2"}]"#))
            await model.finish()
            #expect(server.calls("POST /v1/companies").count == 1, "creata una volta sola")
            #expect(server.calls("POST /v1/plants").count == 2)
            #expect(server.calls("POST /api/auth/onboarding/finish").count == 1)
        }

        @Test func aRetryAfterAFailedFinishRepeatsNoCreation() async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            server.route("POST /api/auth/onboarding/finish",
                         .json(#"{"code":"backend_error","message":"x"}"#, status: 502),
                         .json(#"{"onboardingComplete":true,"alreadyDone":false}"#))
            await model.finish()
            #expect(model.step == .plan)
            #expect(model.errorMessage == AriaSignUpError.finishFailed.localizedDescription)

            // Riprovando, lo stato riletto dice che l'azienda c'è e l'elenco che lo stabilimento c'è.
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            await model.finish()
            #expect(server.calls("POST /v1/companies").count == 1)
            #expect(server.calls("POST /v1/plants").count == 1)
            #expect(server.calls("POST /api/auth/onboarding/finish").count == 2)
        }

        @Test func aCompanyRefusedButAlreadyThereGoesOn() async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            server.route("POST /v1/companies", .json(#"{"detail":{"code":"operator_identity_forbidden","message":"no"}}"#, status: 403))
            server.route("GET /v1/onboarding/status", .json(Self.named), .json(Self.owner))
            server.route("GET /v1/me", .json(#"{"id":"u1","name":"Maria Rossi","email":"mario@acme.test","onboardingCompany":{"id":"c9","name":"Acme","slug":"acme","role":"owner"}}"#))
            await model.finish()
            #expect(model.blockingMessage == nil, "la risposta della prima creazione si era persa")
            #expect(server.calls("POST /api/auth/onboarding/finish").count == 1)
        }

        @Test func aRefusedCompanyWithoutOneSendsThePersonToTheWeb() async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            server.route("POST /v1/companies", .json(#"{"detail":{"code":"operator_identity_forbidden","message":"no"}}"#, status: 403))
            await model.finish()
            #expect(model.step == .company)
            #expect(model.blockingMessage != nil)
        }

        @Test(arguments: [409, 500])
        func aSlugTakenMeanwhileGoesBackToCompany(status: Int) async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            server.route("GET /v1/companies/check-slug?slug=acme", .json(#"{"available":false,"slug":"acme"}"#))
            server.route("POST /v1/companies", .json(#"{"detail":"Slug already taken"}"#, status: status))
            await model.finish()
            #expect(model.step == .company)
            #expect(model.slugState == .taken)
            #expect(model.errorMessage == String(localized: "This workspace address is already taken. Choose another one."))
            #expect(!model.canCreateCompany)
            #expect(server.calls("POST /v1/plants").isEmpty)
        }

        /// ARIA-121: l'indirizzo è già attivo in un'altra azienda. Non è "indirizzo preso": si resta ad Azienda col testo
        /// della web, lo slug non è toccato e non si va avanti.
        @Test func anEmailAlreadyInAnotherCompanyStaysOnCompany() async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            let refusal = #"{"error":{"type":"http_error","message":"This email address already belongs to another company. An address can belong to one company only.","code":409,"request_id":"r1"},"detail":{"code":"already_in_another_company","message":"This email address already belongs to another company. An address can belong to one company only."}}"#
            server.route("POST /v1/companies", .json(refusal, status: 409))
            await model.finish()
            #expect(model.step == .company)
            #expect(model.errorMessage == String(localized: "Your email address already belongs to a company, and an address can belong to one company only, so a new company can't be created with it."))
            #expect(model.slugState != .taken)
            #expect(model.blockingMessage == nil)
            #expect(server.calls("POST /v1/companies").count == 1, "nessun nuovo tentativo da solo")
            #expect(server.calls("POST /v1/plants").isEmpty)
            #expect(server.calls("POST /api/auth/onboarding/finish").isEmpty)
        }

        @Test func finishingWithoutACompanyGoesBackToCompany() async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            server.route("POST /api/auth/onboarding/finish", .json(#"{"code":"no_company","message":"x"}"#, status: 409))
            await model.finish()
            #expect(model.step == .company)
            #expect(!model.companyOnServer)
            #expect(!model.isSaving)
        }

        @Test func aPlantRefusedForRightsGoesOnToTheFinish() async throws {
            let model = try await model()
            await walkToPlan(model)
            stubFinalRun()
            server.route("POST /v1/plants", .json(#"{"detail":"forbidden"}"#, status: 403))
            await model.finish()
            #expect(server.calls("POST /api/auth/onboarding/finish").count == 1, "l'avviso della chat offrirà di aggiungerlo")
        }

        // MARK: Chi si è

        @Test func aMemberWritesTheProfileOnceAndGoesIn() async throws {
            server.route("GET /v1/me", .json(#"{"id":"u1","name":"","email":"mario@acme.test","onboardingCompany":null}"#))
            let model = try await model(status: Self.member)
            #expect(model.step == .profile)
            #expect(model.memberOnly)
            #expect(model.isLastStep, "il Profilo è il suo ultimo passo")

            server.route("PATCH /v1/me", .json(Self.meReply))
            server.route("GET /v1/onboarding/status", .json(#"{"profileComplete":true,"companyCreated":true,"planSelected":true,"onboardingComplete":false}"#))
            server.route("GET /v1/companies", .json(#"[{"id":"c1","name":"Acme","myRole":"member"}]"#))
            fillProfile(model)
            await model.continueFromStep()
            #expect(writes == ["PATCH /v1/me"])
            #expect(!model.app.backend.isSigningUp, "si entra nell'app")
        }

        @Test func anAdminOfACompanyStillOnboardingSeesItReadOnly() async throws {
            let model = try await returning(
                companies: #"[{"id":"c7","name":"Acme","myRole":"admin","onboardingCompleted":false}]"#, plants: .json("[]"),
                me: #"{"id":"u1","name":"Mario","email":"mario@acme.test","jobRole":"technician","onboardingCompany":{"id":"c7","name":"Acme","slug":"acme","role":"admin"}}"#)
            #expect(model.app.backend.isSigningUp, "un admin dell'azienda in onboarding sceglie il piano")
            #expect(!model.memberOnly)
            #expect(model.step == .plant, "si parte dal primo passo che il server non ha")
            #expect(server.calls("GET /v1/plants").last?.header("company-id") == "c7")
            model.goBack()
            #expect(model.step == .company)
            #expect(model.companyOnServer)
            #expect(model.savedCompany?.name == "Acme")
            #expect(model.canCreateCompany, "sola lettura: si va avanti senza ricompilarla")
        }

        @Test func aMemberWithoutANameReadsTheStatus() async throws {
            TestEnv.stubSignIn()
            server.route("POST /api/auth/mobile/verify",
                         .json(#"{"token":"SESSION","user":{"id":"u1","name":"","email":"mario@acme.test"}}"#, headers: ["set-auth-token": "SESSION"]))
            server.route("GET /v1/onboarding/status", .json(Self.member))
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(backend.isSigningUp, "il profilo da compilare, come sulla web")
        }

        @Test func backAfterARelaunchTheCompanyWithoutPlantsAsksForOne() async throws {
            let model = try await returning(companies: "[\(Self.acme)]", plants: .json("[]"))
            #expect(model.step == .plant)
            #expect(server.calls("GET /v1/plants").last?.header("company-id") == "c9")
            model.goBack()
            #expect(model.companyOnServer, "l'azienda c'è: sola lettura")
            #expect(model.savedCompany?.name == "Acme", "il nome dall'elenco, anche senza /v1/me")
        }

        @Test func plantsThatCantBeReadSkipToThePlan() async throws {
            let model = try await returning(companies: "[\(Self.acme)]", plants: .json(#"{"detail":"forbidden"}"#, status: 403))
            #expect(model.step == .plan, "l'avviso della chat offre comunque di aggiungerlo")
            model.goBack()
            #expect(model.plantOnServer && model.plantForbidden, "sola lettura, da aggiungere dopo")
        }

        // MARK: Slug

        @Test func theSlugFollowsTheNameAndIsCheckedNormalised() async throws {
            let model = try await model(status: Self.named)
            server.route("GET /v1/companies/check-slug?slug=acme-srl", .json(#"{"available":true,"slug":"acme-srl"}"#))
            model.companyName = "Acme Srl"
            #expect(model.slug == "acme-srl")
            #expect(model.slugState == .checking)
            #expect(await TestEnv.waitUntil { model.slugState == .available })
            #expect(await TestEnv.waitUntil { model.websiteStatus == .verified })
            #expect(!model.canCreateCompany, "il settore è obbligatorio, come sulla web")
            #expect(model.stillNeeded?.contains(String(localized: "the industry")) == true)
            model.industry = .energy
            #expect(model.canCreateCompany)
            #expect(model.stillNeeded == nil)
            let check = try #require(server.calls("GET /v1/companies/check-slug").last)
            #expect(check.header("company-id") == nil)

            // Toccato a mano, lo slug non segue più il nome; un carattere solo non si controlla.
            model.slug = "A"
            model.companyName = "Something else"
            #expect(model.slug == "a")
            #expect(model.slugState == .idle)
            #expect(!model.canCreateCompany)
        }

        @Test func aSlugCheckThatNeverAnswersDoesNotBlock() async throws {
            let app = AppViewModel()
            _ = try await newSignUp(status: .json(Self.named), on: app.backend)
            let model = AriaSignUpViewModel(app: app, slugDelay: .milliseconds(10), slugTimeout: .milliseconds(50),
                                            websiteDelay: .milliseconds(10), resolver: SignUpDomainStub(.found),
                                            isOnline: { true })
            await model.load()
            server.route("GET /v1/companies/check-slug?slug=acme", .json(#"{"available":true,"slug":"acme"}"#, delay: 5))
            model.companyName = "Acme"
            model.industry = .food
            #expect(await TestEnv.waitUntil { model.slugState == .failed })
            #expect(await TestEnv.waitUntil { model.websiteStatus == .verified })
            #expect(model.canCreateCompany, "la creazione ricontrolla lo slug, come la web")
        }

        // MARK: Sito web

        @Test func theWebsiteOpensWithTheEmailDomainAndIsCheckedWhenLeavingTheStep() async throws {
            let resolver = SignUpDomainStub(.found)
            let model = try await model(status: Self.named, resolver: resolver)
            #expect(model.website == "acme.test", "il dominio dell'email, come la web")
            #expect(await TestEnv.waitUntil { model.websiteStatus == .verified })
            #expect(resolver.lookups == ["acme.test"])
            await fillCompany(model)
            await model.continueFromStep()
            #expect(model.step == .plant)
            #expect(resolver.lookups.count == 2, "uscendo dal passo si ricontrolla, come il salvataggio della web")
            fillPlant(model)
            await model.continueFromStep()
            stubFinalRun()
            await model.finish()
            #expect(resolver.lookups.count == 2, "alla fine si scrive e basta: il sito è già verificato")
        }

        @Test func aMailboxProviderOrAMissingDomainBlocks() async throws {
            let resolver = SignUpDomainStub(.notFound)
            let model = try await model(status: Self.named, resolver: resolver)
            server.route("GET /v1/companies/check-slug?slug=acme", .json(#"{"available":true,"slug":"acme"}"#))
            model.companyName = "Acme"
            model.industry = .energy

            model.website = "www.gmail.com"
            #expect(await TestEnv.waitUntil { model.websiteStatus == .problem(.personal) })
            #expect(!model.canCreateCompany)
            #expect(model.stillNeeded?.contains(String(localized: "the company website")) == true)
            #expect(!resolver.lookups.contains("gmail.com"), "un provider non si chiede al DNS")

            model.website = "made-up-company.it"
            #expect(await TestEnv.waitUntil { model.websiteStatus == .problem(.notFound) })
            #expect(!model.canCreateCompany)
        }

        @Test func anUnverifiedWebsiteLetsTheButtonOnButLeavingTheStepRefusesIt() async throws {
            let resolver = SignUpDomainStub(.failed)
            let model = try await model(status: Self.named, resolver: resolver)
            server.route("GET /v1/companies/check-slug?slug=acme", .json(#"{"available":true,"slug":"acme"}"#))
            model.companyName = "Acme"
            model.industry = .energy
            #expect(await TestEnv.waitUntil { model.slugState == .available })
            #expect(await TestEnv.waitUntil { model.websiteStatus == .problem(.unverified) })
            #expect(model.canCreateCompany, "il DNS che non risponde non blocca il pulsante")

            await model.continueFromStep()
            #expect(model.step == .company, "si va avanti solo con il sito verificato")
            #expect(model.errorMessage == String(localized: AriaWebsiteProblem.unverified.message))

            resolver.answer(.found)
            await model.continueFromStep()
            #expect(model.step == .plant)
            #expect(model.websiteStatus == .verified)
            #expect(writes.isEmpty)
        }

        @Test func offlineTheWebsiteIsUnverifiedWithoutAskingTheDNS() async throws {
            let resolver = SignUpDomainStub(.notFound)
            let model = try await model(status: Self.named, resolver: resolver, online: false)
            #expect(await TestEnv.waitUntil { model.websiteStatus == .problem(.unverified) })
            #expect(resolver.lookups.isEmpty, "offline \"non esiste\" sarebbe falso")
        }

        @Test func aPastedAddressLosesItsScheme() async throws {
            let model = try await model(status: Self.named)
            model.website = "HTTPS://www.sinauragroup.com/it"
            #expect(model.website == "www.sinauragroup.com/it")
            #expect(await TestEnv.waitUntil { model.websiteStatus == .verified })
        }

        // MARK: Piano

        @Test func thePlanReadsThePublicPriceListOnce() async throws {
            let model = try await model(status: Self.owner)
            #expect(model.priceList == .loading)
            server.route("GET /v1/public/price-list", .json(#"{"published":false,"sales_contact_email":"sales@sinaura.com"}"#))
            await model.loadPriceList()
            await model.loadPriceList()
            #expect(model.priceList == .unavailable(salesEmail: "sales@sinaura.com"))
            let calls = server.calls("GET /v1/public/price-list")
            #expect(calls.count == 1)
            #expect(calls.first?.header("company-id") == nil, "rotta pubblica: l'azienda può non esserci")
            #expect(model.canFinish, "senza listino il pulsante resta attivo")
        }

        @Test func aPriceListThatFailsLeavesTheCardWithItsWords() async throws {
            let model = try await model(status: Self.owner)
            server.route("GET /v1/public/price-list", .json(#"{"detail":"boom"}"#, status: 500))
            await model.loadPriceList()
            #expect(model.priceList == .failed)
        }
    }
}

/// Il DNS finto del sito web aziendale: risponde quello che gli si dice e ricorda cosa gli è stato chiesto.
nonisolated final class SignUpDomainStub: AriaDomainResolving, @unchecked Sendable {
    private let lock = NSLock()
    private var reply: AriaDomainLookup
    private var asked: [String] = []

    init(_ reply: AriaDomainLookup) { self.reply = reply }

    func answer(_ reply: AriaDomainLookup) { lock.withLock { self.reply = reply } }

    var lookups: [String] { lock.withLock { asked } }

    func lookup(_ host: String) async -> AriaDomainLookup {
        lock.withLock {
            asked.append(host)
            return reply
        }
    }
}
