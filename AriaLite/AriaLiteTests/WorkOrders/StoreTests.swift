//
//  StoreTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  AriaWorkOrderStore: sincronizzazione della lista e della disponibilità, dettaglio, modifiche ai passi
//  con ricarica dell'ordine, completamento, e cosa succede quando la sessione finisce o la rete cade.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Work order store")
    struct Store {
        private let server = StubServer.shared
        private let openKey = "GET /v1/mobile/work-orders?status=open&limit=50"
        private let closedKey = "GET /v1/mobile/work-orders?status=closed&limit=200"

        init() { TestEnv.reset() }

        private func meJSON(_ availability: String = "available") -> String {
            #"{"id":"u1","name":"M","email":"m@a.b","specialties":[],"availability":"\#(availability)","availabilityAt":"2026-10-09T07:00:00Z"}"#
        }

        private func stubHome(open: [String] = [], closed: [String] = [], availability: String = "available") {
            server.route("PUT /v1/mobile/me/availability", .json(meJSON(availability)))
            server.route("GET /v1/mobile/me", .json(meJSON(availability)))
            server.route(openKey, .json("[\(open.joined(separator: ","))]"))
            server.route(closedKey, .json("[\(closed.joined(separator: ","))]"))
        }

        // MARK: Sincronizzazione

        @Test func syncRenewsAvailabilityThenLoadsOpenAndClosedOrders() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1"), TestEnv.orderJSON(id: "o2")],
                     closed: [TestEnv.orderJSON(id: "c1", status: "completed")])

            await store.sync()

            #expect(store.profile?.availability == .available)
            #expect(store.orders.map(\.id) == ["o1", "o2"], "l'ordine è quello del server")
            #expect(store.closedOrders.map(\.id) == ["c1"])
            #expect(store.hasLoaded && store.hasLoadedClosed)
            #expect(store.lastUpdated != nil)
            #expect(store.errorMessage == nil && !store.isLoading)
            let put = try #require(server.calls("PUT /v1/mobile/me/availability").first)
            #expect(put.json as? [String: String] == ["availability": "available"])
        }

        @Test func syncWithABusyPreferenceOnlyReadsTheProfile() async throws {
            UserDefaults.standard.set("busy", forKey: "aria.availability_preference")
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(availability: "busy")

            await store.sync()

            #expect(server.calls("PUT /v1/mobile/me/availability").isEmpty, "busy e off_duty non scadono: niente rinnovo")
            #expect(server.calls("GET /v1/mobile/me").count == 1)
            #expect(store.profile?.availability == .busy)
        }

        @Test func everyForegroundRestartsTheTwelveHours() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome()
            await store.sync()
            await store.sync()
            #expect(server.calls("PUT /v1/mobile/me/availability").count == 2)
        }

        @Test func pullToRefreshReloadsWithoutRenewingAvailability() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON()])
            await store.refresh()
            #expect(server.calls("PUT /v1/mobile/me/availability").isEmpty)
            #expect(server.calls("GET /v1/mobile/me").count == 1)
            #expect(store.orders.count == 1)
        }

        @Test func listRequestsUseTheContractQueries() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome()
            await store.sync()
            #expect(server.calls("GET /v1/mobile/work-orders").map(\.query) == ["status=open&limit=50", "status=closed&limit=200"])
            #expect(server.calls("GET /v1/mobile/work-orders").allSatisfy { $0.header("company-id") == "c1" })
        }

        @Test func signedOutStoreDoesNothing() async {
            let store = AriaWorkOrderStore(backend: AriaBackend())
            await store.sync()
            await store.refresh()
            #expect(server.calls.isEmpty)
            #expect(!store.hasLoaded)
        }

        // MARK: Disponibilità

        @Test func changingAvailabilityPersistsTheChoiceAndReloadsTheList() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(availability: "off_duty")
            await store.setAvailability(.offDuty)
            #expect(store.preferredAvailability == .offDuty)
            #expect(UserDefaults.standard.string(forKey: "aria.availability_preference") == "off_duty")
            #expect(server.calls("PUT /v1/mobile/me/availability").first?.json as? [String: String] == ["availability": "off_duty"])
            #expect(!server.calls("GET /v1/mobile/work-orders").isEmpty, "cambia la disponibilità, cambia cosa arriva")
            #expect(!store.isUpdatingAvailability)
        }

        @Test func serverRefusingTheChangeKeepsThePreviousChoice() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome()
            server.route("PUT /v1/mobile/me/availability", .json(#"{"detail":"bad"}"#, status: 422))
            await store.setAvailability(.busy)
            #expect(store.preferredAvailability == .available)
            #expect(UserDefaults.standard.string(forKey: "aria.availability_preference") == nil)
            #expect(store.errorMessage != nil)
        }

        @Test func choosingTheCurrentAvailabilityIsANoOp() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            await store.setAvailability(.available)
            #expect(server.calls("PUT /v1/mobile/me/availability").isEmpty)
        }

        // MARK: Dettaglio

        @Test func detailRefreshesTheListEntry() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1", title: "Old")])
            await store.sync()
            server.route("GET /v1/mobile/work-orders/o1", .json(TestEnv.orderJSON(id: "o1", title: "New", withProcedure: true)))

            guard case .found(let order)? = await store.detail(of: "o1") else { Issue.record("atteso .found"); return }

            #expect(order.procedure?.steps.count == 2)
            #expect(store.orders.first?.title == "New")
        }

        @Test func reassignedOrderDisappearsWithoutAnError() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1"), TestEnv.orderJSON(id: "o2")])
            await store.sync()
            server.route("GET /v1/mobile/work-orders/o1", .json(#"{"detail":"Not found"}"#, status: 404))

            guard case .gone? = await store.detail(of: "o1") else { Issue.record("atteso .gone"); return }

            #expect(store.orders.map(\.id) == ["o2"])
            #expect(store.errorMessage == nil, "404 sul dettaglio non è un errore da mostrare")
        }

        // MARK: Passi

        @Test func reportingAStepSendsTheResultThenReloadsTheOrder() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(TestEnv.stepJSON()))
            server.route("GET /v1/mobile/work-orders/o1", .json(TestEnv.orderJSON(withProcedure: true, reported: 1)))

            let change = await store.report(.done(note: nil), step: "s1", of: "o1")

            #expect(change.order?.procedure?.steps.first?.report?.isDone == true)
            let sequence = server.calls.map { "\($0.method) \($0.path)" }.filter { $0.contains("work-orders") }
            #expect(sequence == ["PUT /v1/mobile/work-orders/o1/steps/s1", "GET /v1/mobile/work-orders/o1"])
        }

        @Test func notDoneWithoutAReasonFailsLocallyWithAReadableMessage() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            let before = server.calls.count
            let change = await store.report(.notDone(note: ""), step: "s1", of: "o1")
            #expect(change.failureMessage == AriaServerCode.noteRequired.localized)
            #expect(server.calls.count == before)
        }

        @Test func stepRemovedOnTheDesktopReloadsTheOrderAndReportsFailure() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1", title: "Before")])
            await store.sync()
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1",
                         .json(#"{"detail":{"code":"step_not_found","message":"m"}}"#, status: 404))
            server.route("GET /v1/mobile/work-orders/o1", .json(TestEnv.orderJSON(id: "o1", title: "After", withProcedure: true)))

            let change = await store.report(.done(note: nil), step: "s1", of: "o1")

            #expect(change.failureMessage == AriaServerCode.stepNotFound.localized)
            #expect(store.orders.first?.title == "After", "l'ordine è stato ricaricato")
        }

        @Test func closedOrderReloadsAndRefusesTheChange() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1",
                         .json(#"{"detail":{"code":"work_order_closed","message":"m"}}"#, status: 409))
            server.route("GET /v1/mobile/work-orders/o1", .json(TestEnv.orderJSON(status: "completed", withProcedure: true)))
            let change = await store.report(.done(note: nil), step: "s1", of: "o1")
            #expect(change.failureMessage == AriaServerCode.workOrderClosed.localized)
            #expect(server.calls("GET /v1/mobile/work-orders/o1").count == 1)
        }

        @Test func orderNoLongerOursOnAStepCallIsGoneAndRemoved() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1")])
            await store.sync()
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(#"{"detail":"Not found"}"#, status: 404))
            let change = await store.report(.done(note: nil), step: "s1", of: "o1")
            #expect(change.isGone)
            #expect(store.orders.isEmpty)
        }

        @Test func clearingAResultReloadsTheOrder() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            server.route("DELETE /v1/mobile/work-orders/o1/steps/s1", .noContent)
            server.route("GET /v1/mobile/work-orders/o1", .json(TestEnv.orderJSON(withProcedure: true, reported: 0)))
            let change = await store.clearReport(step: "s1", of: "o1")
            #expect(change.order?.progress?.reported == 0)
        }

        @Test func addingAPhotoRunsTheWholeFlowAndReloads() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            let base = "/v1/mobile/work-orders/o1/steps/s1/photos"
            server.route("POST \(base)", .json(#"{"photoId":"p1","upload":{"url":"https://s3.test/b","fields":{"key":"k"}},"expiresIn":300}"#, status: 201))
            server.route("POST /b", .noContent)
            server.route("POST \(base)/p1/confirm", .json(TestEnv.stepJSON()))
            server.route("GET /v1/mobile/work-orders/o1", .json(TestEnv.orderJSON(withProcedure: true, reported: 1)))

            let change = await store.addPhoto(jpeg: Data(count: 100), step: "s1", of: "o1")

            #expect(change.order != nil)
            #expect(server.calls("POST /b").count == 1)
            #expect(server.calls("GET /v1/mobile/work-orders/o1").count == 1)
        }

        @Test func photoLimitIsReportedWithoutReloadingTheList() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            server.route("POST /v1/mobile/work-orders/o1/steps/s1/photos",
                         .json(#"{"detail":{"code":"photo_limit_reached","message":"m"}}"#, status: 409))
            let change = await store.addPhoto(jpeg: Data(count: 100), step: "s1", of: "o1")
            #expect(change.failureMessage == AriaServerCode.photoLimitReached.localized)
        }

        @Test func removingAPhotoReloadsTheOrder() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            server.route("DELETE /v1/mobile/work-orders/o1/steps/s1/photos/p1", .json(TestEnv.stepJSON()))
            server.route("GET /v1/mobile/work-orders/o1", .json(TestEnv.orderJSON(withProcedure: true)))
            let change = await store.removePhoto("p1", step: "s1", of: "o1")
            #expect(change.order != nil)
        }

        // MARK: Completamento

        @Test func completingMovesTheOrderFromOpenToClosed() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1"), TestEnv.orderJSON(id: "o2")],
                     closed: [TestEnv.orderJSON(id: "old", status: "completed")])
            await store.sync()
            server.route("POST /v1/mobile/work-orders/o1/complete", .json(TestEnv.orderJSON(id: "o1", status: "completed")))

            let change = await store.complete("o1", resolutionNotes: "Replaced")

            #expect(change.order?.isClosed == true)
            #expect(store.orders.map(\.id) == ["o2"])
            #expect(store.closedOrders.map(\.id) == ["o1", "old"], "la più recente in cima")
        }

        @Test func incompleteStepsLeaveTheListsUntouched() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1")])
            await store.sync()
            server.route("POST /v1/mobile/work-orders/o1/complete",
                         .json(#"{"detail":{"code":"steps_incomplete","message":"m","missing":["s2"]}}"#, status: 409))
            let change = await store.complete("o1", resolutionNotes: "x")
            #expect(change.failureMessage == AriaServerCode.stepsIncomplete.localized)
            #expect(store.orders.map(\.id) == ["o1"] && store.closedOrders.isEmpty)
        }

        @Test func blankResolutionNotesFailBeforeAnyRequestOfTheirOwn() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            let change = await store.complete("o1", resolutionNotes: "  ")
            #expect(change.failureMessage == AriaServerCode.resolutionNotesRequired.localized)
            #expect(server.calls("POST /v1/mobile/work-orders/o1/complete").isEmpty)
        }

        // MARK: Sessione e rete

        @Test func endedSessionSignsTheBackendOutWithoutAnErrorBanner() async throws {
            let (backend, store) = try await TestEnv.signedInStore()
            stubHome()
            await backend.api.auth.invalidate()
            server.route("GET /api/aria/token", .json(#"{"error":"revoked"}"#, status: 401))

            await store.sync()

            #expect(!backend.isSignedIn, "terzo dispositivo, sessione scaduta o revocata: si torna al login")
            #expect(store.errorMessage == nil)
        }

        @Test func disabledOperatorIsSignedOut() async throws {
            let (backend, store) = try await TestEnv.signedInStore()
            stubHome()
            server.route("PUT /v1/mobile/me/availability", .json(#"{"detail":"Not a member of this company"}"#, status: 403))
            await store.sync()
            #expect(!backend.isSignedIn)
        }

        @Test func offlineKeepsTheOperatorSignedInAndShowsAMessage() async throws {
            let (backend, store) = try await TestEnv.signedInStore()
            stubHome()
            server.route(openKey, .failing(.notConnectedToInternet))
            await store.sync()
            #expect(backend.isSignedIn)
            #expect(!store.hasLoaded)
            #expect(store.errorMessage != nil)
            #expect(!store.isLoading)
        }

        @Test func hostDownShowsTheOfflineMessage() async throws {
            let (backend, store) = try await TestEnv.signedInStore()
            stubHome()
            server.route(openKey, .hostDown())
            await store.sync()
            #expect(backend.isSignedIn)
            #expect(store.errorMessage?.lowercased().contains("offline") == true)
        }

        @Test func listStaysOnScreenWhenARefreshFails() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1")])
            await store.sync()
            server.route(openKey, .failing(.timedOut))
            await store.refresh()
            #expect(store.orders.map(\.id) == ["o1"], "l'ultima lista buona resta")
            #expect(store.hasLoaded && store.errorMessage != nil)
        }

        @Test func nextSuccessfulRefreshClearsTheError() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome()
            server.route(openKey, .failing(.timedOut), .json("[]"))
            await store.refresh()
            #expect(store.errorMessage != nil)
            await store.refresh()
            #expect(store.errorMessage == nil)
        }

        @Test func resetForgetsEverythingOfThePreviousOperator() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON()], closed: [TestEnv.orderJSON(id: "c", status: "completed")])
            await store.sync()
            store.reset()
            #expect(store.profile == nil && store.orders.isEmpty && store.closedOrders.isEmpty)
            #expect(!store.hasLoaded && !store.hasLoadedClosed && store.lastUpdated == nil && store.errorMessage == nil)
        }
    }
}
