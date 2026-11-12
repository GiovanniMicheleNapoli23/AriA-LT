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

        private func model(status: String = SignUp.fresh) async throws -> AriaSignUpViewModel {
            let app = AppViewModel()
            _ = try await newSignUp(status: .json(status), on: app.backend)
            let model = AriaSignUpViewModel(app: app, slugDelay: .milliseconds(10))
            await model.load()
            return model
        }

        @Test func profileSendsTheWebFieldsThenGoesToCompany() async throws {
            let model = try await model()
            #expect(model.step == .profile)
            #expect(!model.canSaveProfile, "nome e ruolo sono obbligatori")

            server.route("PATCH /v1/me", .json(#"{"id":"u1","name":"Maria Rossi","email":"mario@acme.test"}"#))
            server.route("GET /v1/onboarding/status", .json(Self.named))
            model.name = "  Maria Rossi "
            model.jobRole = .maintenanceEngineer
            await model.saveProfile()

            let patch = try #require(server.calls("PATCH /v1/me").first)
            #expect(patch.header("company-id") == nil)
            #expect(patch.json?["name"] as? String == "Maria Rossi")
            #expect(patch.json?["jobRole"] as? String == "maintenance_engineer")
            #expect(patch.json?["preferredLocale"] as? String == AriaSignUpLocale.current)
            #expect(patch.json?.keys.contains("phone") == false, "un telefono vuoto non si manda")
            #expect(patch.json?.keys.contains("onboardingComplete") == false)
            #expect(model.step == .company)
            #expect(model.app.backend.mobileAccount?.name == "Maria Rossi")
        }

        @Test func theSlugFollowsTheNameAndIsCheckedNormalised() async throws {
            let model = try await model(status: Self.named)
            server.route("GET /v1/companies/check-slug?slug=acme-srl", .json(#"{"available":true,"slug":"acme-srl"}"#))
            model.companyName = "Acme Srl"
            #expect(model.slug == "acme-srl")
            #expect(model.slugState == .checking)
            #expect(await TestEnv.waitUntil { model.slugState == .available })
            #expect(model.canCreateCompany)
            let check = try #require(server.calls("GET /v1/companies/check-slug").last)
            #expect(check.header("company-id") == nil)

            // Toccato a mano, lo slug non segue più il nome; un carattere solo non si controlla.
            model.slug = "A"
            model.companyName = "Something else"
            #expect(model.slug == "a")
            #expect(model.slugState == .idle)
            #expect(!model.canCreateCompany)
        }

        @Test func aRefusedCompanyThatAlreadyExistsGoesOnToPlan() async throws {
            let model = try await model(status: Self.named)
            server.route("GET /v1/companies/check-slug?slug=acme", .json(#"{"available":true,"slug":"acme"}"#))
            model.companyName = "Acme"
            #expect(await TestEnv.waitUntil { model.slugState == .available })

            server.route("POST /v1/companies", .json(#"{"detail":{"code":"operator_identity_forbidden","message":"no"}}"#, status: 403))
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            await model.createCompany()
            #expect(model.step == .plan, "la risposta della prima creazione si era persa")
            #expect(model.blockingMessage == nil)
            let create = try #require(server.calls("POST /v1/companies").first)
            #expect(create.json?["slug"] as? String == "acme")
            #expect(create.json?.keys.contains("plan") == false)
            #expect(create.json?.keys.contains("industry") == false, "senza scelta non si manda")
        }

        @Test func aRefusedCompanyWithoutOneSendsThePersonToTheWeb() async throws {
            let model = try await model(status: Self.named)
            server.route("GET /v1/companies/check-slug?slug=acme", .json(#"{"available":true,"slug":"acme"}"#))
            model.companyName = "Acme"
            #expect(await TestEnv.waitUntil { model.slugState == .available })

            server.route("POST /v1/companies", .json(#"{"detail":{"code":"operator_identity_forbidden","message":"no"}}"#, status: 403))
            await model.createCompany()
            #expect(model.step == .company)
            #expect(model.blockingMessage != nil)
        }

        @Test func aSlugTakenMeanwhileAsksForAnother() async throws {
            let model = try await model(status: Self.named)
            server.route("GET /v1/companies/check-slug?slug=acme",
                         .json(#"{"available":true,"slug":"acme"}"#), .json(#"{"available":false,"slug":"acme"}"#))
            model.companyName = "Acme"
            #expect(await TestEnv.waitUntil { model.slugState == .available })

            server.route("POST /v1/companies", .json(#"{"error":{"type":"internal_error","message":"An unexpected error occurred","code":500}}"#, status: 500))
            await model.createCompany()
            #expect(model.slugState == .taken)
            #expect(model.errorMessage != nil)
            #expect(!model.canCreateCompany)
        }

        // MARK: Primo stabilimento

        nonisolated static let acme = #"{"id":"c9","name":"Acme","myRole":"owner","onboardingCompleted":false}"#

        @Test func aNewCompanyAsksForItsFirstPlantThenThePlan() async throws {
            let model = try await model(status: Self.named)
            server.route("GET /v1/companies/check-slug?slug=acme", .json(#"{"available":true,"slug":"acme"}"#))
            model.companyName = "Acme"
            #expect(await TestEnv.waitUntil { model.slugState == .available })

            server.route("POST /v1/companies", .json(Self.acme, status: 201))
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            server.route("GET /v1/plants", .json("[]"), .json(#"[{"id":"p1","name":"Main plant","code":"MAIN"}]"#))
            await model.createCompany()
            #expect(model.step == .plant)
            let list = try #require(server.calls("GET /v1/plants").first)
            #expect(list.header("company-id") == "c9", "l'azienda appena creata, non quella del contesto")
            #expect(!model.canCreatePlant, "nome e codice sono obbligatori")

            server.route("POST /v1/plants", .json(#"{"id":"p1","name":"Main plant","code":"MAIN"}"#, status: 201))
            model.plantName = " Main plant "
            model.plantCode = " MAIN "
            await model.createPlant()

            let create = try #require(server.calls("POST /v1/plants").first)
            #expect(create.header("company-id") == "c9")
            #expect(create.json?["name"] as? String == "Main plant")
            #expect(create.json?["code"] as? String == "MAIN")
            #expect(create.json?["location"] == nil, "un campo vuoto non si manda")
            #expect(model.step == .plan)
            #expect(!model.isSaving)
        }

        @Test func backAfterARelaunchTheCompanyWithoutPlantsAsksForOne() async throws {
            TestEnv.stubSignIn(companies: "[\(Self.acme)]", plants: .json("[]"))
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            let app = AppViewModel()
            try await TestEnv.requestLink(app.backend)
            try await app.backend.completeSignIn(with: AriaSignInLink(token: "t"))
            let model = AriaSignUpViewModel(app: app)
            await model.load()
            #expect(model.step == .plant)
            #expect(server.calls("GET /v1/plants").last?.header("company-id") == "c9")
        }

        @Test func aRefusedPlantStaysOnThePlantStepWithTheServerText() async throws {
            TestEnv.stubSignIn(companies: "[\(Self.acme)]", plants: .json("[]"))
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            let app = AppViewModel()
            try await TestEnv.requestLink(app.backend)
            try await app.backend.completeSignIn(with: AriaSignInLink(token: "t"))
            let model = AriaSignUpViewModel(app: app)
            await model.load()

            server.route("POST /v1/plants", .json(#"{"detail":"A plant with this code already exists"}"#, status: 409))
            model.plantName = "Main"
            model.plantCode = "MAIN"
            await model.createPlant()
            #expect(model.step == .plant, "l'azienda c'è già: mai indietro al passo Azienda")
            #expect(model.errorMessage == "A plant with this code already exists")
        }

        @Test func aPlantRefusedForRightsGoesOnToThePlan() async throws {
            TestEnv.stubSignIn(companies: "[\(Self.acme)]", plants: .json("[]"))
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            let app = AppViewModel()
            try await TestEnv.requestLink(app.backend)
            try await app.backend.completeSignIn(with: AriaSignInLink(token: "t"))
            let model = AriaSignUpViewModel(app: app)
            await model.load()

            server.route("POST /v1/plants", .json(#"{"detail":"forbidden"}"#, status: 403))
            model.plantName = "Main"
            model.plantCode = "MAIN"
            await model.createPlant()
            #expect(model.step == .plan, "chi ha appena creato l'azienda non resta fermo: lo offre l'avviso della chat")
            #expect(model.errorMessage == nil)
        }

        @Test func aRetryAfterACreatedPlantDoesNotCreateItAgain() async throws {
            TestEnv.stubSignIn(companies: "[\(Self.acme)]", plants: .json("[]"))
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            let app = AppViewModel()
            try await TestEnv.requestLink(app.backend)
            try await app.backend.completeSignIn(with: AriaSignInLink(token: "t"))
            let model = AriaSignUpViewModel(app: app)
            await model.load()

            server.route("POST /v1/plants", .json(#"{"id":"p1","name":"Main","code":"MAIN"}"#, status: 201))
            server.route("GET /v1/onboarding/status", .json(#"{"detail":"boom"}"#, status: 500), .json(Self.owner))
            model.plantName = "Main"
            model.plantCode = "MAIN"
            await model.createPlant()
            #expect(model.step == .plant)
            #expect(model.errorMessage != nil)

            await model.createPlant()
            #expect(server.calls("POST /v1/plants").count == 1, "creato una volta sola")
            #expect(model.step == .plan)
        }

        @Test func plantsThatCantBeReadBeforeThePlanSkipToThePlan() async throws {
            TestEnv.stubSignIn(companies: "[\(Self.acme)]", plants: .json(#"{"detail":"forbidden"}"#, status: 403))
            server.route("GET /v1/onboarding/status", .json(Self.owner))
            let app = AppViewModel()
            try await TestEnv.requestLink(app.backend)
            try await app.backend.completeSignIn(with: AriaSignInLink(token: "t"))
            let model = AriaSignUpViewModel(app: app)
            await model.load()
            #expect(model.step == .plan, "l'avviso della chat offre comunque di aggiungerlo")
        }

        @Test func finishingWithoutACompanyGoesBackToCompany() async throws {
            let model = try await model(status: Self.owner)
            #expect(model.step == .plan)
            server.route("POST /api/auth/onboarding/finish", .json(#"{"code":"no_company","message":"x"}"#, status: 409))
            await model.finish()
            #expect(model.step == .company)
            #expect(!model.isSaving)
        }
    }
}
