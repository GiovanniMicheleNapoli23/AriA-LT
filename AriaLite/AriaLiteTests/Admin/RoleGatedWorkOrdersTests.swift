//
//  RoleGatedWorkOrdersTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 05/11/26.
//
//  Ruoli e diritti lato ordini di lavoro dell'admin: le anagrafiche /v1/lookups/* al posto di users, members,
//  teams e mobile-operators, `scope=all` della Taskboard, le azioni che il ruolo concede (completa, verifica,
//  annulla, riapri, assegnazione automatica) e Maintenance (storico, ordini generati, persone, stati).
//  Per ogni comportamento: il membro con ruolo e il caso senza limiti (nessun blocco `access`, azienda legacy, admin).
//

import Foundation
import Testing
@testable import AriaLite

// MARK: - Aiuti

/// I tre modi in cui un account non ha limiti: l'app deve comportarsi come prima dei ruoli.
nonisolated enum RoleGatedUnrestricted: CaseIterable {
    case noAccessBlock, legacyCompany, admin

    @MainActor var access: String? {
        switch self {
        case .noAccessBlock: nil
        case .legacyCompany: TestEnv.accessJSON(model: "legacy", sections: "{}")
        case .admin: TestEnv.accessJSON(admin: true, role: nil, sections: "{}")
        }
    }
}

private enum Roles {
    /// Un ruolo attivo che segue l'app: `[sezione: [azioni]]`, ogni sezione concessa.
    static func access(_ sections: [String: [String]]) -> String {
        let body = sections.sorted { $0.key < $1.key }.map { slug, actions in
            let list = actions.map { "\"\($0)\"" }.joined(separator: ",")
            return #""\#(slug)":{"granted":true,"actions":[\#(list)]}"#
        }.joined(separator: ",")
        return TestEnv.accessJSON(sections: "{\(body)}")
    }

    /// Ordini di lavoro e Taskboard, con le azioni date.
    static func workOrders(_ actions: [String] = []) -> String {
        access(["work_orders": actions, "taskboard": []])
    }

    static func member(_ access: String?) async throws -> AriaBackend {
        let (backend, _) = try await TestEnv.signedInStore()
        await TestEnv.grant(access, to: backend)
        return backend
    }
}

