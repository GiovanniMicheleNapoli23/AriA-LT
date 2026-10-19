//
//  OfflineSyncTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 19/10/26.
//
//  Doppio database: le modifiche ai lavori si salvano sul telefono e si vedono subito (anche offline),
//  poi partono a lotti con meno chiamate possibile; la copia locale sopravvive al riavvio; gli errori
//  del server diventano avvisi o nuovi tentativi; offline non parte nessuna chiamata.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Offline sync")
    struct OfflineSync {
        private let server = StubServer.shared
        private let detailKey = "GET /v1/mobile/work-orders/o1"
        private let openKey = "GET /v1/mobile/work-orders?status=open&limit=50"
        private let closedKey = "GET /v1/mobile/work-orders?status=closed&limit=200"

        init() { TestEnv.reset() }

        /// Store con l'ordine o1 (due passi) già scaricato e salvato sul telefono.
        /// `nil` = valori di TestEnv.signedInStore.
        private func storeWithOrder(reported: Int = 0, network: AriaNetworkMonitor? = nil,
                                    offline: AriaOfflineStore? = nil)
            async throws -> (backend: AriaBackend, store: AriaWorkOrderStore) {
            let (backend, store) = try await TestEnv.signedInStore(network: network, offline: offline)
            server.route(detailKey, .json(TestEnv.orderJSON(withProcedure: true, reported: reported)))
            guard case .found? = await store.detail(of: "o1") else { throw TestFailure("dettaglio non caricato") }
            return (backend, store)
        }

        private struct TestFailure: Error { let message: String; init(_ m: String) { message = m } }

        private func workOrderCalls(after count: Int = 0) -> [String] {
            server.calls.dropFirst(count).map { "\($0.method) \($0.path)" }.filter { $0.contains("work-orders") }
        }

        private func stubHome(open: [String] = [], closed: [String] = []) {
            let me = #"{"id":"u1","name":"M","email":"m@a.b","specialties":[],"availability":"available"}"#
            server.route("PUT /v1/mobile/me/availability", .json(me))
            server.route("GET /v1/mobile/me", .json(me))
            server.route(openKey, .json("[\(open.joined(separator: ","))]"))
            server.route(closedKey, .json("[\(closed.joined(separator: ","))]"))
        }

        // MARK: Local-first

        @Test func aResultIsVisibleAtOnceAndLeavesInOneBatchWithASingleReload() async throws {
            let (_, store) = try await storeWithOrder()
            let before = server.calls.count
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(TestEnv.stepJSON()))
            server.route(detailKey, .json(TestEnv.orderJSON(status: "in_progress", withProcedure: true, reported: 1)))

            let change = await store.report(.done(note: nil), step: "s1", of: "o1")

            #expect(change.order?.procedure?.steps.first?.report?.isDone == true, "si vede subito")
            #expect(change.order?.status == "in_progress")
            #expect(store.pendingCount == 1)
            #expect(workOrderCalls(after: before).isEmpty, "niente rete finché non parte il lotto")

            await store.flush()

            #expect(workOrderCalls(after: before) == ["PUT /v1/mobile/work-orders/o1/steps/s1", "GET /v1/mobile/work-orders/o1"])
            #expect(store.pendingCount == 0)
            #expect(store.lastSyncedAt != nil)
            #expect(store.current("o1")?.procedure?.steps.first?.report?.isDone == true)
        }

        @Test func manyStepsOfAProcedureNeedOneReloadNotOnePerStep() async throws {
            let (_, store) = try await storeWithOrder()
            let before = server.calls.count
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(TestEnv.stepJSON()))
            server.route("PUT /v1/mobile/work-orders/o1/steps/s2", .json(TestEnv.stepJSON(id: "s2")))
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            _ = await store.report(.done(note: nil), step: "s2", of: "o1")

            await store.flush()

            #expect(server.calls.dropFirst(before).filter { $0.method == "GET" }.count == 1)
            #expect(server.calls.dropFirst(before).filter { $0.method == "PUT" }.count == 2)
        }

        @Test func twoResultsForTheSameStepBecomeOneCall() async throws {
            let (_, store) = try await storeWithOrder()
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(TestEnv.stepJSON(status: "not_done")))
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            _ = await store.report(.notDone(note: "Manca il pezzo"), step: "s1", of: "o1")
            #expect(store.pendingCount == 1)

            await store.flush()

            let puts = server.calls("PUT /v1/mobile/work-orders/o1/steps/s1")
            #expect(puts.count == 1)
            #expect(puts.first?.json as? [String: String] == ["status": "not_done", "note": "Manca il pezzo"])
        }

        @Test func undoingAResultThatNeverLeftCostsNoCalls() async throws {
            let (_, store) = try await storeWithOrder()
            let before = server.calls.count
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            let change = await store.clearReport(step: "s1", of: "o1")
            #expect(change.order?.procedure?.steps.first?.report == nil)
            #expect(store.pendingCount == 0)
            await store.flush()
            #expect(workOrderCalls(after: before).isEmpty)
        }

        @Test func undoingAResultAlreadyOnTheServerSendsTheDelete() async throws {
            let (_, store) = try await storeWithOrder(reported: 1)
            server.route("DELETE /v1/mobile/work-orders/o1/steps/s1", .noContent)
            _ = await store.clearReport(step: "s1", of: "o1")
            #expect(store.pendingCount == 1)
            await store.flush()
            #expect(server.calls("DELETE /v1/mobile/work-orders/o1/steps/s1").count == 1)
        }

        @Test func notDoneWithoutAReasonFailsLocallyWithAReadableMessage() async throws {
            let (_, store) = try await storeWithOrder()
            let change = await store.report(.notDone(note: "  "), step: "s1", of: "o1")
            #expect(change.failureMessage == AriaServerCode.noteRequired.localized)
            #expect(store.pendingCount == 0)
        }

        @Test func aClosedOrderRefusesChangesLocally() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            server.route(detailKey, .json(TestEnv.orderJSON(status: "completed", withProcedure: true, reported: 2)))
            _ = await store.detail(of: "o1")
            let change = await store.clearReport(step: "s1", of: "o1")
            #expect(change.failureMessage == AriaServerCode.workOrderClosed.localized)
            #expect(store.pendingCount == 0)
        }

        // MARK: Offline

        @Test func offlineNothingIsCalledAndTheWorkWaitsOnThePhone() async throws {
            let network = AriaNetworkMonitor(monitoring: false)
            let (_, store) = try await storeWithOrder(network: network)
            network.simulate(.offline)
            let before = server.calls.count

            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            _ = await store.report(.done(note: nil), step: "s2", of: "o1")
            await store.flush()
            await store.sync()
            await store.refresh()
            guard case .found(let order)? = await store.detail(of: "o1") else { Issue.record("atteso .found"); return }

            #expect(server.calls.count == before, "offline non parte nessuna chiamata (niente timeout, niente batteria)")
            #expect(store.isOffline)
            #expect(store.pendingCount == 2)
            #expect(order.procedure?.isFullyReported == true, "il dettaglio offline mostra il lavoro fatto")
            #expect(store.errorMessage == nil)
        }

        @Test func whenTheNetworkReturnsTheQueueLeavesByItself() async throws {
            let network = AriaNetworkMonitor(monitoring: false)
            let (_, store) = try await storeWithOrder(network: network)
            network.simulate(.offline)
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            stubHome(open: [TestEnv.orderJSON()])
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(TestEnv.stepJSON()))

            network.simulate(.online)

            #expect(await TestEnv.waitUntil { store.pendingCount == 0 && !store.isSyncingChanges })
            #expect(server.calls("PUT /v1/mobile/work-orders/o1/steps/s1").count == 1)
        }

        @Test func completingOfflineClosesTheTaskOnThePhoneAndQueuesTheClosure() async throws {
            let network = AriaNetworkMonitor(monitoring: false)
            let (_, store) = try await storeWithOrder(reported: 2, network: network)
            network.simulate(.offline)

            let change = await store.complete("o1", resolutionNotes: "Sostituito il cuscinetto")

            #expect(change.order?.isClosed == true)
            #expect(store.orders.isEmpty)
            #expect(store.closedOrders.map(\.id) == ["o1"])
            #expect(store.pendingCount == 1)
            #expect(server.calls("POST /v1/mobile/work-orders/o1/complete").isEmpty)
        }

        @Test func completingChecksTheStepsOnThePhoneFirst() async throws {
            let (_, store) = try await storeWithOrder(reported: 1)
            let change = await store.complete("o1", resolutionNotes: "x")
            #expect(change.failureMessage == AriaServerCode.stepsIncomplete.localized)
            #expect(store.pendingCount == 0)
        }

        @Test func blankResolutionNotesFailBeforeAnything() async throws {
            let (_, store) = try await storeWithOrder(reported: 2)
            let change = await store.complete("o1", resolutionNotes: "  ")
            #expect(change.failureMessage == AriaServerCode.resolutionNotesRequired.localized)
            #expect(store.pendingCount == 0)
        }

        @Test func anOrderNeverDownloadedCannotBeChangedOffline() async throws {
            let network = AriaNetworkMonitor(monitoring: false, initial: .offline)
            let (_, store) = try await TestEnv.signedInStore(network: network)
            let change = await store.report(.done(note: nil), step: "s1", of: "o9")
            #expect(change.failureMessage?.isEmpty == false)
            #expect(store.pendingCount == 0)
        }

        // MARK: Fine procedura

        @Test func completingOnlineSendsTheWholeBatchAndMovesTheOrderToClosed() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON(id: "o1"), TestEnv.orderJSON(id: "o2")],
                     closed: [TestEnv.orderJSON(id: "old", status: "completed")])
            await store.sync()
            server.route(detailKey, .json(TestEnv.orderJSON(withProcedure: true)))
            _ = await store.detail(of: "o1")
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(TestEnv.stepJSON()))
            server.route("PUT /v1/mobile/work-orders/o1/steps/s2", .json(TestEnv.stepJSON(id: "s2")))
            server.route("POST /v1/mobile/work-orders/o1/complete", .json(TestEnv.orderJSON(id: "o1", status: "completed")))
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            _ = await store.report(.done(note: nil), step: "s2", of: "o1")
            let before = server.calls.count

            let change = await store.complete("o1", resolutionNotes: "Replaced")

            #expect(change.order?.isClosed == true)
            #expect(workOrderCalls(after: before) == ["PUT /v1/mobile/work-orders/o1/steps/s1",
                                                       "PUT /v1/mobile/work-orders/o1/steps/s2",
                                                       "POST /v1/mobile/work-orders/o1/complete"],
                    "in ordine, e la risposta della chiusura è già l'ordine aggiornato: niente rilettura")
            #expect(store.orders.map(\.id) == ["o2"])
            #expect(store.closedOrders.map(\.id) == ["o1", "old"], "la più recente in cima")
            #expect(store.pendingCount == 0)
        }

        @Test func aClosureRefusedByTheServerIsReportedHereAndTheOrderStaysOpen() async throws {
            let (_, store) = try await storeWithOrder(reported: 2)
            server.route("POST /v1/mobile/work-orders/o1/complete",
                         .json(#"{"detail":{"code":"steps_incomplete","message":"m","missing":["s2"]}}"#, status: 409))
            let change = await store.complete("o1", resolutionNotes: "x")
            #expect(change.failureMessage == AriaServerCode.stepsIncomplete.localized)
            #expect(store.orders.map(\.id) == ["o1"] && store.closedOrders.isEmpty)
            #expect(store.syncIssues.isEmpty, "detto qui, non anche come problema di sincronizzazione")
        }

        // MARK: Errori durante l'invio

        @Test func aStepRemovedOnTheDesktopBecomesASyncIssue() async throws {
            let (_, store) = try await storeWithOrder()
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1",
                         .json(#"{"detail":{"code":"step_not_found","message":"m"}}"#, status: 404))
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")

            await store.flush()

            #expect(store.pendingCount == 0, "rifiutata: non si riprova")
            #expect(store.syncIssues.map(\.message) == [AriaServerCode.stepNotFound.localized])
            #expect(store.syncIssues.first?.orderTitle == "Fix")
            #expect(server.calls(detailKey).count == 2, "l'ordine si rilegge per mostrare com'è sul server")
        }

        @Test func anOrderNoLongerOursIsRemovedWithItsQueue() async throws {
            let (_, store) = try await storeWithOrder()
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(#"{"detail":"Not found"}"#, status: 404))
            server.route("PUT /v1/mobile/work-orders/o1/steps/s2", .json(TestEnv.stepJSON(id: "s2")))
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            _ = await store.report(.done(note: nil), step: "s2", of: "o1")

            await store.flush()

            #expect(store.orders.isEmpty && store.current("o1") == nil)
            #expect(store.pendingCount == 0)
            #expect(server.calls("PUT /v1/mobile/work-orders/o1/steps/s2").isEmpty, "il resto della coda dell'ordine non parte")
            #expect(store.syncIssues.first?.kind == .gone)
        }

        @Test func aServerThatIsDownKeepsTheChangeForLater() async throws {
            let (_, store) = try await storeWithOrder()
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json("{}", status: 503))
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")

            await store.flush()

            #expect(store.pendingCount == 1)
            #expect(store.syncIssues.isEmpty)
            #expect(store.current("o1")?.procedure?.steps.first?.report?.isDone == true, "resta visibile")
        }

        @Test func failuresAreClassifiedForRetryOrRejection() {
            #expect(AriaWorkOrderStore.classify(URLError(.notConnectedToInternet)) == .retryLater)
            #expect(AriaWorkOrderStore.classify(AriaError.http(status: 500, detail: "")) == .retryLater)
            #expect(AriaWorkOrderStore.classify(AriaError.http(status: 429, detail: "")) == .retryLater)
            #expect(AriaWorkOrderStore.classify(AriaError.http(status: 404, detail: "")) == .orderGone)
            #expect(AriaWorkOrderStore.classify(AriaError.workOrder(.photoNotUploaded)) == .retryLater)
            #expect(AriaWorkOrderStore.classify(AriaError.workOrder(.workOrderClosed))
                    == .rejected(AriaServerCode.workOrderClosed.localized))
            #expect(AriaWorkOrderStore.classify(AriaError.signedOut) == .signedOut)
            #expect(AriaWorkOrderStore.classify(CancellationError()) == .cancelled)
        }

        // MARK: Foto

        @Test func photosWaitForTheResultThenLeaveAfterIt() async throws {
            let (_, store) = try await storeWithOrder()
            let early = await store.addPhoto(jpeg: Data(count: 100), step: "s1", of: "o1")
            #expect(early.failureMessage == AriaServerCode.stepNotReported.localized)

            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            _ = await store.addPhoto(jpeg: Data(count: 100), step: "s1", of: "o1")
            #expect(store.pendingPhotos(step: "s1", of: "o1").count == 1)

            let base = "/v1/mobile/work-orders/o1/steps/s1/photos"
            server.route("PUT /v1/mobile/work-orders/o1/steps/s1", .json(TestEnv.stepJSON()))
            server.route("POST \(base)", .json(#"{"photoId":"p1","upload":{"url":"https://s3.test/b","fields":{"key":"k"}},"expiresIn":300}"#, status: 201))
            server.route("POST /b", .noContent)
            server.route("POST \(base)/p1/confirm", .json(TestEnv.stepJSON()))
            let before = server.calls.count

            await store.flush()

            #expect(server.calls.dropFirst(before).map { "\($0.method) \($0.path)" } == [
                "PUT /v1/mobile/work-orders/o1/steps/s1", "POST \(base)", "POST /b", "POST \(base)/p1/confirm",
                "GET /v1/mobile/work-orders/o1",
            ])
            #expect(store.pendingPhotos(step: "s1", of: "o1").isEmpty)
        }

        @Test func aPhotoRemovedBeforeLeavingCostsNoCalls() async throws {
            let (_, store) = try await storeWithOrder(reported: 1)
            _ = await store.addPhoto(jpeg: Data(count: 100), step: "s1", of: "o1")
            let localId = try #require(store.pendingPhotos(step: "s1", of: "o1").first?.localId)
            _ = await store.removePhoto(localId, step: "s1", of: "o1")
            #expect(store.pendingCount == 0)
        }

        @Test func atMostThreePhotosPerStepCountingTheQueuedOnes() async throws {
            let (_, store) = try await storeWithOrder(reported: 1)
            for _ in 0..<3 { _ = await store.addPhoto(jpeg: Data(count: 10), step: "s1", of: "o1") }
            let fourth = await store.addPhoto(jpeg: Data(count: 10), step: "s1", of: "o1")
            #expect(fourth.failureMessage == AriaServerCode.photoLimitReached.localized)
            #expect(store.pendingPhotos(step: "s1", of: "o1").count == 3)
        }

        // MARK: Copia locale

        @Test func savedTasksAndQueueSurviveARelaunch() async throws {
            let offline = AriaOfflineStore(inMemory: true)
            let (backend, store) = try await storeWithOrder(offline: offline)
            stubHome(open: [TestEnv.orderJSON(id: "o1"), TestEnv.orderJSON(id: "o2")])
            await store.refresh()
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            let before = server.calls.count

            let relaunched = AriaWorkOrderStore(backend: backend, network: AriaNetworkMonitor(monitoring: false, initial: .offline),
                                                offline: offline)

            #expect(relaunched.hasLoaded && relaunched.lastUpdated != nil, "la lista c'è anche senza rete")
            #expect(relaunched.orders.map(\.id) == ["o1", "o2"])
            #expect(relaunched.pendingCount == 1)
            #expect(relaunched.current("o1")?.procedure?.steps.first?.report?.isDone == true)
            #expect(relaunched.profile?.id == "u1")
            #expect(server.calls.count == before)
        }

        @Test func foregroundingTwiceInAMinuteLoadsTheListOnce() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            stubHome(open: [TestEnv.orderJSON()])
            await store.sync()
            await store.sync()
            #expect(server.calls.filter { $0.path == "/v1/mobile/work-orders" && $0.query == "status=open&limit=50" }.count == 1)
            await store.refresh()
            #expect(server.calls.filter { $0.path == "/v1/mobile/work-orders" && $0.query == "status=open&limit=50" }.count == 2,
                    "il pull-to-refresh ricarica sempre")
        }

        @Test func onlyChangedDetailsArePrefetched() async throws {
            let (_, store) = try await TestEnv.signedInStore()
            let monday = "2026-10-19T08:00:00Z", tuesday = "2026-10-20T08:00:00Z"
            stubHome(open: [TestEnv.orderJSON(id: "o1", updatedAt: monday), TestEnv.orderJSON(id: "o2", updatedAt: monday)])
            server.route(detailKey, .json(TestEnv.orderJSON(id: "o1", withProcedure: true, updatedAt: monday)))
            server.route("GET /v1/mobile/work-orders/o2", .json(TestEnv.orderJSON(id: "o2", withProcedure: true, updatedAt: monday)))

            await store.refresh()
            #expect(server.calls(detailKey).count == 1 && server.calls("GET /v1/mobile/work-orders/o2").count == 1)
            #expect(store.current("o2")?.procedure != nil, "i passi sono sul telefono prima ancora di aprire l'ordine")

            // Il giorno dopo un planner cambia solo o1.
            stubHome(open: [TestEnv.orderJSON(id: "o1", updatedAt: tuesday), TestEnv.orderJSON(id: "o2", updatedAt: monday)])
            server.route(detailKey, .json(TestEnv.orderJSON(id: "o1", withProcedure: true, updatedAt: tuesday)))
            await store.refresh()

            #expect(server.calls(detailKey).count == 2)
            #expect(server.calls("GET /v1/mobile/work-orders/o2").count == 1, "o2 non è cambiato: non si riscarica")
        }

        @Test func lowDataModeSkipsThePrefetch() async throws {
            let network = AriaNetworkMonitor(monitoring: false, initial: .init(isOnline: true, isExpensive: true,
                                                                                isConstrained: true, interface: .cellular))
            let (_, store) = try await TestEnv.signedInStore(network: network)
            stubHome(open: [TestEnv.orderJSON(id: "o1")])
            await store.refresh()
            #expect(server.calls(detailKey).isEmpty)
            #expect(store.orders.count == 1)
        }

        @Test func availabilityChosenOfflineLeavesWhenTheNetworkReturns() async throws {
            let network = AriaNetworkMonitor(monitoring: false, initial: .offline)
            let (_, store) = try await TestEnv.signedInStore(network: network)
            await store.setAvailability(.busy)
            #expect(store.availability == .busy)
            #expect(server.calls("PUT /v1/mobile/me/availability").isEmpty)

            stubHome()
            network.simulate(.online)

            #expect(await TestEnv.waitUntil { !server.calls("PUT /v1/mobile/me/availability").isEmpty })
            #expect(server.calls("PUT /v1/mobile/me/availability").first?.json as? [String: String] == ["availability": "busy"])
        }

        @Test func loggingOutWipesThePhoneButAnExpiredSessionKeepsTheQueue() async throws {
            let offline = AriaOfflineStore(inMemory: true)
            let (_, store) = try await storeWithOrder(offline: offline)
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")

            store.reset(keepOfflineWork: true)
            #expect(offline.pendingCount(accountId: "u1") == 1)

            store.reset()
            #expect(offline.pendingCount(accountId: "u1") == 0)
            #expect(offline.orders(accountId: "u1").isEmpty)
        }
    }
}
