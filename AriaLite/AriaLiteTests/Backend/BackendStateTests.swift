//
//  BackendStateTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  AriaBackend: accesso completo (il link vale solo per la richiesta fatta da questo dispositivo),
//  profilo nel Keychain e link in attesa, sessioni di versioni precedenti, scelta di azienda e stabilimento, uscita.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Backend state")
    struct BackendState {
        private let server = StubServer.shared
        private let defaults = UserDefaults.standard

        init() { TestEnv.reset() }

        // MARK: Accesso

        @Test func completeSignInOpensTheSessionAndLoadsCompanyAndPlant() async throws {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            #expect(!backend.isSignedIn)

            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))

            #expect(backend.isSignedIn)
            #expect(backend.mobileAccount == AriaMobileAccount(id: "u1", name: "Mario Rossi", email: "mario@acme.test"))
            #expect(backend.activeCompanyId == "c1")
            #expect(backend.activePlantId == "p1")
            #expect(backend.isReady)
            #expect(backend.activePlantName == "Plant 1")
            #expect(backend.lastError == nil)
            #expect(server.calls("GET /v1/companies").first?.host == AriaConfig.productionAPI.host())
            #expect(server.calls("GET /v1/companies").first?.header("company-id") == nil, "le aziende si chiedono senza Company-Id")
        }

        @Test func accountSurvivesARelaunch() async throws {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))

            let relaunched = AriaBackend()
            #expect(relaunched.isSignedIn)
            #expect(relaunched.mobileAccount?.email == "mario@acme.test")
            #expect(relaunched.activeCompanyId == "c1" && relaunched.activePlantId == "p1")
        }

        @Test func signInClearsThePendingLink() async throws {
            server.route("POST /api/auth/mobile/request-link", .json("{}", status: 202))
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            try await backend.sendSignInLink(email: "mario@acme.test")
            #expect(backend.pendingLinkEmail != nil)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(backend.pendingLinkEmail == nil)
            #expect(defaults.string(forKey: "aria.magic_link_email") == nil)
        }

        @Test func failedLinkKeepsTheOperatorSignedOut() async throws {
            server.route("POST /api/auth/mobile/verify", .json(#"{"code":"INVALID_OR_EXPIRED_LINK"}"#, status: 401))
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            await #expect(throws: AriaError.self) { try await backend.completeSignIn(with: AriaSignInLink(token: "t")) }
            #expect(!backend.isSignedIn && backend.mobileAccount == nil)
        }

        @Test func linkWithoutARequestFromThisDeviceIsRefusedWithoutCallingTheServer() async {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            await #expect { try await backend.completeSignIn(with: AriaSignInLink(token: "attacker")) } throws: { error in
                guard case AriaSignInError.noPendingRequest? = error as? AriaSignInError else { return false }
                return true
            }
            #expect(server.calls.isEmpty, "il token non si consuma")
            #expect(!backend.isSignedIn && backend.mobileAccount == nil)
            #expect(!AriaKeychain.exists("aria.mobile_session"))
        }

        @Test func linkOfAnotherAccountIsRevokedAndLeavesThePendingRequest() async throws {
            TestEnv.stubSignIn()
            server.route("POST /api/auth/sign-out", .json("{}"))
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend, email: "luigi@acme.test")

            await #expect { try await backend.completeSignIn(with: AriaSignInLink(token: "attacker")) } throws: { error in
                guard case AriaSignInError.accountMismatch? = error as? AriaSignInError else { return false }
                return true
            }

            #expect(server.calls("POST /api/auth/sign-out").first?.header("authorization") == "Bearer SESSION")
            #expect(!backend.isSignedIn && backend.mobileAccount == nil)
            #expect(!AriaKeychain.exists("aria.mobile_session"))
            #expect(AriaKeychain.get("aria.operator_account") == nil)
            #expect(backend.pendingLinkEmail == "luigi@acme.test", "l'utente può ancora aprire il link giusto")
            #expect(server.calls("GET /v1/companies").isEmpty)
        }

        @Test func requestedEmailIsComparedIgnoringCase() async throws {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend, email: "Mario@Acme.TEST")
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(backend.isSignedIn && backend.mobileAccount?.email == "mario@acme.test")
        }

        @Test func accountWithoutCompaniesIsSignedOutAgain() async throws {
            TestEnv.stubSignIn(companies: "[]")
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(!backend.isSignedIn, "la membership non è più attiva")
            #expect(!AriaKeychain.exists("aria.mobile_session"))
            #expect(backend.lastError != nil)
        }

        @Test func bootstrapPrefersTheSavedCompanyThenTheOwnedOne() async throws {
            let two = #"[{"id":"c1","name":"A","myRole":"member"},{"id":"c2","name":"B","myRole":"owner"}]"#
            TestEnv.stubSignIn(companies: two)
            let owned = AriaBackend()
            try await TestEnv.requestLink(owned)
            try await owned.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(owned.activeCompanyId == "c2")

            TestEnv.reset()
            defaults.set("c1", forKey: "aria.company_id")
            TestEnv.stubSignIn(companies: two)
            let saved = AriaBackend()
            try await TestEnv.requestLink(saved)
            try await saved.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(saved.activeCompanyId == "c1")
        }

        @Test func plantsFailingDoesNotBreakTheWorkOrders() async throws {
            TestEnv.stubSignIn(plants: .json(#"{"detail":"nope"}"#, status: 403))
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(backend.isSignedIn)
            #expect(backend.activeCompanyId == "c1", "i lavori non hanno bisogno degli stabilimenti")
            #expect(backend.plants.isEmpty && backend.activePlantId == nil)
            #expect(!backend.isReady, "la chat sì")
        }

        @Test func companiesNetworkFailureKeepsTheSessionAndExplains() async throws {
            TestEnv.stubSignIn()
            server.route("GET /v1/companies", .failing(.notConnectedToInternet))
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(backend.isSignedIn)
            #expect(backend.lastError != nil)
            #expect(backend.activeCompanyId == nil)

            server.route("GET /v1/companies", .json(#"[{"id":"c1","name":"Acme","myRole":"member"}]"#))
            await backend.bootstrapIfNeeded()
            #expect(backend.activeCompanyId == "c1" && backend.lastError == nil)
        }

        @Test func bootstrapRunsOnlyOnceWhenAlreadyDone() async throws {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            let before = server.calls("GET /v1/companies").count
            await backend.bootstrapIfNeeded()
            await backend.bootstrapIfNeeded()
            #expect(server.calls("GET /v1/companies").count == before)
        }

        // MARK: Link in attesa

        @Test func sendingALinkNormalizesTheEmailAndRemembersIt() async throws {
            server.route("POST /api/auth/mobile/request-link", .json("{}", status: 202))
            let backend = AriaBackend()
            try await backend.sendSignInLink(email: "  Mario@Acme.TEST \n")
            #expect(backend.pendingLinkEmail == "mario@acme.test")
            #expect(server.calls("POST /api/auth/mobile/request-link").first?.json as? [String: String] == ["email": "mario@acme.test"])
            #expect(defaults.object(forKey: "aria.magic_link_sent_at") is Date)
        }

        @Test func aRejectedRequestLeavesNoPendingLink() async {
            server.route("POST /api/auth/mobile/request-link", .json("{}", status: 429))
            let backend = AriaBackend()
            await #expect(throws: AriaError.self) { try await backend.sendSignInLink(email: "a@b.c") }
            #expect(backend.pendingLinkEmail == nil)
        }

        @Test func pendingLinkSurvivesARelaunchWithinFifteenMinutes() {
            defaults.set("mario@acme.test", forKey: "aria.magic_link_email")
            defaults.set(Date.now.addingTimeInterval(-14 * 60), forKey: "aria.magic_link_sent_at")
            #expect(AriaBackend().pendingLinkEmail == "mario@acme.test")
        }

        @Test func pendingLinkExpiresAfterFifteenMinutes() {
            defaults.set("mario@acme.test", forKey: "aria.magic_link_email")
            defaults.set(Date.now.addingTimeInterval(-16 * 60), forKey: "aria.magic_link_sent_at")
            #expect(AriaBackend().pendingLinkEmail == nil)
        }

        @Test func cancellingThePendingLinkForgetsIt() async throws {
            server.route("POST /api/auth/mobile/request-link", .json("{}", status: 202))
            let backend = AriaBackend()
            try await backend.sendSignInLink(email: "a@b.c")
            backend.cancelPendingLink()
            #expect(backend.pendingLinkEmail == nil)
            #expect(AriaBackend().pendingLinkEmail == nil)
        }

        // MARK: Sessioni di versioni precedenti

        @Test func sessionWithoutAProfileIsDroppedAtLaunch() {
            AriaKeychain.set("OLD-USERNAME-SESSION", for: "aria.mobile_session")
            let backend = AriaBackend()
            #expect(!backend.isSignedIn)
            #expect(!AriaKeychain.exists("aria.mobile_session"))
        }

        @Test func oldProfileFormatIsIgnored() {
            AriaKeychain.set("S", for: "aria.mobile_session")
            defaults.set(Data(#"{"id":"1","name":"M","username":"acme.mario","displayUsername":"mario"}"#.utf8),
                         forKey: "aria.mobile_account")
            #expect(!AriaBackend().isSignedIn, "il profilo con l'username non è quello nuovo")
        }

        @Test func sessionWithItsProfileIsKept() throws {
            TestEnv.markInstalled()
            AriaKeychain.set("S", for: "aria.mobile_session")
            let account = AriaMobileAccount(id: "u1", name: "M", email: "m@a.b")
            AriaKeychain.set(String(decoding: try JSONEncoder().encode(account), as: UTF8.self), for: "aria.operator_account")
            let backend = AriaBackend()
            #expect(backend.isSignedIn)
            #expect(backend.mobileAccount == account)
        }

        @Test func profileWithoutASessionIsNotShown() throws {
            let account = AriaMobileAccount(id: "u1", name: "M", email: "m@a.b")
            AriaKeychain.set(String(decoding: try JSONEncoder().encode(account), as: UTF8.self), for: "aria.operator_account")
            let backend = AriaBackend()
            #expect(!backend.isSignedIn && backend.mobileAccount == nil)
        }

        @Test func profileInUserDefaultsMovesToTheKeychain() throws {
            AriaKeychain.set("S", for: "aria.mobile_session")
            let account = AriaMobileAccount(id: "u1", name: "M", email: "m@a.b")
            defaults.set(try JSONEncoder().encode(account), forKey: "aria.operator_account")
            let backend = AriaBackend()
            #expect(backend.isSignedIn && backend.mobileAccount == account)
            #expect(defaults.object(forKey: "aria.operator_account") == nil, "nome ed email non restano nel plist")
            #expect(AriaKeychain.get("aria.operator_account") != nil)
            #expect(AriaBackend().mobileAccount == account)
            #expect(defaults.bool(forKey: "aria.install_marker"))
        }

        @Test func keychainLeftByAnUninstalledAppIsForgotten() throws {
            AriaKeychain.set("S", for: "aria.mobile_session")
            AriaKeychain.set("T", for: "aria.dev_access_token")
            let account = AriaMobileAccount(id: "u1", name: "M", email: "m@a.b")
            AriaKeychain.set(String(decoding: try JSONEncoder().encode(account), as: UTF8.self), for: "aria.operator_account")
            let backend = AriaBackend()
            #expect(!backend.isSignedIn && backend.mobileAccount == nil)
            TestEnv.keychainAccounts.forEach { #expect(!AriaKeychain.exists($0), "\($0) resta nel Keychain") }
            #expect(defaults.bool(forKey: "aria.install_marker"))
        }

        @Test func profileIsNeverWrittenToUserDefaults() async throws {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            #expect(defaults.object(forKey: "aria.operator_account") == nil)
            #expect(AriaKeychain.get("aria.operator_account")?.contains("mario@acme.test") == true)
        }

        // MARK: Selezione e uscita

        @Test func selectingPlantAndCompanyPersists() async throws {
            TestEnv.stubSignIn(plants: .json(#"[{"id":"p1","name":"One","code":null},{"id":"p2","name":"Two","code":null}]"#))
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            await backend.selectPlant("p2")
            #expect(backend.activePlantId == "p2" && backend.activePlantName == "Two")
            #expect(defaults.string(forKey: "aria.plant_id") == "p2")
        }

        @Test func signOutCallsTheServerAndWipesEveryTrace() async throws {
            TestEnv.stubSignIn()
            server.route("POST /api/auth/sign-out", .json("{}"))
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))

            await backend.signOut()

            #expect(server.calls("POST /api/auth/sign-out").first?.header("authorization") == "Bearer SESSION")
            #expect(!backend.isSignedIn && backend.mobileAccount == nil)
            #expect(backend.companies.isEmpty && backend.plants.isEmpty)
            #expect(backend.activeCompanyId == nil && backend.activePlantId == nil)
            #expect(!AriaKeychain.exists("aria.mobile_session"))
            #expect(AriaKeychain.get("aria.operator_account") == nil)
            #expect(!AriaBackend().isSignedIn)
        }

        @Test func handlingSignedOutResetsTheSessionState() async throws {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            backend.handle(AriaError.signedOut)
            #expect(!backend.isSignedIn && backend.mobileAccount == nil)
            #expect(backend.lastError != nil)
        }

        @Test func lockedSessionIsNotAnErrorToShow() {
            let backend = AriaBackend()
            backend.handle(AriaError.locked)
            #expect(backend.lastError == nil, "la schermata di sblocco è già davanti")
        }

        @Test func suggestionsAreEmptyWithoutAPlant() async {
            #expect(await AriaBackend().suggestions().isEmpty)
            #expect(server.calls.isEmpty)
        }
    }
}