private func gateOrder(_ status: String, id: String = "o1") throws -> AdminWorkOrder {
    try JSONDecoder().decode(AdminWorkOrder.self, from: Data(#"{"id":"\#(id)","title":"Fix","status":"\#(status)"}"#.utf8))
}

// MARK: - Anagrafiche (valori puri)

@Suite("Admin lookups")
struct AdminLookupsTests {
    private func rows(_ json: String) throws -> [AdminLookupRow] {
        AdminLookupsAPI.rows(from: try JSONDecoder().decode(AriaJSON.self, from: Data(json.utf8)))
    }

    @Test func rowsComeFromAnArrayOrFromAWrappedList() throws {
        let row = #"{"id":"u1","name":"Anna"}"#
        #expect(try rows("[\(row)]").map(\.id) == ["u1"])
        for key in ["items", "data", "people", "teams", "candidates", "results"] {
            #expect(try rows(#"{"\#(key)":[\#(row)],"total":1}"#).map(\.id) == ["u1"], "chiave \(key)")
        }
        #expect(try rows(#"{"total":1,"whatever":[\#(row)]}"#).map(\.id) == ["u1"], "in mancanza, il primo array")
        #expect(try rows(#"{"total":0}"#).isEmpty)
        #expect(try rows(#""nope""#).isEmpty)
    }

    @Test func rowsReadNamesInBothCasesAndDropTheOnesWithoutAnId() throws {
        let list = try rows("""
        [{"id":"a","full_name":"Anna Bianchi","email":"anna@a.b"},
         {"id":"b","fullName":"Bruno Neri"},
         {"id":"c","display_name":"Carla"},
         {"id":"d","email":"d@a.b"},
         {"id":"e"},
         {"userId":"f","name":"Franco"},
         {"name":"No id"}, "text", 7]
        """)
        #expect(list.map(\.id) == ["a", "b", "c", "d", "e", "f"], "senza id la riga non si può scegliere")
        #expect(list.map(\.name) == ["Anna Bianchi", "Bruno Neri", "Carla", "d@a.b", "e", "Franco"],
                "il nome: quello del server, poi l'email, poi l'id")
    }

    /// Le forme dell'openapi del 05/11/26 (PersonLookup, TeamLookup, DispatchCandidateLookup).
    @Test func theSchemaShapesAreReadWhole() throws {
        let person = try #require(try rows(#"[{"id":"u1","name":"Anna Bianchi","fieldLabel":"technician","plantId":"p1","isFieldWorker":true}]"#).first)
        #expect(person.asUser.displayName == "Anna Bianchi" && person.asUser.isActive && person.plantId == "p1")

        let team = try #require(try rows(#"[{"id":"t1","name":"Mechanics","memberIds":["u1","u2","u3"]}]"#).first)
        #expect(team.asTeam.name == "Mechanics" && team.asTeam.memberCount == 3, "i membri si contano da `memberIds`")

        let candidate = try #require(try rows(#"[{"id":"u2","name":"Bruno","specialties":["hvac"],"availability":"busy","availabilityAt":"2026-11-05T08:30:00Z","openCount":2,"openMinutes":45}]"#).first)
        let field = candidate.asOperator
        #expect(field.availability == .busy && field.openCount == 2 && field.openMinutes == 45 && field.specialties == ["hvac"])
        #expect(field.availabilityAt == ISO8601DateFormatter().date(from: "2026-11-05T08:30:00Z"))
    }

    @Test func aRowBecomesAUserATeamAndAFieldOperator() throws {
        let row = try #require(try rows("""
        [{"id":"u1","full_name":"Anna Bianchi","email":"anna@a.b","role":"technician","plant_id":"p1","active":false,
          "members":[{"id":"x"},{"id":"y"}],"availability":"off_duty","open_count":3,"open_minutes":120,
          "specialties":["hvac","",  "pumps"]}]
        """).first)
        let user = row.asUser
        #expect(user.id == "u1" && user.displayName == "Anna Bianchi" && user.role == "technician" && !user.isActive)
        let team = row.asTeam
        #expect(team.name == "Anna Bianchi" && team.plantId == "p1" && team.memberCount == 2, "member_count manca: si contano i `members`")
        let field = row.asOperator
        #expect(field.availability == .offDuty && field.openCount == 3 && field.openMinutes == 120)
        #expect(field.specialties == ["hvac", "pumps"] && field.email == "anna@a.b")

        let bare = try #require(try rows(#"[{"id":"u2","member_count":5}]"#).first)
        #expect(bare.asUser.isActive && bare.asUser.email.isEmpty, "senza `is_active` la persona è attiva")
        #expect(bare.asTeam.memberCount == 5 && bare.asOperator.availability == nil)
    }
}

extension BackendTests {
    // MARK: - API degli ordini

    @Suite("Role-gated work orders API")
    struct WorkOrdersAPI {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        /// L'API con i diritti che il backend ha adesso.
        private func makeAPI(_ backend: AriaBackend) -> AdminWorkOrdersAPI {
            AdminWorkOrdersAPI(api: backend.api, rights: backend.rights)
        }

        private func stubOldRoutes() {
            server.route("GET /v1/users", .json(#"[{"id":"u1","email":"z@a.b","full_name":"Zoe"}]"#))
            server.route("GET /v1/teams", .json(#"[{"id":"t1","name":"Mechanics"}]"#))
            server.route("GET /v1/assets", .json(#"[{"tag":"A1","name":"Pump"}]"#))
            server.route("GET /v1/mobile-operators", .json(#"[{"id":"u2","name":"Anna","email":"a@a.b"}]"#))
        }

        @Test func aRoleBasedMemberReadsPeopleAndTeamsFromTheLookups() async throws {
            let api = makeAPI(try await Roles.member(Roles.workOrders()))
            server.route("GET /v1/lookups/people", .json(#"[{"id":"u1","full_name":"Anna Bianchi","email":"anna@a.b"}]"#))
            server.route("GET /v1/lookups/teams", .json(#"{"items":[{"id":"t1","name":"Mechanics","plant_id":"p1"}]}"#))

            let users = try await api.users()
            let teams = try await api.teams(plantId: "p1")

            #expect(users.map(\.displayName) == ["Anna Bianchi"])
            #expect(teams.map(\.name) == ["Mechanics"] && teams.first?.plantId == "p1")
            #expect(server.calls("GET /v1/lookups/people").count == 1 && server.calls("GET /v1/lookups/people")[0].query == nil,
                    "tutte le persone, non solo il campo")
            #expect(server.calls("GET /v1/lookups/teams").first?.query == "plant_id=p1")
            #expect(server.calls("GET /v1/users").isEmpty && server.calls("GET /v1/teams").isEmpty, "servono members e teams: il ruolo non li ha")
        }

        @Test(arguments: RoleGatedUnrestricted.allCases)
        func withoutLimitsTheOldRoutesAreUsed(_ kind: RoleGatedUnrestricted) async throws {
            let api = makeAPI(try await Roles.member(kind.access))
            stubOldRoutes()

            #expect(try await api.users().map(\.id) == ["u1"])
            #expect(try await api.teams(plantId: nil).map(\.id) == ["t1"])
            #expect(try await api.assets().map(\.tag) == ["A1"])
            #expect(try await api.mobileOperators().map(\.id) == ["u2"])

            #expect(server.calls("GET /v1/users").first?.query == "active_only=true")
            #expect(server.calls("GET /v1/mobile-operators").count == 1)
            #expect(server.calls.allSatisfy { !$0.path.hasPrefix("/v1/lookups") }, "nessuna anagrafica /v1/lookups")
        }

        @Test func operatorsOfARoleBasedMemberAreTheDispatchCandidates() async throws {
            let api = makeAPI(try await Roles.member(Roles.workOrders()))
            server.route("GET /v1/lookups/dispatch-candidates", .json("""
            [{"id":"u2","name":"Anna","email":"a@a.b","availability":"busy","open_count":3,"open_minutes":120,"specialties":["hvac"]}]
            """))

            let operators = try await api.mobileOperators()

            let field = try #require(operators.first)
            #expect(field.id == "u2" && field.availability == .busy && field.openCount == 3 && field.openMinutes == 120)
            #expect(field.specialties == ["hvac"])
            #expect(server.calls("GET /v1/mobile-operators").isEmpty)
            #expect(server.calls("GET /v1/lookups/people").isEmpty, "i candidati ci sono: niente ripiego")
        }

        @Test func missingCandidatesFallBackToTheFieldWorkers() async throws {
            let api = makeAPI(try await Roles.member(Roles.workOrders()))
            server.route("GET /v1/lookups/dispatch-candidates", .json(#"{"detail":"Not found"}"#, status: 404))
            server.route("GET /v1/lookups/people", .json(#"[{"id":"u3","full_name":"Carla"}]"#))

            let operators = try await api.mobileOperators()

            #expect(operators.map(\.name) == ["Carla"])
            #expect(server.calls("GET /v1/lookups/people").first?.query == "field_only=true")
            #expect(server.calls("GET /v1/mobile-operators").isEmpty)
        }

        @Test func aDeniedCandidatesRequestIsNotRetriedWithPeople() async throws {
            let api = makeAPI(try await Roles.member(Roles.workOrders()))
            server.route("GET /v1/lookups/dispatch-candidates",
                         .json(#"{"detail":{"code":"permission_denied","section":"work_orders","reason":"no_section"}}"#, status: 403))
            server.route("GET /v1/lookups/people", .json(#"[{"id":"u3"}]"#))

            await #expect { try await api.mobileOperators() } throws: { error in
                if case .permissionDenied? = error as? AriaError { true } else { false }
            }
            #expect(server.calls("GET /v1/lookups/people").isEmpty, "un 403 non è una rotta mancante")
        }

        @Test func assetsNeedTheAssetsSectionForARoleBasedMember() async throws {
            server.route("GET /v1/assets", .json(#"[{"tag":"A1","name":"Pump"}]"#))

            let backend = try await Roles.member(Roles.workOrders())
            #expect(try await makeAPI(backend).assets().isEmpty)
            #expect(server.calls("GET /v1/assets").isEmpty, "senza il diritto, nessuna chiamata")

            await TestEnv.grant(Roles.access(["work_orders": [], "assets": []]), to: backend)
            #expect(try await makeAPI(backend).assets().map(\.tag) == ["A1"])
            #expect(server.calls("GET /v1/assets").count == 1)
        }
    }

    // MARK: - Taskboard

    @Suite("Role-gated taskboard")
    struct Taskboard {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        private func stubRoutes(orders: [String] = [TestEnv.orderJSON(id: "o1")]) {
            server.route("GET /v1/work-orders", .json("[\(orders.joined(separator: ","))]"))
            server.route("GET /v1/lookups/people", .json("""
            {"items":[{"id":"u1","full_name":"Zoe Verdi"},{"id":"u2","full_name":"Anna Bianchi"},{"id":"u3","full_name":"Gone","is_active":false}]}
            """))
            server.route("GET /v1/lookups/teams", .json(#"[{"id":"t1","name":"Mechanics"}]"#))
            server.route("GET /v1/lookups/dispatch-candidates", .json(#"[{"id":"u2","name":"Anna Bianchi","availability":"available"}]"#))
            server.route("GET /v1/users", .json(#"[{"id":"u1","full_name":"Zoe Verdi"}]"#))
            server.route("GET /v1/members", .json(#"[{"id":"u1","full_name":"Zoe Verdi"}]"#))
            server.route("GET /v1/teams", .json(#"[{"id":"t1","name":"Mechanics"}]"#))
            server.route("GET /v1/assets", .json(#"[{"tag":"A1","name":"Pump"}]"#))
            server.route("GET /v1/mobile-operators", .json(#"[{"id":"u2","name":"Anna Bianchi","email":"a@a.b"}]"#))
        }

        /// La bacheca caricata, con anagrafiche già arrivate.
        private func loaded(_ access: String?) async throws -> AdminTaskboardViewModel {
            let backend = try await Roles.member(access)
            stubRoutes()
            let model = AdminTaskboardViewModel(backend: backend)
            await model.load()
            #expect(await TestEnv.waitUntil { model.directory.hasLoaded }, "le anagrafiche arrivano")
            return model
        }

        @Test func aRoleBasedMemberListsEveryOrderAndNeverCallsTheMemberRoutes() async throws {
            let model = try await loaded(Roles.workOrders(["complete"]))

            let query = try #require(server.calls("GET /v1/work-orders").first?.query)
            #expect(query.contains("scope=all") && query.contains("status_group=all"))
            #expect(model.orders.map(\.id) == ["o1"])
            for route in ["GET /v1/users", "GET /v1/members", "GET /v1/teams", "GET /v1/mobile-operators", "GET /v1/assets"] {
                #expect(server.calls(route).isEmpty, "\(route): il ruolo non ha members, teams né assets")
            }
            #expect(server.calls("GET /v1/lookups/people").count == 1)
            #expect(server.calls("GET /v1/lookups/teams").count == 1)
            #expect(server.calls("GET /v1/lookups/dispatch-candidates").count == 1)
            #expect(model.members.isEmpty)
        }

        @Test func theMemberFilterOfARoleBasedMemberUsesTheActivePeopleOfTheLookups() async throws {
            let model = try await loaded(Roles.workOrders())

            #expect(model.memberChoices.map(\.title) == ["Anna Bianchi", "Zoe Verdi"], "in ordine, senza chi non è attivo")
            #expect(model.directory.teams.map(\.name) == ["Mechanics"])
        }

        @Test(arguments: RoleGatedUnrestricted.allCases)
        func withoutLimitsTheTaskboardKeepsMembersAndTheOldRoutes(_ kind: RoleGatedUnrestricted) async throws {
            let model = try await loaded(kind.access)

            #expect(await TestEnv.waitUntil { model.members.count == 1 }, "i membri si leggono da /v1/members")
            #expect(server.calls("GET /v1/work-orders").first?.query?.contains("scope=all") == true, "il server lo ignora se non serve")
            for route in ["GET /v1/users", "GET /v1/members", "GET /v1/teams", "GET /v1/mobile-operators", "GET /v1/assets"] {
                #expect(server.calls(route).count == 1, "\(route)")
            }
            #expect(server.calls.allSatisfy { !$0.path.hasPrefix("/v1/lookups") })
            #expect(model.memberChoices.map(\.title) == ["Zoe Verdi"])
        }

        @Test func theMoveMenuAndTheKanbanDropOnlyOfferWhatTheRoleHas() async throws {
            let model = try await loaded(Roles.workOrders(["complete"]))
            let card = model.card(try #require(model.orders.first))

            #expect(model.moveChoices(for: card) == [.proposed, .planned, .inProgress, .completed], "senza `cancel`, niente Cancelled")
            #expect(!model.drop(["o1"], on: .cancelled))
            #expect(model.quickActions.cancelling == nil)
            #expect(model.drop(["o1"], on: .completed))
            #expect(model.quickActions.completion != nil, "Completed apre le note di chiusura")
        }

        @Test func aRoleWithoutAnyStatusActionLeavesAClosedCardWithoutMoves() async throws {
            let backend = try await Roles.member(Roles.workOrders())
            stubRoutes(orders: [TestEnv.orderJSON(id: "o1", status: "verified")])
            let model = AdminTaskboardViewModel(backend: backend)
            await model.load()

            #expect(model.moveChoices(for: model.card(try #require(model.orders.first))).isEmpty, "il menu Move to… non c'è")
        }
    }

    // MARK: - Scheda Task dell'operatore

    @Suite("Role-gated task tab")
    struct TaskTab {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        @Test func theOperatorTaskTabNeverSendsScopeEvenForAFollowedRole() async throws {
            let (backend, store) = try await TestEnv.signedInStore()
            let profile = #"{"id":"u1","name":"M","email":"m@a.b","availability":"available","availabilityAt":"2026-10-09T07:00:00Z"}"#
            server.route("GET /v1/me", .json(#"{"id":"u1","name":"M","membership":{"role":"member","restricted":true},"access":\#(Roles.workOrders(["complete"])),"operatorProfile":\#(profile)}"#))
            server.route("PUT /v1/me/availability", .json(profile))
            server.route("GET /v1/work-orders", .json("[\(TestEnv.orderJSON(id: "o1"))]"))
            await backend.refreshMembership()
            #expect(backend.rights.followsRole)

            await store.sync()

            let calls = server.calls("GET /v1/work-orders")
            #expect(!calls.isEmpty && store.orders.map(\.id) == ["o1"])
            #expect(calls.allSatisfy { $0.query?.contains("scope") != true }, "Task: nessun scope, solo i propri ordini aperti")
        }
    }

    // MARK: - Azioni rapide

    @Suite("Role-gated work order actions")
    struct QuickActions {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        /// Un solo backend per test: i diritti si cambiano con `TestEnv.grant`, le azioni li leggono ogni volta.
        private func makeActions(_ access: String?) async throws -> (backend: AriaBackend, actions: AdminWorkOrderQuickActions) {
            let backend = try await Roles.member(access)
            return (backend, AdminWorkOrderQuickActions(backend: backend))
        }

        @Test func anOpenOrderOffersOnlyTheStatusesWhoseActionTheRoleHas() async throws {
            let open = try gateOrder("assigned")
            let (backend, actions) = try await makeActions(Roles.workOrders())
            #expect(actions.statusChoices(for: open) == [.proposed, .planned, .inProgress], "i passaggi senza azione restano")

            await TestEnv.grant(Roles.workOrders(["complete"]), to: backend)
            #expect(actions.statusChoices(for: open) == [.proposed, .planned, .inProgress, .completed])

            await TestEnv.grant(Roles.workOrders(["complete", "cancel"]), to: backend)
            #expect(actions.statusChoices(for: open) == [.proposed, .planned, .inProgress, .completed, .cancelled])
        }

        @Test func aCompletedOrderReopensFreelyAndAClosedOneOnlyToProposedWithReopen() async throws {
            let done = try gateOrder("completed"), verified = try gateOrder("verified"), cancelled = try gateOrder("cancelled")
            let (backend, actions) = try await makeActions(Roles.workOrders(["complete", "cancel"]))
            #expect(actions.statusChoices(for: done) == [.proposed, .planned, .assigned, .inProgress],
                    "da Completed basta la sezione; Cancelled no (409)")
            #expect(actions.statusChoices(for: verified).isEmpty && actions.statusChoices(for: cancelled).isEmpty)

            await TestEnv.grant(Roles.workOrders(["verify"]), to: backend)
            #expect(actions.statusChoices(for: done) == [.proposed, .planned, .assigned, .inProgress, .verified],
                    "Verified solo da Completed, con `verify`")

            await TestEnv.grant(Roles.workOrders(["reopen", "complete", "verify", "cancel"]), to: backend)
            #expect(actions.statusChoices(for: verified) == [.proposed], "il resto da Verified è 409")
            #expect(actions.statusChoices(for: cancelled) == [.proposed])
        }

        @Test(arguments: RoleGatedUnrestricted.allCases)
        func withoutLimitsEveryChoiceAndActionStaysAvailable(_ kind: RoleGatedUnrestricted) async throws {
            let (_, actions) = try await makeActions(kind.access)
            #expect(actions.statusChoices(for: try gateOrder("assigned")) == [.proposed, .planned, .inProgress, .completed, .cancelled])
            #expect(actions.statusChoices(for: try gateOrder("completed")) == [.proposed, .planned, .assigned, .inProgress, .verified])
            #expect(actions.statusChoices(for: try gateOrder("cancelled")) == [.proposed])
            let open = try gateOrder("assigned"), closed = try gateOrder("completed")
            #expect(actions.canComplete(open) && !actions.canComplete(closed))
            #expect(actions.canAutoAssign)
        }

        @Test func theCompleteSwipeAndAutoAssignFollowTheRole() async throws {
            let (backend, actions) = try await makeActions(Roles.workOrders(["verify"]))
            #expect(!actions.canComplete(try gateOrder("assigned")))
            #expect(!actions.canAutoAssign)

            await TestEnv.grant(Roles.workOrders(["complete", "auto_assign"]), to: backend)
            #expect(actions.canComplete(try gateOrder("assigned")))
            #expect(!actions.canComplete(try gateOrder("completed")), "un ordine chiuso non si completa")
            #expect(actions.canAutoAssign)
        }

        @Test func changingToAStatusTheRoleLacksDoesNothing() async throws {
            let (_, actions) = try await makeActions(Roles.workOrders(["verify"]))
            let open = try gateOrder("assigned"), closed = try gateOrder("verified")

            actions.change(open, to: .cancelled)
            actions.change(open, to: .completed)
            await actions.setStatus(closed, .proposed)
            await actions.setStatus(open, .completed)

            #expect(actions.cancelling == nil && actions.completion == nil)
            #expect(server.calls("PATCH /v1/work-orders/o1").isEmpty, "niente richiesta: il server la rifiuterebbe")
        }

        @Test func changingToAGrantedStatusGoesThrough() async throws {
            server.route("PATCH /v1/work-orders/o1", .json(TestEnv.orderJSON(id: "o1", status: "verified")))
            let (_, actions) = try await makeActions(Roles.workOrders(["verify", "cancel", "complete"]))
            var saved: [AdminWorkOrder] = []
            actions.onUpdated = { saved.append($0) }
            let done = try gateOrder("completed"), open = try gateOrder("assigned")

            await actions.setStatus(done, .verified)
            actions.change(open, to: .cancelled)
            actions.change(open, to: .completed)

            #expect(saved.map(\.status) == [.verified])
            #expect(server.calls("PATCH /v1/work-orders/o1").first?.json?["status"] as? String == "verified")
            #expect(actions.cancelling?.id == "o1" && actions.completion != nil, "Cancelled chiede conferma, Completed le note")
        }

        @Test func autoAssignWithoutTheActionNeverReachesTheServer() async throws {
            server.route("POST /v1/work-orders/o1/auto-assign", .json(#"{"assigned":false,"note":"Nobody"}"#))
            let (backend, actions) = try await makeActions(Roles.workOrders(["complete"]))
            var reloaded: [String] = []
            actions.onReload = { reloaded.append($0) }

            await actions.autoAssign(try gateOrder("assigned"))
            #expect(server.calls("POST /v1/work-orders/o1/auto-assign").isEmpty)
            #expect(actions.outcome == nil && reloaded.isEmpty)

            await TestEnv.grant(Roles.workOrders(["auto_assign"]), to: backend)
            await actions.autoAssign(try gateOrder("assigned"))
            #expect(server.calls("POST /v1/work-orders/o1/auto-assign").count == 1)
            #expect(actions.outcome != nil && reloaded == ["o1"])
        }

        @Test func theDetailHidesAutoAssignAndTheStatusMenuTheRoleCannotUse() async throws {
            let backend = try await Roles.member(Roles.workOrders(["complete"]))
            let list = AdminWorkOrdersViewModel(backend: backend)

            let open = AdminWorkOrderDetailViewModel(order: try gateOrder("assigned"), list: list)
            #expect(!open.canAutoAssign)
            #expect(open.canChangeStatus && open.statusChoices.contains(.completed))
            let closed = AdminWorkOrderDetailViewModel(order: try gateOrder("cancelled"), list: list)
            #expect(!closed.canChangeStatus, "nessuno stato da offrire: si legge e basta")

            await TestEnv.grant(nil, to: backend)
            #expect(open.canAutoAssign && closed.canChangeStatus, "senza limiti torna tutto")
        }
    }

    // MARK: - Anagrafica e form

    @Suite("Role-gated work order directory")
    struct Directory {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        private func stubRoutes() {
            server.route("GET /v1/lookups/people", .json(#"[{"id":"u1","full_name":"Anna Bianchi"}]"#))
            server.route("GET /v1/lookups/teams", .json(#"[{"id":"t1","name":"Mechanics"}]"#))
            server.route("GET /v1/lookups/dispatch-candidates", .json(#"[{"id":"u1","name":"Anna Bianchi","availability":"available"}]"#))
            server.route("GET /v1/assets", .json(#"[{"tag":"A1","name":"Pump"}]"#))
            server.route("GET /v1/users", .json(#"[{"id":"u1","full_name":"Anna Bianchi"}]"#))
            server.route("GET /v1/teams", .json(#"[{"id":"t1","name":"Mechanics"}]"#))
            server.route("GET /v1/mobile-operators", .json(#"[{"id":"u1","name":"Anna Bianchi","email":"a@a.b"}]"#))
        }

        private func makeForm(_ backend: AriaBackend) -> AdminWorkOrderFormViewModel {
            AdminWorkOrderFormViewModel(mode: .create, backend: backend, directory: AdminWorkOrderDirectory(backend: backend), onSaved: { _ in })
        }

        @Test func theFormStatusPickerFollowsTheLifecycleAndTheRole() async throws {
            let backend = try await Roles.member(Roles.workOrders())
            let directory = AdminWorkOrderDirectory(backend: backend)
            func edit(_ status: String) throws -> AdminWorkOrderFormViewModel {
                AdminWorkOrderFormViewModel(mode: .edit(try gateOrder(status)), backend: backend, directory: directory, onSaved: { _ in })
            }

            #expect(try edit("completed").statusOptions == [.proposed, .planned, .assigned, .inProgress, .completed],
                    "da Completed basta la sezione; Verified vuole `verify`, Cancelled è 409")
            #expect(try !edit("verified").showsStatusPicker, "senza `reopen` un ordine verificato non si sposta")
            #expect(makeForm(backend).statusOptions == [.proposed, .planned, .assigned, .inProgress])

            await TestEnv.grant(Roles.workOrders(["reopen", "complete"]), to: backend)
            #expect(try edit("verified").statusOptions == [.proposed, .verified], "da Verified si esce solo verso Proposed")
            #expect(makeForm(backend).statusOptions == [.proposed, .planned, .assigned, .inProgress, .completed])
        }

        @Test func aNewTaskInAClosedColumnNeedsThatColumnsAction() async throws {
            let backend = try await Roles.member(Roles.workOrders())
            #expect(AdminTaskboardCreateViewModel(backend: backend, status: .completed, onCreated: { _ in }).status == .planned)
            #expect(AdminTaskboardCreateViewModel(backend: backend, status: .inProgress, onCreated: { _ in }).status == .inProgress)

            await TestEnv.grant(Roles.workOrders(["complete"]), to: backend)
            #expect(AdminTaskboardCreateViewModel(backend: backend, status: .completed, onCreated: { _ in }).status == .completed)
        }

        @Test func theDirectoryOfARoleWithoutAssetsFillsFromTheLookupsAndSkipsAssets() async throws {
            let backend = try await Roles.member(Roles.workOrders())
            stubRoutes()
            let form = makeForm(backend)

            await form.loadChoices()

            let directory = form.directory
            #expect(directory.users.map(\.id) == ["u1"] && directory.teams.map(\.id) == ["t1"] && directory.operators.map(\.id) == ["u1"])
            #expect(directory.assets.isEmpty && directory.unavailable.isEmpty && !form.assetsUnavailable)
            #expect(!directory.canChooseAssets && !form.canChooseAsset, "la riga dell'asset non c'è")
            for route in ["GET /v1/assets", "GET /v1/users", "GET /v1/teams", "GET /v1/mobile-operators"] {
                #expect(server.calls(route).isEmpty, "\(route)")
            }
        }

        @Test func aRoleWithAssetsOffersThemAndWithoutLimitsEverythingIsAsBefore() async throws {
            let backend = try await Roles.member(Roles.access(["work_orders": [], "assets": []]))
            stubRoutes()
            let granted = makeForm(backend)
            await granted.loadChoices()
            #expect(granted.canChooseAsset && granted.directory.assets.map(\.tag) == ["A1"])

            let lookupCalls = server.calls("GET /v1/lookups/people").count
            var operatorCalls = server.calls("GET /v1/mobile-operators").count
            for kind in RoleGatedUnrestricted.allCases {
                await TestEnv.grant(kind.access, to: backend)
                let free = makeForm(backend)
                await free.loadChoices()
                operatorCalls += 1
                #expect(free.canChooseAsset && free.directory.assets.map(\.tag) == ["A1"], "\(kind)")
                #expect(free.directory.users.map(\.id) == ["u1"] && server.calls("GET /v1/mobile-operators").count == operatorCalls)
                #expect(server.calls("GET /v1/lookups/people").count == lookupCalls, "senza limiti, niente anagrafica")
            }
        }
    }

    // MARK: - Maintenance

    @Suite("Role-gated maintenance")
    struct Maintenance {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        private func plan(status: String = "approved") throws -> AdminMaintenancePlan {
            let json = #"{"id":"mp1","name":"Lube","frequency":"monthly","status":"\#(status)","assetTag":"A1","plantId":"p1"}"#
            return try JSONDecoder().decode(AdminMaintenancePlan.self, from: Data(json.utf8))
        }

        private func role(_ maintenance: [String] = [], _ extra: [String] = []) -> String {
            var sections = ["maintenance": maintenance]
            for slug in extra { sections[slug] = [] }
            return Roles.access(sections)
        }

        private func stubRoutes() {
            server.route("GET /v1/maintenance-plans/mp1", .json(#"{"id":"mp1","name":"Lube","frequency":"monthly","status":"approved","asset_tag":"A1","plant_id":"p1"}"#))
            server.route("GET /v1/work-orders", .json("""
            [{"id":"w1","title":"Lube round","status":"assigned","maintenance_plan_id":"mp1"},
             {"id":"w2","title":"Other plan","status":"assigned","maintenance_plan_id":"mp2"}]
            """))
            server.route("GET /v1/audit-log", .json(#"{"items":[{"id":"a1","action":"update","user_id":"u2"}],"total":1}"#))
            server.route("GET /v1/lookups/people", .json(#"[{"id":"u2","full_name":"Anna Bianchi"}]"#))
            server.route("GET /v1/users", .json(#"[{"id":"u2","full_name":"Anna Bianchi"}]"#))
            server.route("GET /v1/assets", .json(#"[{"tag":"A1","name":"Pump"}]"#))
        }

        // Storico e persone

        @Test func theHistoryNeedsAuditLogAndReadsPeopleFromTheLookups() async throws {
            let backend = try await Roles.member(role([], ["audit_log"]))
            stubRoutes()
            let history = AdminMaintenanceHistoryViewModel(planId: "mp1", backend: backend)

            await history.load()

            #expect(history.entries.map(\.id) == ["a1"])
            #expect(server.calls("GET /v1/audit-log").count == 1)
            #expect(server.calls("GET /v1/lookups/people").count == 1)
            #expect(server.calls("GET /v1/users").isEmpty, "servono members: il ruolo non li ha")
        }

        @Test func withoutAuditLogTheHistoryIsHiddenAndNeverRequested() async throws {
            let backend = try await Roles.member(role())
            stubRoutes()
            let history = AdminMaintenanceHistoryViewModel(planId: "mp1", backend: backend)
            let detail = AdminMaintenanceDetailViewModel(backend: backend, plan: try plan(), onChange: { _ in })

            await history.load()
            await history.loadMore()
            await detail.load()

            #expect(history.entries.isEmpty && detail.history == nil)
            #expect(server.calls("GET /v1/audit-log").isEmpty && server.calls("GET /v1/lookups/people").isEmpty)
            #expect(!server.calls("GET /v1/maintenance-plans/mp1").isEmpty, "il resto del dettaglio si carica")
        }

        @Test(arguments: RoleGatedUnrestricted.allCases)
        func withoutLimitsTheHistoryUsesAuditLogAndUsers(_ kind: RoleGatedUnrestricted) async throws {
            let backend = try await Roles.member(kind.access)
            stubRoutes()
            let detail = AdminMaintenanceDetailViewModel(backend: backend, plan: try plan(), onChange: { _ in })
            let history = try #require(detail.history)

            await history.load()

            #expect(history.entries.map(\.id) == ["a1"])
            #expect(server.calls("GET /v1/users").first?.query == "active_only=true")
            #expect(server.calls("GET /v1/lookups/people").isEmpty)
        }

        // Ordini generati

        @Test func generatedOrdersNeedWorkOrdersAndAskForEveryonesOrders() async throws {
            let backend = try await Roles.member(role([], ["work_orders"]))
            stubRoutes()
            let detail = AdminMaintenanceDetailViewModel(backend: backend, plan: try plan(), onChange: { _ in })

            await detail.load()

            #expect(detail.showsWorkOrders)
            #expect(detail.workOrders.map(\.id) == ["w1"], "solo quelli del piano")
            #expect(server.calls("GET /v1/work-orders").first?.query?.contains("scope=all") == true)
        }

        @Test func withoutWorkOrdersTheGeneratedOrdersAreNotRequested() async throws {
            let backend = try await Roles.member(role([], ["audit_log"]))
            stubRoutes()
            let detail = AdminMaintenanceDetailViewModel(backend: backend, plan: try plan(), onChange: { _ in })

            await detail.load()

            #expect(!detail.showsWorkOrders && detail.workOrders.isEmpty)
            #expect(server.calls("GET /v1/work-orders").isEmpty)
            #expect(!server.calls("GET /v1/maintenance-plans/mp1").isEmpty)
        }

        @Test(arguments: RoleGatedUnrestricted.allCases)
        func withoutLimitsTheGeneratedOrdersAreLoadedAsBefore(_ kind: RoleGatedUnrestricted) async throws {
            let backend = try await Roles.member(kind.access)
            stubRoutes()
            let detail = AdminMaintenanceDetailViewModel(backend: backend, plan: try plan(), onChange: { _ in })

            await detail.load()

            #expect(detail.showsWorkOrders && detail.workOrders.map(\.id) == ["w1"])
        }

        @Test func peopleComeFromTheLookupsOnlyForARoleBasedMember() async throws {
            stubRoutes()
            let backend = try await Roles.member(role())
            let people = try await AdminMaintenanceAPI.people(api: backend.api, rights: backend.rights)
            #expect(people.map(\.displayName) == ["Anna Bianchi"] && server.calls("GET /v1/users").isEmpty)

            await TestEnv.grant(nil, to: backend)
            let all = try await AdminMaintenanceAPI.people(api: backend.api, rights: backend.rights)
            #expect(all.map(\.id) == ["u2"] && server.calls("GET /v1/users").count == 1)
            #expect(server.calls("GET /v1/lookups/people").count == 1, "la seconda volta non passa dall'anagrafica")
        }

        // Form: stati e asset

        @Test func theStatusOptionsOfAnApprovedPlanFollowApproveUnapproveAndReject() async throws {
            let backend = try await Roles.member(role())
            let form = AdminMaintenanceFormViewModel(backend: backend, editing: try plan(status: "approved"))
            #expect(form.statusOptions == ["approved"] && !form.showsStatus, "il picker non offre scelta: non c'è")

            await TestEnv.grant(role(["reject"]), to: backend)
            #expect(form.statusOptions == ["approved"] && !form.showsStatus, "rifiutare un approvato vuole anche unapprove")

            await TestEnv.grant(role(["reject", "unapprove"]), to: backend)
            #expect(form.statusOptions == ["approved", "draft", "staged", "rejected", "superseded"])

            await TestEnv.grant(role(["unapprove"]), to: backend)
            #expect(form.statusOptions == ["approved", "draft", "staged"], "superato vuole reject")

            await TestEnv.grant(role(["unapprove", "reject", "approve"]), to: backend)
            #expect(form.statusOptions == AdminMaintenanceStatus.allCases.map(\.rawValue))
        }

        @Test func aPlanThatIsNotApprovedNeedsApproveAndRejectOnlyForThoseStatuses() async throws {
            let backend = try await Roles.member(role())
            let form = AdminMaintenanceFormViewModel(backend: backend, editing: try plan(status: "draft"))
            #expect(form.statusOptions == ["draft", "staged"], "da bozza non serve `unapprove`; superato vuole reject")

            await TestEnv.grant(role(["approve", "reject"]), to: backend)
            #expect(form.statusOptions == AdminMaintenanceStatus.allCases.map(\.rawValue))
        }

        // Dettaglio: Approve e Reject

        @Test func aPlanOffersTheDecisionsOfItsStatusThatTheRoleHolds() async throws {
            let backend = try await Roles.member(role())
            let detail = AdminMaintenanceDetailViewModel(backend: backend, plan: try plan(status: "draft"), onChange: { _ in })
            #expect(detail.reviewActions.isEmpty && !detail.showsReview, "senza diritti niente avviso")

            await TestEnv.grant(role(["approve"]), to: backend)
            #expect(detail.reviewActions == [.approve] && detail.showsReview)
            await TestEnv.grant(role(["reject"]), to: backend)
            #expect(detail.reviewActions == [.reject])

            let approved = AdminMaintenanceDetailViewModel(backend: backend, plan: try plan(), onChange: { _ in })
            await TestEnv.grant(role(["approve", "reject"]), to: backend)
            #expect(approved.reviewActions.isEmpty, "da approvato servono unapprove (e reject)")
            await TestEnv.grant(role(["approve", "reject", "unapprove"]), to: backend)
            #expect(approved.reviewActions == [.reject, .unapprove] && approved.showsReview)

            for kind in RoleGatedUnrestricted.allCases {
                await TestEnv.grant(kind.access, to: backend)
                #expect(detail.reviewActions == [.reject, .approve], "\(kind)")
            }
        }

        @Test func reviewingADraftPatchesOnlyTheStatus() async throws {
            let backend = try await Roles.member(role(["approve", "reject"]))
            for action in [AdminReviewAction.approve, .reject] {
                server.route("PATCH /v1/maintenance-plans/mp1",
                             .json(#"{"id":"mp1","name":"Lube","frequency":"monthly","status":"\#(action.target)"}"#))
                let detail = AdminMaintenanceDetailViewModel(backend: backend, plan: try plan(status: "draft"), onChange: { _ in })

                await detail.review(action)

                let body = server.calls("PATCH /v1/maintenance-plans/mp1").last?.json
                #expect(body?["status"] as? String == action.target && body?.count == 1)
                #expect(detail.plan.status == action.target && detail.reviewError == nil && detail.reviewing == nil)
            }
        }

        @Test func aNewPlanStartsAsDraftUnlessTheRoleCanApprove() async throws {
            let backend = try await Roles.member(role())
            let draft = AdminMaintenanceFormViewModel(backend: backend, editing: nil)
            #expect(draft.status == "draft" && !draft.statusOptions.contains("approved"))

            await TestEnv.grant(role(["approve"]), to: backend)
            #expect(AdminMaintenanceFormViewModel(backend: backend, editing: nil).status == "approved")

            for kind in RoleGatedUnrestricted.allCases {
                await TestEnv.grant(kind.access, to: backend)
                let free = AdminMaintenanceFormViewModel(backend: backend, editing: nil)
                #expect(free.status == "approved" && free.statusOptions == AdminMaintenanceStatus.allCases.map(\.rawValue), "\(kind)")
            }
        }

        @Test func theAssetPickerNeedsTheAssetsSection() async throws {
            stubRoutes()
            let backend = try await Roles.member(role())
            let without = AdminMaintenanceFormViewModel(backend: backend, editing: nil)
            await without.loadAssets()
            #expect(without.assets.isEmpty && server.calls("GET /v1/assets").isEmpty, "il tag si scrive a mano")

            await TestEnv.grant(role([], ["assets"]), to: backend)
            let with = AdminMaintenanceFormViewModel(backend: backend, editing: nil)
            await with.loadAssets()
            #expect(with.assets.map(\.tag) == ["A1"])
            #expect(server.calls("GET /v1/assets").first?.query == "status=approved")
        }
    }
}
