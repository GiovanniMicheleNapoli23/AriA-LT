//
//  RolesAndRightsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 12/11/26.
//
//  La sezione Roles & Rights (guida del 12/11/2026): chi la vede, chi cambia quale ruolo, "Non incluso nel tuo
//  ruolo", la nota "Solo consultazione", le scelte del ruolo predefinito e dell'eliminazione, i codici di rifiuto
//  e i body che il server distingue (`{"moveTo": null}` contro nessun body).
//

import Foundation
import Testing
@testable import AriaLite

// MARK: - Senza rete

struct RolesAndRightsPureTests {
    private func access(_ json: String) throws -> AriaAccess {
        try JSONDecoder().decode(AriaAccess.self, from: Data(json.utf8))
    }

    private func rights(model: String = "rbac", admin: Bool = false, set: String = "high", canManage: Bool = true,
                        follows: Bool = true) throws -> AriaRights {
        let role = admin ? "null" : #"{"id":"r1","name":"Manager","set":"\#(set)","enabled":true}"#
        return AriaRights(access: try access(TestEnv.accessJSON(model: model, admin: admin, role: role, sections: "{}",
                                                                followsRole: follows, canManageRoles: canManage)))
    }

    @Test func theSectionIsOfferedOnlyToWhoManagesRolesInACompanyOnRoles() throws {
        #expect(try rights(admin: true, follows: false).canOpenRolesAndRights, "owner o admin: sempre")
        #expect(try rights(set: "high").canOpenRolesAndRights, "ruolo alto che segue l'app")
        #expect(try !rights(set: "high", follows: false).canOpenRolesAndRights, "membro senza appFollowsRole: operation_forbidden")
        #expect(try !rights(set: "low", canManage: false).canOpenRolesAndRights, "ruolo base")
        #expect(try !rights(model: "legacy", admin: true).canOpenRolesAndRights, "azienda legacy, nemmeno l'owner")
        #expect(!AriaRights(access: nil).canOpenRolesAndRights, "access non letto")
    }

