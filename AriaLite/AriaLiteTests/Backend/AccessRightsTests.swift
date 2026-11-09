//
//  AccessRightsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 03/11/26.
//
//  Ruoli e diritti: il blocco `access` di GET /v1/me, cosa concede (AriaRights), la sidebar dell'operatore che
//  segue il ruolo, il 403 `permission_denied` e i segnali che fanno rileggere i diritti (X-Access-Version).
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Access rights")
    struct AccessRights {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        private static func access(model: String = "rbac", admin: Bool = false, role: String? = #"{"id":"r1","name":"Technician","set":"low","enabled":true}"#,
                                   sections: String = #"{"work_orders":{"granted":true,"actions":["complete"]},"assets":{"granted":false,"actions":[]}}"#,
                                   followsRole: Bool = true, version: String = "v1") -> String {
        TestEnv.accessJSON(model: model, admin: admin, role: role, sections: sections, followsRole: followsRole, version: version)
    }

        private static func rights(_ json: String) throws -> AriaRights {
            AriaRights(access: try JSONDecoder().decode(AriaAccess.self, from: Data(json.utf8)))
        }

        // MARK: Decodifica

        @Test func meDecodesTheAccessBlock() throws {
            let json = #"{"id":"u1","membership":{"role":"member","restricted":true},"access":\#(Self.access())}"#
            let me = try JSONDecoder().decode(AriaMe.self, from: Data(json.utf8))
            let access = try #require(me.access)
            #expect(access.model == "rbac")
            #expect(access.role?.name == "Technician")
            #expect(access.sections["work_orders"] == AriaAccess.Grant(granted: true, actions: ["complete"]))
            #expect(access.version == "v1")
            #expect(access.appFollowsRole)
        }

        @Test func meWithoutAccessOrWithAnUnknownShapeStillDecodes() throws {
            let old = try JSONDecoder().decode(AriaMe.self, from: Data(#"{"id":"u1"}"#.utf8))
            #expect(old.access == nil)
            let odd = try JSONDecoder().decode(AriaMe.self, from: Data(#"{"id":"u1","access":"rbac"}"#.utf8))
            #expect(odd.access == nil)
        }

        @Test func missingAppFollowsRoleMeansFalse() throws {
            let json = #"{"model":"rbac","role":null,"admin":false,"sections":{}}"#
            let access = try JSONDecoder().decode(AriaAccess.self, from: Data(json.utf8))
            #expect(!access.appFollowsRole)
            #expect(access.version == nil)
        }

        // MARK: Cosa concede

        @Test func withoutAccessLegacyOrAdminEverythingIsGranted() throws {
            for rights in [AriaRights.unrestricted,
                           try Self.rights(Self.access(model: "legacy", sections: "{}")),
                           try Self.rights(Self.access(admin: true, role: nil, sections: "{}"))] {
                #expect(!rights.isRoleBased)
                #expect(!rights.followsRole)
                #expect(!rights.isPaused)
                #expect(rights.has(.assets))
                #expect(rights.can(.stepPhotos, in: .workOrders))
            }
        }

        @Test func aRoleGrantsOnlyItsSectionsAndActions() throws {
            let rights = try Self.rights(Self.access())
            #expect(rights.isRoleBased)
            #expect(rights.followsRole)
            #expect(rights.has(.workOrders))
            #expect(!rights.has(.assets))
            #expect(!rights.has(.marketplace), "una sezione che manca non è concessa")
            #expect(rights.can(.complete, in: .workOrders))
            #expect(!rights.can(.stepPhotos, in: .workOrders))
        }

        @Test func noRoleOrAPausedRoleGrantsNothing() throws {
            for role in [nil, #"{"id":"r1","name":"Technician","enabled":false}"#] {
                let rights = try Self.rights(Self.access(role: role))
                #expect(rights.isPaused)
                #expect(!rights.has(.workOrders))
                #expect(!rights.can(.complete, in: .workOrders))
            }
        }

        @Test func statusMovesNeedTheSwitchOfWhereTheyGoAndWhereTheyLeave() throws {
            let onlyReject = try Self.rights(Self.access(sections: #"{"assets":{"granted":true,"actions":["reject"]}}"#))
            #expect(onlyReject.canMove(from: "draft", to: "superseded", in: .assets), "superato vuole reject")
            #expect(!onlyReject.canMove(from: "approved", to: "superseded", in: .assets), "da approvato anche unapprove")
            #expect(onlyReject.canMove(from: "rejected", to: "draft", in: .assets), "fuori da rifiutato vuole reject")
            #expect(!onlyReject.canMove(from: "rejected", to: "approved", in: .assets), "ad approvato vuole approve")
            #expect(!onlyReject.canMove(from: "approved", to: "draft", in: .assets))

            let none = try Self.rights(Self.access(sections: #"{"assets":{"granted":true,"actions":[]}}"#))
            #expect(none.canMove(from: "draft", to: "staged", in: .assets))
            #expect(none.canMove(from: "rejected", to: "rejected", in: .assets), "lo stesso stato non chiede niente")
            #expect(!none.canMove(from: "draft", to: "superseded", in: .assets))
            #expect(!none.canMove(from: "rejected", to: "staged", in: .assets))
            #expect(AriaRights.unrestricted.canMove(from: "approved", to: "rejected", in: .assets))
        }

        @Test func deletingAWorkOrderNeedsCancelUnlessItIsCancelled() throws {
            let rights = try Self.rights(Self.access())
            #expect(!rights.canDeleteWorkOrder(status: "open"))
            #expect(rights.canDeleteWorkOrder(status: "cancelled"))
            let canCancel = try Self.rights(Self.access(sections: #"{"work_orders":{"granted":true,"actions":["cancel"]}}"#))
            #expect(canCancel.canDeleteWorkOrder(status: "open"))
        }

        @Test func lookOnlySectionsHideTheirSwitches() throws {
            let rights = try Self.rights(Self.access(sections: #"{"vendors":{"granted":true,"actions":["edit"]}}"#))
            #expect(rights.has(.vendors))
            #expect(rights.can(.edit, in: .vendors))
            #expect(!rights.can(.create, in: .vendors))
            #expect(!rights.can(.delete, in: .vendors))
        }

        // MARK: Sidebar

        @Test func operatorWithoutAccessKeepsTasksAndCalendarOnly() {
            let offered = AriaSidebarSections.destinations(operatorLayout: true, rights: .unrestricted)
            #expect(offered == [.tasks, .calendar])
        }

        @Test func roleThatIsNotFollowedCanOnlyRemoveTasksAndCalendar() throws {
            let rights = try Self.rights(Self.access(sections: #"{"work_orders":{"granted":false},"assets":{"granted":true}}"#,
                                                     followsRole: false))
            #expect(AriaSidebarSections.destinations(operatorLayout: true, rights: rights).isEmpty)
        }

        @Test func followedRoleAddsItsGrantedSections() throws {
            let sections = #"{"work_orders":{"granted":true},"assets":{"granted":true},"taskboard":{"granted":true},"marketplace":{"granted":true},"vendors":{"granted":false}}"#
            let rights = try Self.rights(Self.access(sections: sections))
            let offered = AriaSidebarSections.destinations(operatorLayout: true, rights: rights)
            #expect(offered == [.tasks, .calendar, .assets, .adminTaskboard, .adminMarketplace])
        }

        @Test func taskboardNeedsWorkOrdersToo() throws {
            let rights = try Self.rights(Self.access(sections: #"{"taskboard":{"granted":true},"work_orders":{"granted":false}}"#))
            #expect(!AriaSidebarSections.destinations(operatorLayout: true, rights: rights).contains(.adminTaskboard))
        }

        @Test func pausedRoleLeavesNoSection() throws {
            let rights = try Self.rights(Self.access(role: nil))
            #expect(AriaSidebarSections.destinations(operatorLayout: true, rights: rights).isEmpty)
        }

        @Test func adminLayoutIsUnchanged() throws {
            let rights = try Self.rights(Self.access(sections: "{}"))
            #expect(AriaSidebarSections.destinations(operatorLayout: false, rights: rights).contains(.adminMembers))
        }

        // MARK: 403 e segnali

        @Test func permissionDeniedIsItsOwnError() async throws {
            let client = try await TestEnv.signedInClient()
            let body = #"{"detail":{"code":"permission_denied","message":"No","section":"work_orders","action":"complete","reason":"no_action"}}"#
            server.route("POST /v1/work-orders/o1/complete", .json(body, status: 403))
            await #expect { try await client.perform("POST", "v1/work-orders/o1/complete") } throws: { error in
                guard case .permissionDenied(let denial)? = error as? AriaError else { return false }
                return denial == AriaPermissionDenial(reason: "no_action", section: "work_orders", action: "complete", message: "No")
            }
        }

        @Test func aDeniedRequestAsksForTheRightsAgain() async throws {
            let client = try await TestEnv.signedInClient()
            server.route("GET /v1/assets", .json(#"{"detail":{"code":"permission_denied","reason":"no_section"}}"#, status: 403))
            let context = client.context
            let counter = SignalCounter()
            let listener = Task { for await _ in context.accessSignals { await counter.add() } }
            defer { listener.cancel() }
            _ = try? await client.data("GET", "v1/assets")
            #expect(await TestEnv.waitUntilAsync { await counter.count == 1 })
        }

        @Test func aNewAccessVersionAsksForTheRightsOnce() async throws {
            let client = try await TestEnv.signedInClient()
            await client.context.setAccess(version: "v1", followsRole: true)
            server.route("GET /v1/plants", .json("[]", headers: ["X-Access-Version": "v1"]),
                         .json("[]", headers: ["X-Access-Version": "v2"]), .json("[]", headers: ["X-Access-Version": "v2"]))
            let context = client.context
            let counter = SignalCounter()
            let listener = Task { for await _ in context.accessSignals { await counter.add() } }
            defer { listener.cancel() }
            _ = try await client.data("GET", "v1/plants")
            #expect(await counter.count == 0, "stessa versione: niente da rileggere")
            _ = try await client.data("GET", "v1/plants")
            _ = try await client.data("GET", "v1/plants")
            #expect(await TestEnv.waitUntilAsync { await counter.count == 1 })
            try await Task.sleep(for: .milliseconds(100))
            #expect(await counter.count == 1, "la stessa versione nuova si segnala una volta")
        }

        @Test func operationForbiddenAsksForTheRightsOnlyWhileFollowingTheRole() async throws {
            let client = try await TestEnv.signedInClient()
            let context = client.context
            let counter = SignalCounter()
            let listener = Task { for await _ in context.accessSignals { await counter.add() } }
            defer { listener.cancel() }
            server.route("GET /v1/chat/suggestions", .json(#"{"detail":{"code":"operation_forbidden"}}"#, status: 403))
            _ = try? await client.data("GET", "v1/chat/suggestions")
            try await Task.sleep(for: .milliseconds(100))
            #expect(await counter.count == 0)

            await context.setAccess(version: nil, followsRole: true)
            server.route("GET /v1/chat/suggestions", .json(#"{"detail":{"code":"operation_forbidden"}}"#, status: 403))
            _ = try? await client.data("GET", "v1/chat/suggestions")
            #expect(await TestEnv.waitUntilAsync { await counter.count == 1 })
        }
    }
}

private actor SignalCounter {
    private(set) var count = 0
    func add() { count += 1 }
}
