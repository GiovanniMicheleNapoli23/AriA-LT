//
//  RoleGatedStoreTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 05/11/26.
//
//  Le azioni dei lavori che dipendono dal ruolo: foto dei passi (`step_photos`) e chiusura (`complete`) si
//  rifiutano sul telefono senza chiamare il server, e un 403 `permission_denied` in coda si scarta senza
//  bloccare il resto.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Role-gated work orders")
    struct RoleGatedStore {
        private let server = StubServer.shared
        private let detailKey = "GET /v1/work-orders/o1"

        init() { TestEnv.reset() }

        /// Store con l'ordine o1 (due passi, `reported` già fatti) e i diritti di `access` (`nil` = nessun blocco).
        private func store(access: String?, reported: Int = 0) async throws -> AriaWorkOrderStore {
            let (backend, store) = try await TestEnv.signedInStore()
            await TestEnv.grant(access, to: backend)
            server.route(detailKey, .json(TestEnv.orderJSON(withProcedure: true, reported: reported)))
            guard case .found? = await store.detail(of: "o1") else {
                Issue.record("dettaglio non caricato")
                return store
            }
            return store
        }

        private static let roleMessage = AriaError.permissionDenied(AriaPermissionDenial(reason: "no_action")).localizedDescription

        private static func sections(_ actions: String) -> String {
            TestEnv.accessJSON(sections: #"{"work_orders":{"granted":true,"actions":[\#(actions)]}}"#)
        }

        // MARK: Cosa offre

        @Test func withoutAccessBlockPhotosAndClosingStayAvailable() async throws {
            let store = try await store(access: nil)
            #expect(store.canManagePhotos)
            #expect(store.canComplete)
        }

        @Test func stepPhotosAloneAllowsPhotosButNotClosing() async throws {
            let store = try await store(access: Self.sections(#""step_photos""#))
            #expect(store.canManagePhotos && !store.canComplete)
        }

        @Test func completeAloneAllowsClosingButNotPhotos() async throws {
            let store = try await store(access: Self.sections(#""complete""#))
            #expect(!store.canManagePhotos && store.canComplete)
        }

        @Test func aPausedRoleCanDoNeither() async throws {
            let store = try await store(access: TestEnv.accessJSON(role: #"{"id":"r1","name":"Technician","enabled":false}"#,
                                                                    sections: #"{"work_orders":{"granted":true,"actions":["complete","step_photos"]}}"#))
            #expect(!store.canManagePhotos)
            #expect(!store.canComplete)
        }

        // MARK: Rifiuti sul telefono

        @Test func addingAPhotoWithoutStepPhotosFailsWithoutQueueingIt() async throws {
            let store = try await store(access: Self.sections(#""complete""#), reported: 1)

            let change = await store.addPhoto(jpeg: Data(count: 100), step: "s1", of: "o1")

            #expect(change.failureMessage == Self.roleMessage)
            #expect(store.pendingPhotos(step: "s1", of: "o1").isEmpty)
            #expect(store.pendingCount == 0)
        }

        @Test func closingWithoutCompleteFailsWithoutCallingTheServer() async throws {
            let store = try await store(access: Self.sections(#""step_photos""#), reported: 2)

            let change = await store.complete("o1", resolutionNotes: "Replaced")

            #expect(change.failureMessage == Self.roleMessage)
            #expect(server.calls("POST /v1/work-orders/o1/complete").isEmpty)
            #expect(store.pendingCount == 0)
            #expect(store.current("o1")?.isClosed == false, "l'ordine resta aperto")
        }

        @Test func reportingAStepNeedsOnlyTheSection() async throws {
            let store = try await store(access: Self.sections(""))
            let change = await store.report(.done(note: nil), step: "s1", of: "o1")
            #expect(change.failureMessage == nil, "nota e valore di un passo vogliono solo work_orders")
            #expect(store.pendingCount == 1)
        }

        // MARK: Rifiuti del server in coda

        @Test func aMissingActionIsARejectionButAPausedRoleIsARetry() {
            let missing = AriaError.permissionDenied(AriaPermissionDenial(reason: "no_action", section: "work_orders", action: "complete"))
            #expect(AriaWorkOrderStore.classify(missing) == .rejected(missing.localizedDescription))
            for reason in ["role_disabled", "no_role", "no_section"] {
                let paused = AriaError.permissionDenied(AriaPermissionDenial(reason: reason, section: "work_orders"))
                #expect(AriaWorkOrderStore.classify(paused) == .retryLater, "\(reason): l'admin può ridare l'accesso")
            }
            let otherSection = AriaError.permissionDenied(AriaPermissionDenial(reason: "no_section", section: "assets"))
            #expect(AriaWorkOrderStore.classify(otherSection) == .rejected(otherSection.localizedDescription))
        }

        @Test func aQueuedChangeRefusedByTheRoleIsDroppedAndTheRestLeaves() async throws {
            let store = try await store(access: nil)
            server.route("PUT /v1/work-orders/o1/steps/s1",
                         .json(#"{"detail":{"code":"permission_denied","section":"work_orders","action":"x","reason":"no_action"}}"#, status: 403))
            server.route("PUT /v1/work-orders/o1/steps/s2", .json(TestEnv.stepJSON(id: "s2")))
            server.route("GET /v1/me", .json(#"{"id":"u1"}"#))
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            _ = await store.report(.done(note: nil), step: "s2", of: "o1")

            await store.flush()

            #expect(store.pendingCount == 0, "rifiutata: non si riprova")
            #expect(server.calls("PUT /v1/work-orders/o1/steps/s2").count == 1, "il resto della coda parte")
            #expect(store.syncIssues.map(\.message)
                    == [AriaError.permissionDenied(AriaPermissionDenial(reason: "no_action")).localizedDescription])
        }

        @Test func aChangeRefusedBecauseTheRoleIsPausedStaysOnThePhone() async throws {
            let store = try await store(access: nil)
            server.route("PUT /v1/work-orders/o1/steps/s1",
                         .json(#"{"detail":{"code":"permission_denied","section":"work_orders","reason":"role_disabled"}}"#, status: 403))
            server.route("GET /v1/me", .json(#"{"id":"u1"}"#))
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")

            await store.flush()

            #expect(store.pendingCount == 1, "la pausa finisce: il lavoro fatto non si perde")
            #expect(store.syncIssues.isEmpty)
            #expect(store.current("o1")?.procedure?.steps.first?.report?.isDone == true, "resta visibile")
        }

        @Test func withoutWorkOrdersTheQueueWaitsAndNoListIsAsked() async throws {
            let (backend, store) = try await TestEnv.signedInStore()
            server.route(detailKey, .json(TestEnv.orderJSON(withProcedure: true)))
            _ = await store.detail(of: "o1")
            _ = await store.report(.done(note: nil), step: "s1", of: "o1")
            await TestEnv.grant(TestEnv.accessJSON(role: nil), to: backend)
            #expect(!store.hasWorkOrders)
            let before = server.calls.count

            await store.flush()
            await store.sync()
            await store.refresh()

            let workOrderCalls = server.calls.dropFirst(before).filter { $0.path.hasPrefix("/v1/work-orders") }
            #expect(workOrderCalls.isEmpty, "niente 403 da collezionare: né coda né liste")
            #expect(store.pendingCount == 1, "la coda aspetta il ruolo")

            // L'admin ridà il ruolo: la coda parte.
            server.route("PUT /v1/work-orders/o1/steps/s1", .json(TestEnv.stepJSON()))
            await TestEnv.grant(TestEnv.accessJSON(sections: #"{"work_orders":{"granted":true,"actions":[]}}"#), to: backend)
            await store.flush()
            #expect(store.pendingCount == 0)
            #expect(server.calls("PUT /v1/work-orders/o1/steps/s1").count == 1)
        }
    }
}
