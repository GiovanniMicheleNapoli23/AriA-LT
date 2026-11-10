//
//  AccessRefreshTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 05/11/26.
//
//  Ruoli e diritti lato backend: il layout dell'operatore per la sessione dell'app di un membro, i diritti letti
//  da GET /v1/me e riletti da soli (403 `permission_denied`, nuova X-Access-Version, segnale da uno stream),
//  e cosa resta quando la lettura fallisce, si cambia azienda o si esce.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Access refresh")
    struct AccessRefresh {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        private static let withAssets = #"{"work_orders":{"granted":true,"actions":["complete"]},"assets":{"granted":true,"actions":[]}}"#

        /// Un account della piattaforma (senza `operatorProfile`): la membership decide il layout.
        private func platformAccount(restricted: Bool) async throws -> AriaBackend {
            TestEnv.stubSignIn()
            server.route("GET /v1/me", .json(#"{"id":"u1","name":"M","email":"m@a.b","membership":{"role":"member","restricted":\#(restricted)}}"#))
            let backend = AriaBackend()
            try await backend.useDeveloperToken(TestEnv.jwt())
            return backend
        }

        private func meCalls() -> Int { server.calls("GET /v1/me").count }

        // MARK: Layout

        @Test func aMemberAppSessionGetsTheOperatorLayout() async throws {
            let backend = try await platformAccount(restricted: true)
            #expect(backend.isAdmin, "l'account è della piattaforma")
            #expect(backend.usesOperatorLayout, "ma la sessione dell'app di un membro è ristretta")
        }

        @Test func anOwnerOrAdminKeepsTheFullLayout() async throws {
            let backend = try await platformAccount(restricted: false)
            #expect(backend.isAdmin)
            #expect(!backend.usesOperatorLayout)
        }

        @Test func aMobileOperatorAlwaysUsesTheOperatorLayout() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            #expect(!backend.isAdmin)
            #expect(backend.usesOperatorLayout)
        }

        // MARK: Lettura

        @Test func meRefreshReadsTheRoleForTheActiveCompany() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(), to: backend)

            #expect(backend.access?.role?.name == "Technician")
            #expect(backend.rights.isRoleBased && backend.rights.followsRole)
            #expect(backend.rights.has(.workOrders) && !backend.rights.has(.assets))
            #expect(backend.membership?.restricted == true)
            #expect(server.calls("GET /v1/me").last?.header("company-id") == "c1")
        }

        @Test func aBackendWithoutTheAccessBlockGrantsEverything() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(nil, to: backend)

            #expect(backend.access == nil)
            #expect(!backend.rights.isRoleBased)
            #expect(backend.rights.has(.assets) && backend.rights.can(.stepPhotos, in: .workOrders))
        }

        @Test func offlineTheLastRightsStayButARefusalDropsThem() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(), to: backend)

            server.route("GET /v1/me", .failing(.notConnectedToInternet))
            await backend.refreshMembership()
            #expect(backend.access?.role?.name == "Technician", "senza rete restano gli ultimi letti")

            server.route("GET /v1/me", .json(#"{"detail":"boom"}"#, status: 500))
            await backend.refreshMembership()
            #expect(backend.access == nil)
            #expect(backend.membership == nil)
        }

        // MARK: Rilettura da sola

        @Test func aDeniedCallRereadsTheRightsAndHidesWhatIsGone() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(sections: Self.withAssets), to: backend)
            #expect(backend.rights.has(.assets))

            // L'admin toglie Assets al ruolo: la prossima chiamata risponde 403 e /v1/me dice il ruolo nuovo.
            server.route("GET /v1/me", .json(#"{"id":"u1","membership":{"role":"member","restricted":true},"access":\#(TestEnv.accessJSON(version: "v2"))}"#))
            server.route("GET /v1/assets", .json(#"{"detail":{"code":"permission_denied","section":"assets","reason":"no_section"}}"#, status: 403))
            _ = try? await backend.api.data("GET", "v1/assets")

            #expect(await TestEnv.waitUntil { !backend.rights.has(.assets) })
            #expect(backend.access?.version == "v2")
            #expect(backend.isSignedIn, "un 403 del ruolo non è un logout")
            #expect(backend.activeCompanyId == "c1", "l'azienda resta")
        }

        @Test func aNewAccessVersionRereadsTheRightsAndTheSameOneDoesNot() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(version: "v1"), to: backend)
            let before = meCalls()

            server.route("GET /v1/plants", .json("[]", headers: ["X-Access-Version": "v1"]))
            _ = try await backend.api.data("GET", "v1/plants")
            try await Task.sleep(for: .milliseconds(100))
            #expect(meCalls() == before, "stessa versione: niente da rileggere")

            server.route("GET /v1/plants", .json("[]", headers: ["X-Access-Version": "v2"]))
            _ = try await backend.api.data("GET", "v1/plants")
            #expect(await TestEnv.waitUntil { meCalls() == before + 1 })
        }

        @Test func anActionTakenAwayAndGivenBackComesBack() async throws {
            let approve = #"{"alarms":{"granted":true,"actions":["approve"]}}"#
            let without = #"{"alarms":{"granted":true,"actions":[]}}"#
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(sections: approve, version: "v1"), to: backend)
            #expect(backend.rights.can(.approve, in: .alarms))

            // L'admin toglie "approve": la prossima risposta porta la versione nuova.
            server.route("GET /v1/me", .json(#"{"id":"u1","membership":{"role":"member","restricted":true},"access":\#(TestEnv.accessJSON(sections: without, version: "v2"))}"#))
            server.route("GET /v1/alarms", .json("[]", headers: ["X-Access-Version": "v2"]))
            _ = try await backend.api.data("GET", "v1/alarms")
            #expect(await TestEnv.waitUntil { !backend.rights.can(.approve, in: .alarms) })

            // E lo ridà.
            server.route("GET /v1/me", .json(#"{"id":"u1","membership":{"role":"member","restricted":true},"access":\#(TestEnv.accessJSON(sections: approve, version: "v3"))}"#))
            server.route("GET /v1/alarms", .json("[]", headers: ["X-Access-Version": "v3"]))
            _ = try await backend.api.data("GET", "v1/alarms")
            #expect(await TestEnv.waitUntil { backend.rights.can(.approve, in: .alarms) })
        }

        @Test func withoutAnyCallTheRightsAreRereadOnTheirOwn() async throws {
            let approve = #"{"alarms":{"granted":true,"actions":["approve"]}}"#
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(sections: #"{"alarms":{"granted":true,"actions":[]}}"#), to: backend)
            #expect(!backend.rights.can(.approve, in: .alarms))

            // Il ruolo ridà "approve" mentre la schermata è ferma: nessuna chiamata porta la versione nuova.
            server.route("GET /v1/me", .json(#"{"id":"u1","membership":{"role":"member","restricted":true},"access":\#(TestEnv.accessJSON(sections: approve, version: "v2"))}"#))
            let watch = Task { await backend.watchAccess(every: .milliseconds(50)) }
            defer { watch.cancel() }

            #expect(await TestEnv.waitUntil { backend.rights.can(.approve, in: .alarms) })
        }

        @Test func theWatchStopsWhenItsTaskEnds() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(), to: backend)
            let before = meCalls()
            let watch = Task { await backend.watchAccess(every: .milliseconds(30)) }
            #expect(await TestEnv.waitUntil { meCalls() >= before + 2 }, "una lettura a ogni giro")
            watch.cancel()
            await watch.value
            let after = meCalls()
            try await Task.sleep(for: .milliseconds(150))
            #expect(meCalls() == after, "l'app in background non rilegge")
        }

        @Test func aSignalFromAStreamRereadsTheRights() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(), to: backend)
            let before = meCalls()

            backend.accessMayHaveChanged()

            #expect(await TestEnv.waitUntil { meCalls() == before + 1 })
        }

        @Test func featuresHiddenForTheOperatorComeBackWhenTheSessionFollowsTheRole() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(followsRole: false), to: backend)
            backend.markUnavailable(.suggestions, ifRefused: AriaError.notOnPhone)
            #expect(!backend.isAvailable(.suggestions))

            await TestEnv.grant(TestEnv.accessJSON(followsRole: false), to: backend)
            #expect(!backend.isAvailable(.suggestions), "stessi limiti: resta nascosta")

            await TestEnv.grant(TestEnv.accessJSON(followsRole: true), to: backend)
            #expect(backend.isAvailable(.suggestions), "i limiti dell'operatore non valgono più: si riprova")
        }

        // MARK: Azienda e uscita

        @Test func anotherCompanyHasItsOwnRights() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(), to: backend)

            server.route("GET /v1/me", .json(#"{"id":"u1","membership":{"role":"member","restricted":true},"access":\#(TestEnv.accessJSON(role: nil))}"#))
            await backend.selectCompany("c2")

            #expect(server.calls("GET /v1/me").last?.header("company-id") == "c2")
            #expect(backend.rights.isPaused, "in c2 non ha un ruolo")
        }

        @Test func signingOutForgetsTheRights() async throws {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(TestEnv.accessJSON(), to: backend)
            server.route("POST /api/auth/sign-out", .json("{}"))

            await backend.signOut()

            #expect(backend.access == nil)
            #expect(backend.membership == nil)
            #expect(!backend.rights.isRoleBased)
        }
    }
}