    @Test func theSidebarOffersRolesAndRightsInBothLayouts() throws {
        let admin = try rights(admin: true)
        #expect(AriaSidebarSections.destinations(operatorLayout: false, rights: admin).contains(.adminRoles))
        let high = try rights(set: "high")
        #expect(AriaSidebarSections.destinations(operatorLayout: true, rights: high).contains(.adminRoles))
        let low = try rights(set: "low", canManage: false)
        #expect(!AriaSidebarSections.destinations(operatorLayout: true, rights: low).contains(.adminRoles))
        #expect(!AriaSidebarSections.destinations(operatorLayout: false, rights: .unrestricted).contains(.adminRoles),
                "un backend senza `access`: niente sezione")
    }

    @Test func theViewerComesFromTheAccessBlock() throws {
        #expect(AdminRolesViewer(access: try access(TestEnv.accessJSON(admin: true, role: nil, sections: "{}", canManageRoles: true))) == .admin)
        let high = try access(TestEnv.accessJSON(role: #"{"id":"r1","name":"Manager","set":"high","enabled":true}"#,
                                                 sections: #"{"work_orders":{"granted":true,"actions":["complete"]},"assets":{"granted":false,"actions":["approve"]}}"#,
                                                 canManageRoles: true))
        guard case .high(let roleId, let holds)? = AdminRolesViewer(access: high) else {
            Issue.record("un ruolo alto attivo dovrebbe essere .high")
            return
        }
        #expect(roleId == "r1")
        #expect(holds == ["work_orders": ["complete"]], "solo le sezioni concesse")
        let low = try access(TestEnv.accessJSON(canManageRoles: false))
        #expect(AdminRolesViewer(access: low) == nil)
    }

    @Test func roleRefusalsKeepTheirCode() {
        func refusal(_ status: Int, _ code: String) -> AriaError? {
            let response = HTTPURLResponse(url: URL(string: "https://api.test/x")!, statusCode: status, httpVersion: nil, headerFields: nil)!
            do {
                try AriaHTTP.check(response, Data(#"{"detail":{"code":"\#(code)","message":"m"}}"#.utf8))
                return nil
            } catch { return error as? AriaError }
        }
        for code in AriaAccessRefusal.allCases {
            guard case .accessRefused(let found)? = refusal(409, code.rawValue) else {
                Issue.record("\(code.rawValue) dovrebbe restare un rifiuto dei ruoli")
                continue
            }
            #expect(found == code)
        }
        guard case .http(404, _)? = refusal(404, "not_found") else {
            Issue.record("not_found resta un 404 qualsiasi")
            return
        }
        guard case .permissionDenied? = refusal(403, "permission_denied") else {
            Issue.record("permission_denied non cambia")
            return
        }
    }

    @Test func nullBodiesAreSentAsNull() throws {
        let encoder = JSONEncoder()
        #expect(String(decoding: try encoder.encode(AdminRoleDeleteMove(moveTo: nil)), as: UTF8.self) == #"{"moveTo":null}"#)
        #expect(String(decoding: try encoder.encode(AdminRoleDeleteMove(moveTo: "r2")), as: UTF8.self) == #"{"moveTo":"r2"}"#)
        #expect(String(decoding: try encoder.encode(AdminRoleAssignment(roleId: nil)), as: UTF8.self) == #"{"roleId":null}"#)
    }

    @Test func roleDecodesTheServerShape() throws {
        let json = #"{"id":"6af","name":"Night shift","set":"low","enabled":true,"grants":{"work_orders":["complete"],"vendors":[]},"ownerRoleId":"6ae","createdBy":"u9","createdByName":"Opfield","holders":3,"isDefault":false,"exceedsOwner":false,"editable":true,"version":4,"seedKey":null}"#
        let role = try JSONDecoder().decode(AdminRole.self, from: Data(json.utf8))
        #expect(role.set == .low)
        #expect(role.grants == ["work_orders": ["complete"], "vendors": []])
        #expect(role.ownerRoleId == "6ae")
        #expect(role.version == 4)
        #expect(role.holders == 3)
        let catalog = try JSONDecoder().decode(AdminRoleCatalog.self, from: Data(#"{"sections":[{"section":"work_orders","group":"operational","labelKey":"sidebar.workOrders","highOnly":false,"actions":[{"action":"verify","kind":"validation"},{"action":"complete","kind":"extra"}]},{"section":"new_thing","group":"future","actions":[]}]}"#.utf8))
        #expect(catalog.sections.map(\.actions) == [["verify", "complete"], []])
        #expect(catalog.sections.last?.group == nil, "un gruppo sconosciuto non fa cadere il catalogo")
        #expect(AdminRoleNames.section("new_thing") == "new_thing", "uno slug sconosciuto si mostra com'è")
    }

    @Test func aSectionSummaryNamesFewActionsAndCountsMany() {
        #expect(AdminRoleNames.summary(isOn: false, onActions: [], total: 3) == String(localized: "roles.summary.off", defaultValue: "Off"))
        #expect(AdminRoleNames.summary(isOn: true, onActions: [], total: 3) == String(localized: "View only"), "accesa, nessuna azione")
        #expect(AdminRoleNames.summary(isOn: true, onActions: ["verify"], total: 3) == AdminRoleNames.action("verify"))
        #expect(AdminRoleNames.summary(isOn: true, onActions: ["verify", "complete"], total: 3)
                == "\(AdminRoleNames.action("verify")), \(AdminRoleNames.action("complete"))")
        #expect(AdminRoleNames.summary(isOn: true, onActions: ["verify", "complete", "reopen"], total: 5) == String(localized: "\(3) of \(5) actions"))
        #expect(AdminRoleNames.summary(isOn: true, onActions: ["verify", "complete", "reopen"], total: 3) == String(localized: "All actions"))
        #expect(AdminRoleNames.summary(isOn: true, onActions: ["verify"], total: 1) == String(localized: "All actions"), "una sola azione, accesa")
    }
}

// MARK: - Con la rete finta

extension BackendTests {
    @Suite("Roles & Rights")
    @MainActor
    struct RolesAndRights {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        private static let base = "/v1/companies/c1/access"
        private static let manager = #"{"id":"rH","name":"Manager","set":"high","enabled":true}"#

        private static let catalog = #"""
        {"sections":[
          {"section":"work_orders","group":"operational","labelKey":"sidebar.workOrders","highOnly":false,"actions":[{"action":"verify","kind":"validation"},{"action":"complete","kind":"extra"}]},
          {"section":"assets","group":"resources","labelKey":"sidebar.assets","highOnly":false,"actions":[{"action":"approve","kind":"validation"}]},
          {"section":"vendors","group":"purchases","labelKey":"sidebar.vendors","highOnly":false,"actions":[{"action":"create","kind":"extra"}]},
          {"section":"audit_log","group":"configuration","labelKey":"sidebar.auditLog","highOnly":true,"actions":[]}
        ]}
        """#

        private static func role(_ id: String, set: String = "low", enabled: Bool = true, grants: String = "{}",
                                 owner: String? = "rH", holders: Int = 0, isDefault: Bool = false,
                                 editable: Bool = true, version: Int = 1) -> String {
            let ownerJSON = owner.map { "\"\($0)\"" } ?? "null"
            return #"{"id":"\#(id)","name":"Role \#(id)","set":"\#(set)","enabled":\#(enabled),"grants":\#(grants),"ownerRoleId":\#(ownerJSON),"holders":\#(holders),"isDefault":\#(isDefault),"exceedsOwner":false,"editable":\#(editable),"version":\#(version)}"#
        }

        private static func roles(_ items: String...) -> String { #"{"roles":[\#(items.joined(separator: ","))]}"# }

        private func connected(admin: Bool) async throws -> AriaBackend {
            let backend = try await TestEnv.signedInStore().backend
            if admin {
                await TestEnv.grant(TestEnv.accessJSON(admin: true, role: nil, sections: "{}", canManageRoles: true),
                                    to: backend, restricted: false)
            } else {
                // Il ruolo alto ha i lavori (solo `complete`) e niente altro.
                await TestEnv.grant(TestEnv.accessJSON(role: Self.manager,
                                                       sections: #"{"work_orders":{"granted":true,"actions":["complete"]}}"#,
                                                       canManageRoles: true), to: backend)
            }
            return backend
        }

        private func loaded(_ backend: AriaBackend, roles: String) async -> AdminRolesViewModel {
            server.route("GET \(Self.base)/catalog", .json(Self.catalog))
            server.route("GET \(Self.base)/roles", .json(roles))
            let viewModel = AdminRolesViewModel(backend: backend)
            await viewModel.load()
            return viewModel
        }

        // MARK: Chi cambia cosa

        @Test func aHighHolderChangesOnlyTheLowRolesItsRoleCreated() async throws {
            let backend = try await connected(admin: false)
            let viewModel = await loaded(backend, roles: Self.roles(
                Self.role("rH", set: "high", owner: nil), Self.role("mine"), Self.role("other", owner: "rX"),
                Self.role("locked", editable: false)))
            #expect(viewModel.placeholder == nil)
            let byId = Dictionary(uniqueKeysWithValues: viewModel.roles.map { ($0.id, $0) })
            #expect(!viewModel.mayChange(byId["rH"]!), "il proprio ruolo è solo da guardare")
            #expect(viewModel.mayChange(byId["mine"]!))
            #expect(!viewModel.mayChange(byId["other"]!), "un ruolo base di un altro ruolo alto")
            #expect(!viewModel.mayChange(byId["locked"]!), "editable falso: vale la risposta del server")
            #expect(viewModel.ownRole?.id == "rH")
            #expect(viewModel.highRoles.isEmpty)
            #expect(viewModel.lowRoles.map(\.id) == ["mine", "other", "locked"])
            #expect(!viewModel.showsDefaultRole)
        }

        @Test func notInYourRoleFollowsTheTable() async throws {
            let backend = try await connected(admin: false)
            let viewModel = await loaded(backend, roles: Self.roles(
                Self.role("rH", set: "high", owner: nil),
                Self.role("mine", grants: #"{"assets":["approve"],"work_orders":[]}"#)))
            let role = try #require(viewModel.role(id: "mine"))
            let rows = Dictionary(uniqueKeysWithValues: viewModel.sectionGroups(for: role).flatMap(\.rows).map { ($0.section, $0) })

            #expect(rows["audit_log"] == nil, "highOnly non si offre a un ruolo base")
            // Il suo ruolo ha la sezione: usabile, senza segno.
            let work = try #require(rows["work_orders"])
            #expect(work.isEnabled && !work.notInYourRole)
            // L'azione che ha: usabile; quella che non ha, spenta: non si aggiunge.
            let chips = Dictionary(uniqueKeysWithValues: work.chips.map { ($0.action, $0) })
            #expect(chips["complete"]?.isEnabled == true && chips["complete"]?.notInYourRole == false)
            #expect(chips["verify"]?.isEnabled == false && chips["verify"]?.notInYourRole == true)
            // Non l'ha, ma è accesa: si può togliere, col segno.
            let assets = try #require(rows["assets"])
            #expect(assets.isEnabled && assets.notInYourRole)
            #expect(assets.chips.first?.isEnabled == true && assets.chips.first?.notInYourRole == true)
            // Non l'ha ed è spenta: non si aggiunge.
            let vendors = try #require(rows["vendors"])
            #expect(!vendors.isEnabled && vendors.notInYourRole && vendors.chips.isEmpty)

            // Sul proprio ruolo nessun segno e niente da toccare.
            let own = try #require(viewModel.role(id: "rH"))
            let ownRows = viewModel.sectionGroups(for: own).flatMap(\.rows)
            #expect(ownRows.allSatisfy { !$0.isEnabled && !$0.notInYourRole })
            #expect(ownRows.contains { $0.section == "audit_log" }, "un ruolo alto vede anche le sezioni highOnly")
        }

        @Test func adminsNeverSeeNotInYourRoleAndLookOnlyNeedsActionsOff() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(
                Self.role("a", grants: #"{"vendors":[],"assets":[]}"#, owner: nil),
                Self.role("b", grants: #"{"vendors":["create"]}"#, owner: nil)))
            let a = try #require(viewModel.role(id: "a"))
            let rowsA = Dictionary(uniqueKeysWithValues: viewModel.sectionGroups(for: a).flatMap(\.rows).map { ($0.section, $0) })
            #expect(rowsA.values.allSatisfy { $0.isEnabled && !$0.notInYourRole })
            #expect(rowsA["vendors"]?.showsLookOnlyHint == true)
            #expect(rowsA["assets"]?.showsLookOnlyHint == false, "assets non è una delle nove sezioni da guardare")
            #expect(rowsA["work_orders"]?.showsLookOnlyHint == false, "spenta")
            let b = try #require(viewModel.role(id: "b"))
            #expect(viewModel.sectionGroups(for: b).flatMap(\.rows).first { $0.section == "vendors" }?.showsLookOnlyHint == false)
            #expect(viewModel.showsDefaultRole)
        }

        @Test func defaultPickerAndMoveTargetsOfferTheRightRoles() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(
                Self.role("H", set: "high", owner: nil), Self.role("pausedDefault", enabled: false, isDefault: true),
                Self.role("paused", enabled: false), Self.role("ok"), Self.role("gone", holders: 2)))
            #expect(viewModel.defaultOptions.map(\.id) == ["pausedDefault", "ok", "gone"])
            #expect(viewModel.currentDefault?.id == "pausedDefault")
            #expect(viewModel.pickerLabel(viewModel.role(id: "pausedDefault")!) == String(localized: "Role pausedDefault (paused)"))
            let gone = try #require(viewModel.role(id: "gone"))
            #expect(viewModel.moveTargets(deleting: gone).map(\.id) == ["H", "ok"], "ogni ruolo attivo tranne questo")
            #expect(!viewModel.mayDelete(viewModel.role(id: "pausedDefault")!), "il predefinito non si elimina")
            #expect(viewModel.mayChange(viewModel.role(id: "pausedDefault")!), "ma si mette in pausa")

            // Lo stesso predefinito non chiama il server.
            await viewModel.setDefault("pausedDefault")
            #expect(server.calls("PUT \(Self.base)/default-role").isEmpty)
        }

        @Test func aSummaryAndTheFlagsComeFromTheCatalogAndTheGrants() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(
                Self.role("a", set: "high", grants: #"{"work_orders":["complete"],"assets":["approve"],"vendors":[],"audit_log":[]}"#, owner: nil)))
            let role = try #require(viewModel.role(id: "a"))
            let rows = Dictionary(uniqueKeysWithValues: viewModel.sectionGroups(for: role).flatMap(\.rows).map { ($0.section, $0) })
            #expect(rows["work_orders"]?.summary == AdminRoleNames.action("complete"))
            #expect(rows["work_orders"]?.hasActions == true)
            #expect(rows["assets"]?.summary == String(localized: "All actions"))
            #expect(rows["vendors"]?.summary == String(localized: "View only"))
            #expect(rows["audit_log"]?.hasActions == false, "senza azioni nel catalogo: un solo interruttore")
        }

        @Test func thePathIsClearedWhenAScreenRefersToAVanishedRole() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(Self.role("a", owner: nil), Self.role("b", owner: nil)))
            viewModel.path = [.role("b"), .section(role: "b", section: "assets"), .person("u1")]
            await viewModel.reloadRoles()
            #expect(viewModel.path.count == 3, "il ruolo c'è ancora")

            server.route("GET \(Self.base)/roles", .json(Self.roles(Self.role("b", owner: nil))))
            for route in [AdminRolesViewModel.Route.role("a"), .people("a"), .section(role: "a", section: "assets")] {
                viewModel.path = [.role("b"), route]
                await viewModel.reloadRoles()
                #expect(viewModel.path.isEmpty, "\(route) riguarda un ruolo che non c'è più")
            }
            viewModel.path = [.person("u1")]
            await viewModel.reloadRoles()
            #expect(viewModel.path == [.person("u1")], "la scheda di una persona non dipende dal ruolo")
        }

        // MARK: Scritture

        @Test func writesCarryTheVersionOfTheLastAnswer() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(Self.role("a", owner: nil, version: 4)))
            server.route("PUT \(Self.base)/roles/a/enabled", .json(Self.role("a", enabled: false, owner: nil, version: 5)))
            // La rilettura non è ancora aggiornata: conta la risposta della scrittura.
            server.route("GET \(Self.base)/roles", .json(Self.roles(Self.role("a", enabled: false, owner: nil, version: 5))))
            await viewModel.setEnabled(try #require(viewModel.role(id: "a")), false)
            #expect(server.calls("PUT \(Self.base)/roles/a/enabled").last?.json?["version"] as? Int == 4)

            server.route("PUT \(Self.base)/roles/a/grants/vendors", .json(Self.role("a", enabled: false, grants: #"{"vendors":[]}"#, owner: nil, version: 6)))
            await viewModel.setSection("vendors", on: true, in: try #require(viewModel.role(id: "a")))
            let grant = try #require(server.calls("PUT \(Self.base)/roles/a/grants/vendors").last?.json)
            #expect(grant["version"] as? Int == 5)
            #expect(grant["enabled"] as? Bool == true)
            #expect((grant["actions"] as? [String]) == [])
            #expect(viewModel.busyRoleIds.isEmpty)
        }

        @Test func aStaleVersionPutsTheSwitchBackAndReloads() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(Self.role("a", owner: nil, version: 4)))
            server.route("PUT \(Self.base)/roles/a/enabled", .json(#"{"detail":{"code":"role_changed","message":"stale"}}"#, status: 409))
            server.route("GET \(Self.base)/roles", .json(Self.roles(Self.role("a", owner: nil, version: 7))))
            let before = server.calls("GET \(Self.base)/roles").count
            await viewModel.setEnabled(try #require(viewModel.role(id: "a")), false)
            #expect(viewModel.role(id: "a")?.enabled == true, "torna com'era")
            #expect(viewModel.role(id: "a")?.version == 7, "riletto")
            #expect(server.calls("GET \(Self.base)/roles").count == before + 1)
            #expect(viewModel.toast?.text == AriaAccessRefusal.roleChanged.localized)
            #expect(viewModel.toast?.isError == true)
        }

        @Test func aChipSendsTheWholeListInCatalogOrder() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(Self.role("a", grants: #"{"work_orders":["complete"]}"#, owner: nil)))
            server.route("PUT \(Self.base)/roles/a/grants/work_orders", .json(Self.role("a", grants: #"{"work_orders":["verify","complete"]}"#, owner: nil, version: 2)))
            await viewModel.toggleAction("verify", in: "work_orders", of: try #require(viewModel.role(id: "a")))
            let body = try #require(server.calls("PUT \(Self.base)/roles/a/grants/work_orders").last?.json)
            #expect((body["actions"] as? [String]) == ["verify", "complete"])
            #expect(body["enabled"] as? Bool == true)
        }

        @Test func deleteSendsNoBodyOrAnExplicitNull() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(
                Self.role("empty", owner: nil), Self.role("full", owner: nil, holders: 2)))
            server.route("DELETE \(Self.base)/roles/empty", .noContent)
            server.route("DELETE \(Self.base)/roles/full", .noContent)

            let empty = AdminRoleDeleteViewModel(role: try #require(viewModel.role(id: "empty")), owner: viewModel)
            #expect(!empty.asksWhereTo && empty.canConfirm)
            server.route("GET \(Self.base)/roles", .json(Self.roles(Self.role("full", owner: nil, holders: 2))))
            #expect(await empty.confirm())
            let noBody = try #require(server.calls("DELETE \(Self.base)/roles/empty").last)
            #expect(noBody.body.isEmpty, "senza body: si elimina solo se nessuno ha il ruolo")

            let full = AdminRoleDeleteViewModel(role: try #require(viewModel.role(id: "full")), owner: viewModel)
            #expect(full.asksWhereTo && !full.canConfirm, "prima si sceglie dove vanno")
            full.choice = .noRole
            server.route("GET \(Self.base)/roles", .json(Self.roles()))
            #expect(await full.confirm())
            let withNull = try #require(server.calls("DELETE \(Self.base)/roles/full").last)
            #expect(withNull.bodyText == #"{"moveTo":null}"#)
            #expect(withNull.header("Content-Type") == "application/json")
            #expect(viewModel.toast?.text == String(localized: "Role full deleted"))
        }

        @Test func someoneTakingTheRoleMeanwhileAsksWhereTheyGo() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(Self.role("a", owner: nil), Self.role("b", owner: nil)))
            server.route("DELETE \(Self.base)/roles/a", .json(#"{"detail":{"code":"role_has_members","message":"m"}}"#, status: 409))
            server.route("GET \(Self.base)/roles", .json(Self.roles(Self.role("a", owner: nil, holders: 1), Self.role("b", owner: nil))))
            let form = AdminRoleDeleteViewModel(role: try #require(viewModel.role(id: "a")), owner: viewModel)
            #expect(!(await form.confirm()), "la schermata resta aperta")
            #expect(form.asksWhereTo)
            #expect(form.targets.map(\.id) == ["b"])
        }

        @Test func aTakenNameStaysUnderTheField() async throws {
            let backend = try await connected(admin: true)
            let viewModel = await loaded(backend, roles: Self.roles(Self.role("a", owner: nil)))
            server.route("POST \(Self.base)/roles", .json(#"{"detail":{"code":"role_name_taken","message":"m"}}"#, status: 409))
            let form = AdminRoleCreateViewModel(owner: viewModel)
            form.name = "  Night shift  "
            #expect(!(await form.submit()))
            #expect(form.nameError == AriaAccessRefusal.roleNameTaken.localized)
            #expect(viewModel.toast == nil, "sotto il campo, non come avviso")
            let body = try #require(server.calls("POST \(Self.base)/roles").last?.json)
            #expect(body["name"] as? String == "Night shift")
            #expect(body["set"] as? String == "low")
            #expect((body["grants"] as? [String: Any])?.isEmpty == true)
            form.name = "Night crew"
            #expect(form.nameError == nil, "si toglie appena il nome cambia")
        }

        @Test func escalationDeniedRereadsTheViewersRights() async throws {
            let backend = try await connected(admin: false)
            let viewModel = await loaded(backend, roles: Self.roles(Self.role("rH", set: "high", owner: nil), Self.role("mine")))
            server.route("PUT \(Self.base)/roles/mine/grants/work_orders", .json(#"{"detail":{"code":"escalation_denied","message":"m"}}"#, status: 403))
            let before = server.calls("GET /v1/me").count
            await viewModel.setSection("work_orders", on: true, in: try #require(viewModel.role(id: "mine")))
            #expect(server.calls("GET /v1/me").count > before)
            #expect(viewModel.role(id: "mine")?.grants["work_orders"] == nil)
            #expect(viewModel.toast?.text == AriaAccessRefusal.escalationDenied.localized)
        }
    }
}
