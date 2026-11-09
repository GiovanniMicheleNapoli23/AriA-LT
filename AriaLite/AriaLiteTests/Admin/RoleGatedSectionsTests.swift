//
//  RoleGatedSectionsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 05/11/26.
//
//  Ruoli e diritti nelle sezioni admin (Marketplace, Crafted, Asset, Ricambi, Allarmi, Consumi LLM, Agent Studio,
//  widget salvati): cosa mostrano con un ruolo che concede solo alcune sezioni e azioni, e cosa fanno senza ruolo
//  (admin, azienda "legacy", backend senza blocco `access`). Più i messaggi del 403 `permission_denied`.
//

import Foundation
import Testing
@testable import AriaLite

// MARK: - Senza rete

/// Tutto quello che si prova senza Keychain né rete finta: decodifica, mappe di errori e testi.
struct RoleGatedPureTests {
    private func json(_ text: String) throws -> AriaJSON {
        try JSONDecoder().decode(AriaJSON.self, from: Data(text.utf8))
    }

    @Test func llmUsageSessionReadsTheUserIdFromUserId() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let mine = try decoder.decode(AdminLLMUsageSession.self, from: Data(#"{"id":"s1","status":"active","user_id":"u7"}"#.utf8))
        #expect(mine.userId == "u7")
        let old = try decoder.decode(AdminLLMUsageSession.self, from: Data(#"{"id":"s2","status":"active"}"#.utf8))
        #expect(old.userId == nil, "un backend che non manda user_id: la sessione non è di nessuno in particolare")
    }

    @Test func streamEventsBecomeTheMatching403() throws {
        let denied = try json(#"{"type":"permission_denied","detail":{"code":"permission_denied","message":"No","section":"scenario_analysis","action":"approve","reason":"no_action"}}"#)
        guard case .permissionDenied(let denial)? = AdminAgentStudioAPI.accessError(in: denied) else {
            Issue.record("permission_denied dovrebbe diventare .permissionDenied")
            return
        }
        #expect(denial == AriaPermissionDenial(reason: "no_action", section: "scenario_analysis", action: "approve", message: "No"))

        let forbidden = try json(#"{"type":"permission_denied","detail":{"code":"operation_forbidden"}}"#)
        guard case .notOnPhone? = AdminAgentStudioAPI.accessError(in: forbidden) else {
            Issue.record("operation_forbidden dovrebbe diventare .notOnPhone")
            return
        }

        for code in ["not_a_member", "membership_suspended"] {
            let line = try json(#"{"type":"permission_denied","detail":{"code":"\#(code)"}}"#)
            guard case .http(403, let detail)? = AdminAgentStudioAPI.accessError(in: line) else {
                Issue.record("\(code) dovrebbe diventare un 403")
                return
            }
            #expect(detail == code)
        }

        // Senza `code` resta un rifiuto dei diritti, con il corpo vuoto.
        let bare = try json(#"{"type":"permission_denied","detail":{}}"#)
        guard case .permissionDenied(let empty)? = AdminAgentStudioAPI.accessError(in: bare) else {
            Issue.record("un detail senza code dovrebbe restare .permissionDenied")
            return
        }
        #expect(empty == AriaPermissionDenial())

        // Ogni altra riga dello stream passa senza essere letta come un rifiuto.
        #expect(AdminAgentStudioAPI.accessError(in: try json(#"{"type":"step-start","seq":3}"#)) == nil)
        #expect(AdminAgentStudioAPI.accessError(in: try json(#"{"seq":4}"#)) == nil)
    }

    @Test func accessLossIsAnythingThatWouldRepeatTheSameRefusal() {
        let lost: [AriaError] = [.signedOut, .notOnPhone, .permissionDenied(AriaPermissionDenial(reason: "no_role")),
                                 .http(status: 403, detail: "membership_suspended")]
        for error in lost { #expect(AdminAgentStudioFailure.isAccessLoss(error), "\(error)") }
        let transient: [any Error] = [AriaError.http(status: 500, detail: "boom"), AriaError.serverOffline,
                                      URLError(.timedOut), CancellationError()]
        for error in transient { #expect(!AdminAgentStudioFailure.isAccessLoss(error), "\(error)") }
    }

    @Test func permissionDeniedMessageDependsOnTheReason() {
        let paused = String(localized: "Your access is paused. Ask your admin.")
        let notAllowed = String(localized: "Your role doesn't allow this.")
        for reason in ["role_disabled", "no_role"] {
            let error = AriaError.permissionDenied(AriaPermissionDenial(reason: reason))
            #expect(error.localizedDescription == paused, "\(reason)")
        }
        let others: [String?] = ["no_section", "no_action", nil, "something_new"]
        for reason in others {
            let error = AriaError.permissionDenied(AriaPermissionDenial(reason: reason, section: "assets"))
            #expect(error.localizedDescription == notAllowed, "\(reason ?? "nil")")
        }
    }
}

// MARK: - Con il backend

extension BackendTests {
    @Suite("Role-gated admin sections")
    struct RoleGatedSections {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        // MARK: Aiuti

        /// Chi ha fatto l'accesso, secondo GET /v1/me.
        private enum Who {
            /// Un membro con un ruolo che concede queste sezioni (JSON di `sections`).
            case role(String)
            /// Owner o admin: tutto.
            case admin
            /// Un'azienda che non ha i ruoli.
            case legacy
            /// Un backend precedente: niente blocco `access`.
            case noBlock
        }

        private func become(_ who: Who, _ backend: AriaBackend) async {
            switch who {
            case .role(let sections): await TestEnv.grant(TestEnv.accessJSON(sections: sections), to: backend)
            case .admin: await TestEnv.grant(TestEnv.accessJSON(admin: true, role: nil, sections: "{}"), to: backend)
            case .legacy: await TestEnv.grant(TestEnv.accessJSON(model: "legacy", sections: "{}"), to: backend)
            case .noBlock: await TestEnv.grant(nil, to: backend)
            }
        }

        /// Le sezioni di un ruolo con una sola sezione concessa e le sue azioni.
        private func sections(_ slug: String, _ actions: String...) -> String {
            let list = actions.map { "\"\($0)\"" }.joined(separator: ",")
            return #"{"\#(slug)":{"granted":true,"actions":[\#(list)]}}"#
        }

        private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
            try JSONDecoder().decode(T.self, from: Data(json.utf8))
        }

        /// Cambia cosa risponde GET /v1/me senza rileggerlo (lo farà l'app, o il test).
        private func routeMe(_ access: String) {
            server.route("GET /v1/me", .json(#"{"id":"u1","membership":{"role":"member","restricted":true},"access":\#(access)}"#))
        }

        private func connected() async throws -> AriaBackend {
            try await TestEnv.signedInStore().backend
        }

        // MARK: Marketplace

        @Test func marketplaceManagementPrefersTheAdminFlagOfTheAccessBlock() async throws {
            let backend = try await connected()
            #expect(!AdminMarketplaceViewModel.canManage(backend), "membership non ancora letta: niente connettori")

            // Un membro con un ruolo non gestisce i connettori, anche se `restricted` dicesse il contrario.
            await TestEnv.grant(TestEnv.accessJSON(sections: sections("marketplace", "approve")), to: backend, restricted: false)
            #expect(!AdminMarketplaceViewModel.canManage(backend))
            // Owner e admin sì, anche con `restricted` vero.
            await TestEnv.grant(TestEnv.accessJSON(admin: true, role: nil, sections: "{}"), to: backend, restricted: true)
            #expect(AdminMarketplaceViewModel.canManage(backend))
            // Senza il blocco `access` decide `membership.restricted`, come prima dei ruoli.
            await TestEnv.grant(nil, to: backend, restricted: false)
            #expect(AdminMarketplaceViewModel.canManage(backend))
            await TestEnv.grant(nil, to: backend, restricted: true)
            #expect(!AdminMarketplaceViewModel.canManage(backend))
        }

        // MARK: Crafted

        private static let oneReview = #"{"sessions":[{"sessionId":"s1","title":"Pump trip"}]}"#
        private static let reviewsRoute = "GET /v1/companies/c1/session-reviews"

        private func reportCount(_ viewModel: AdminCraftedViewModel) -> Int {
            viewModel.items.filter { if case .report = $0 { true } else { false } }.count
        }

        @Test func craftedReviewsAreNotRequestedWithoutScenarioAnalysis() async throws {
            let backend = try await connected()
            await become(.role(sections("assets")), backend)
            server.route(Self.reviewsRoute, .json(Self.oneReview))
            let viewModel = AdminCraftedViewModel(backend: backend)
            let keyWithout = viewModel.loadKey
            #expect(!viewModel.showsReviews)

            await viewModel.load()
            #expect(server.calls(Self.reviewsRoute).isEmpty, "senza la sezione la chiamata non parte")
            #expect(viewModel.reviews.isEmpty)
            #expect(viewModel.reviewsNote == nil, "né errore né avviso")
            #expect(reportCount(viewModel) == 0)

            // Il diritto arriva: la chiave di caricamento cambia e i rapporti compaiono.
            await become(.role(sections("scenario_analysis")), backend)
            #expect(viewModel.showsReviews)
            #expect(viewModel.loadKey != keyWithout)
            await viewModel.load()
            #expect(server.calls(Self.reviewsRoute).count == 1)
            #expect(viewModel.reviews.count == 1)
            #expect(reportCount(viewModel) == 1)
        }

        @Test func craftedReviewsLoadForAdminLegacyAndBackendsWithoutAccess() async throws {
            for who in [Who.admin, .legacy, .noBlock] {
                TestEnv.reset()
                let backend = try await connected()
                await become(who, backend)
                server.route(Self.reviewsRoute, .json(Self.oneReview))
                let viewModel = AdminCraftedViewModel(backend: backend)
                #expect(viewModel.showsReviews)
                await viewModel.load()
                #expect(server.calls(Self.reviewsRoute).count == 1)
                #expect(viewModel.reviews.count == 1)
                #expect(viewModel.reviewsNote == nil)
            }
        }

        @Test func craftedPermissionDeniedClearsTheReviewsWithoutANote() async throws {
            let backend = try await connected()
            await become(.role(sections("scenario_analysis")), backend)
            server.route(Self.reviewsRoute,
                         .json(Self.oneReview),
                         .json(#"{"detail":{"code":"permission_denied","reason":"no_section","section":"scenario_analysis"}}"#, status: 403),
                         .json(#"{"detail":"Forbidden"}"#, status: 403))
            let viewModel = AdminCraftedViewModel(backend: backend)
            await viewModel.load()
            #expect(viewModel.reviews.count == 1)

            // Il ruolo ha perso la sezione a schermata aperta: l'elenco sparisce in silenzio.
            await viewModel.load()
            #expect(viewModel.reviews.isEmpty)
            #expect(viewModel.reviewsNote == nil)

            // Un 403 qualunque resta il vecchio avviso "non è del tuo ruolo".
            await viewModel.load()
            #expect(viewModel.reviewsNote == .restricted)
        }

        // MARK: Asset

        @Test func aNewAssetStartsAsDraftWithoutTheApproveRight() async throws {
            let backend = try await connected()
            await become(.role(sections("assets")), backend)
            #expect(AdminAssetFormViewModel(backend: backend, editing: nil).status == "draft")
            await become(.role(sections("assets", "approve")), backend)
            #expect(AdminAssetFormViewModel(backend: backend, editing: nil).status == "approved")
            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                #expect(AdminAssetFormViewModel(backend: backend, editing: nil).status == "approved")
            }
        }

        @Test func assetStatusPickerOffersOnlyTheChangesTheRoleAllows() async throws {
            let backend = try await connected()
            let draft = try decode(AdminAsset.self, #"{"id":"a1","tag":"M1","name":"Motor","status":"draft"}"#)
            let approved = try decode(AdminAsset.self, #"{"id":"a2","tag":"M2","name":"Pump","status":"approved"}"#)

            // Una bozza: senza approve né reject restano le scelte che non toccano l'approvazione.
            await become(.role(sections("assets")), backend)
            var form = AdminAssetFormViewModel(backend: backend, editing: draft)
            #expect(form.statusOptions == ["draft", "staged", "superseded"])
            #expect(form.showsStatusPicker)
            await become(.role(sections("assets", "approve")), backend)
            form = AdminAssetFormViewModel(backend: backend, editing: draft)
            #expect(form.statusOptions == ["approved", "draft", "staged", "superseded"])
            await become(.role(sections("assets", "reject")), backend)
            form = AdminAssetFormViewModel(backend: backend, editing: draft)
            #expect(form.statusOptions == ["draft", "staged", "rejected", "superseded"])

            // Un asset approvato: togliere l'approvazione è `unapprove`; senza, lo stato non si cambia e il selettore sparisce.
            await become(.role(sections("assets")), backend)
            form = AdminAssetFormViewModel(backend: backend, editing: approved)
            #expect(form.statusOptions == ["approved"])
            #expect(!form.showsStatusPicker)
            await become(.role(sections("assets", "unapprove")), backend)
            form = AdminAssetFormViewModel(backend: backend, editing: approved)
            #expect(form.statusOptions == ["approved", "draft", "staged", "superseded"])

            // Senza ruolo (admin, legacy, backend precedente) tutte le scelte.
            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                form = AdminAssetFormViewModel(backend: backend, editing: approved)
                #expect(form.statusOptions == ["approved", "draft", "staged", "rejected", "superseded"])
            }
        }

        // MARK: Ricambi

        @Test func sparePartStatusChoicesFollowApproveRejectAndUnapprove() async throws {
            let backend = try await connected()
            let owner = AdminSparePartsViewModel(backend: backend)
            let approved = try decode(AdminSparePart.self, #"{"id":"p1","code":"B-1","name":"Bearing","status":"approved"}"#)

            // Un ricambio nuovo parte bozza: senza approve non si può approvare.
            await become(.role(sections("spare_parts")), backend)
            var form = AdminSparePartFormViewModel(mode: .create, owner: owner)
            #expect(form.statusChoices == [.staged, .draft, .superseded])
            await become(.role(sections("spare_parts", "approve", "reject")), backend)
            form = AdminSparePartFormViewModel(mode: .create, owner: owner)
            #expect(form.statusChoices == [.staged, .draft, .approved, .rejected, .superseded])

            // Uno approvato: senza unapprove resta solo lo stato attuale e il selettore non c'è.
            await become(.role(sections("spare_parts")), backend)
            form = AdminSparePartFormViewModel(mode: .edit(approved), owner: owner)
            #expect(form.statusChoices == [.approved])
            #expect(!form.showsStatusPicker)
            await become(.role(sections("spare_parts", "unapprove")), backend)
            form = AdminSparePartFormViewModel(mode: .edit(approved), owner: owner)
            #expect(form.statusChoices == [.staged, .draft, .approved, .superseded])

            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                form = AdminSparePartFormViewModel(mode: .edit(approved), owner: owner)
                #expect(form.statusChoices == AdminSparePartStatus.selectable)
            }
        }

        @Test func sparePartVendorPickerNeedsTheVendorsSection() async throws {
            let backend = try await connected()
            server.route("GET /v1/vendors", .json(#"[{"id":"v1","name":"Acme"}]"#))
            let owner = AdminSparePartsViewModel(backend: backend)
            let form = AdminSparePartFormViewModel(mode: .create, owner: owner)

            await become(.role(sections("spare_parts")), backend)
            #expect(!form.showsVendorPicker)
            await owner.vendors.loadIfNeeded()
            await owner.vendors.load()
            #expect(server.calls("GET /v1/vendors").isEmpty, "senza la sezione fornitori non si chiama")
            #expect(owner.vendors.vendors.isEmpty)

            await become(.role(#"{"spare_parts":{"granted":true,"actions":[]},"vendors":{"granted":true,"actions":[]}}"#), backend)
            #expect(form.showsVendorPicker)
            await owner.vendors.loadIfNeeded()
            #expect(server.calls("GET /v1/vendors").count == 1)
            #expect(owner.vendors.vendors.map(\.id) == ["v1"])

            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                #expect(form.showsVendorPicker)
            }
        }

        // MARK: Allarmi

        private func alarm(status: String, id: String = "a1") throws -> AdminAlarm {
            try decode(AdminAlarm.self, #"{"id":"\#(id)","code":"E-\#(id)","description":"Overload","status":"\#(status)"}"#)
        }

        @Test func alarmStatusOptionsFollowApproveRejectAndUnapprove() async throws {
            let backend = try await connected()
            func keys(_ alarm: AdminAlarm) -> [String] {
                AdminAlarmFormViewModel(alarm: alarm, backend: backend, onSaved: { _ in }).statusOptions.map(\.key)
            }
            let draft = try alarm(status: "draft")
            let approved = try alarm(status: "approved", id: "a2")

            await become(.role(sections("alarms")), backend)
            #expect(keys(draft) == ["draft", "staged", "superseded"])
            await become(.role(sections("alarms", "approve")), backend)
            #expect(keys(draft) == ["approved", "draft", "staged", "superseded"])
            await become(.role(sections("alarms", "reject")), backend)
            #expect(keys(draft) == ["draft", "staged", "rejected", "superseded"])

            await become(.role(sections("alarms")), backend)
            #expect(keys(approved) == ["approved"])
            let form = AdminAlarmFormViewModel(alarm: approved, backend: backend, onSaved: { _ in })
            #expect(!form.showsStatusPicker, "una sola scelta: il selettore non serve")
            await become(.role(sections("alarms", "unapprove")), backend)
            #expect(keys(approved) == ["approved", "draft", "staged", "superseded"])

            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                #expect(keys(approved) == ["approved", "draft", "staged", "rejected", "superseded"])
            }
        }

        @Test func alarmDetailCanApproveOnlyAPendingAlarmWithTheApproveRight() async throws {
            let backend = try await connected()
            let owner = AdminAlarmsViewModel(backend: backend)
            let draft = try alarm(status: "draft")
            let approved = try alarm(status: "approved", id: "a2")

            await become(.role(sections("alarms")), backend)
            #expect(!AdminAlarmDetailViewModel(alarm: draft, owner: owner).canApprove)
            await become(.role(sections("alarms", "approve")), backend)
            #expect(AdminAlarmDetailViewModel(alarm: draft, owner: owner).canApprove)
            #expect(!AdminAlarmDetailViewModel(alarm: approved, owner: owner).canApprove, "già approvato")

            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                #expect(AdminAlarmDetailViewModel(alarm: draft, owner: owner).canApprove)
            }
        }

        @Test func alarmListSelectsDraftsOnlyWithTheApproveRight() async throws {
            let backend = try await connected()
            server.route("GET /v1/alarms", .json(#"[{"id":"a1","code":"E-1","status":"draft"}]"#))
            let owner = AdminAlarmsViewModel(backend: backend)
            owner.selectStatus(.draft)
            await owner.refresh()
            #expect(owner.alarms.count == 1)

            await become(.role(sections("alarms")), backend)
            #expect(!owner.canSelect)
            await become(.role(sections("alarms", "approve")), backend)
            #expect(owner.canSelect)
            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                #expect(owner.canSelect)
            }
        }

        @Test func diagnosisCreatesWorkOrdersOnlyWithTheWorkOrdersSection() async throws {
            let backend = try await connected()
            let diagnosis = AdminAlarmDiagnosisViewModel(alarm: try alarm(status: "approved"), backend: backend)

            await become(.role(sections("alarms", "approve")), backend)
            #expect(!diagnosis.canCreateWorkOrder, "gli allarmi non bastano: l'ordine è della sezione ordini")
            await become(.role(sections("work_orders")), backend)
            #expect(diagnosis.canCreateWorkOrder)
            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                #expect(diagnosis.canCreateWorkOrder)
            }
        }

        // MARK: Consumi LLM

        private func llmSession(id: String = "s1", status: String = "active", user: String?) throws -> AdminLLMUsageSession {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let owner = user.map { #","user_id":"\#($0)""# } ?? ""
            return try decoder.decode(AdminLLMUsageSession.self,
                                      from: Data(#"{"id":"\#(id)","status":"\#(status)"\#(owner)}"#.utf8))
        }

        @Test func llmUsageStopIsOfferedOnOwnSessionsAndToRolesWithStopSession() async throws {
            let backend = try await connected()
            let me = try #require(backend.mobileAccount?.id)
            let viewModel = AdminLLMUsageViewModel(backend: backend)
            let own = try llmSession(id: "own", user: me)
            let colleague = try llmSession(id: "other", user: "someone-else")
            let unknownOwner = try llmSession(id: "anon", user: nil)
            let finished = try llmSession(id: "done", status: "completed", user: "someone-else")

            // Un ruolo con la sezione ma senza `stop_session`: ferma solo le proprie.
            await become(.role(sections("llm_usage")), backend)
            #expect(viewModel.showsStop(own))
            #expect(viewModel.canStop(own))
            #expect(!viewModel.showsStop(colleague))
            #expect(!viewModel.showsStop(unknownOwner))
            viewModel.requestStop(colleague)
            #expect(viewModel.sessionToStop == nil, "senza il diritto la conferma non si apre")
            viewModel.requestStop(own)
            #expect(viewModel.sessionToStop == own)

            // Con `stop_session` anche quelle dei colleghi; una già finita non si ferma comunque.
            await become(.role(sections("llm_usage", "stop_session")), backend)
            #expect(viewModel.showsStop(colleague))
            #expect(viewModel.showsStop(unknownOwner))
            #expect(!viewModel.showsStop(finished))

            for who in [Who.admin, .legacy, .noBlock] {
                await become(who, backend)
                #expect(viewModel.showsStop(colleague))
                #expect(!viewModel.showsStop(finished))
            }
        }

        // MARK: Agent Studio

        private func runBody() -> AdminAgentStudioRunBody {
            AdminAgentStudioRunBody(workflowId: "w1", workflowName: "Flow", mode: "run", graph: .object([:]), plantId: nil)
        }

        private func runViewModel(_ backend: AriaBackend, _ source: AdminAgentStudioRunViewModel.Source,
                                  workflowId: String? = nil) -> AdminAgentStudioRunViewModel {
            AdminAgentStudioRunViewModel(backend: backend, source: source, workflowId: workflowId, onActivityChanged: {})
        }

        @Test func aPermissionDeniedLineEndsTheRunAndRereadsTheRights() async throws {
            let backend = try await connected()
            await become(.role(sections("assets")), backend)
            #expect(!backend.rights.isPaused)
            // L'admin toglie il ruolo mentre il run è aperto: l'ultima riga dello stream lo dice.
            routeMe(TestEnv.accessJSON(role: nil))
            server.route("POST /v1/agent-studio/workflow-runs", .json("""
            {"type":"ping","seq":1}
            {"type":"permission_denied","detail":{"code":"permission_denied","reason":"no_role","message":"No role"}}

            """))
            let before = server.calls("GET /v1/me").count

            let viewModel = runViewModel(backend, .start(runBody(), mode: .run))
            await viewModel.run()

            #expect(!viewModel.isActive)
            #expect(viewModel.live.errorMessage == AdminAgentStudioFailure.roleMessage)
            #expect(await TestEnv.waitUntil { backend.rights.isPaused }, "l'evento fa rileggere GET /v1/me")
            #expect(server.calls("GET /v1/me").count > before)
        }

        @Test func aNotAMemberLineEndsTheOperatorSession() async throws {
            let backend = try await connected()
            #expect(backend.isSignedIn)
            server.route("POST /v1/agent-studio/workflow-runs", .json("""
            {"type":"permission_denied","detail":{"code":"not_a_member"}}

            """))

            let viewModel = runViewModel(backend, .start(runBody(), mode: .run))
            await viewModel.run()

            #expect(!viewModel.isActive)
            #expect(!backend.isSignedIn, "come il 403 not_a_member del client: la sessione dell'operatore finisce")
        }

        @Test func anAccessLossInTheEventsStreamDoesNotReconnect() async throws {
            let backend = try await connected()
            await become(.role(sections("assets")), backend)
            let events = "GET /v1/agent-studio/workflow-runs/r1/events"
            server.route(events, .json("""
            {"type":"permission_denied","detail":{"code":"operation_forbidden"}}

            """))

            let viewModel = runViewModel(backend, .attach(runId: "r1"))
            await viewModel.run()

            #expect(server.calls(events).count == 1, "riconnettersi ripeterebbe lo stesso rifiuto")
            #expect(!viewModel.isActive)
            #expect(viewModel.live.errorMessage == AdminAgentStudioFailure.roleMessage)
        }

        // MARK: Widget salvati

        @Test func savedWidgetOffersRetryOnPermissionDeniedAndAccessUnavailableOnly() async throws {
            let backend = try await connected()
            await become(.role(sections("scenario_analysis")), backend)
            let widget = try decode(AdminCraftedWidget.self, #"{"id":"w1","title":"Trend","kind":"chart","tool_name":"trend"}"#)
            server.route("POST /v1/saved-widgets/w1/render",
                         .json(#"{"detail":{"code":"permission_denied","reason":"no_section","section":"scenario_analysis"}}"#, status: 403),
                         .json(#"{"detail":{"code":"access_unavailable"}}"#, status: 503),
                         .json(#"{"detail":"Not found"}"#, status: 404),
                         .json("{}"))
            let viewModel = AdminCraftedWidgetDetailViewModel(backend: backend, widget: widget)
            #expect(!viewModel.canRetry)

            await viewModel.load()
            #expect(viewModel.canRetry)
            #expect(viewModel.errorMessage == AdminCraftedFailure.roleMessage)

            await viewModel.load()
            #expect(viewModel.canRetry, "503 access_unavailable: i diritti non si potevano controllare, si riprova")
            #expect(viewModel.errorMessage != nil)

            await viewModel.load()
            #expect(!viewModel.canRetry, "un 404 non migliora riprovando")
            #expect(viewModel.errorMessage != nil)

            // Un render riuscito toglie errore e "Riprova".
            await viewModel.load()
            #expect(viewModel.errorMessage == nil)
            #expect(!viewModel.canRetry)
        }

        // MARK: Messaggi d'errore

        @Test func failureMappersShowTheRoleMessageForPermissionDenied() async throws {
            let backend = try await connected()
            let denials = [AriaPermissionDenial(reason: "no_section", section: "assets"),
                           AriaPermissionDenial(reason: "role_disabled")]
            for denial in denials {
                let error = AriaError.permissionDenied(denial)
                let generic = error.localizedDescription

                // Asset, Crafted, Agent Studio e Marketplace: il testo del ruolo, non quello generico dell'errore.
                #expect(AdminAssetsFailure.message(for: error, backend: backend) == AdminAssetsFailure.roleMessage)
                #expect(AdminCraftedFailure.message(for: error, backend: backend) == AdminCraftedFailure.roleMessage)
                #expect(AdminAgentStudioFailure.message(for: error, backend: backend) == AdminAgentStudioFailure.roleMessage)
                #expect(AdminMarketplaceFailure.message(for: error, backend: backend) == AdminMarketplaceFailure.roleMessage)
                #expect(AdminAssetsFailure.roleMessage != generic)

                // Allarmi e ricambi: un rifiuto dei diritti, con il testo della loro sezione.
                let alarms = try #require(AdminAlarmsFailure.from(error, action: .write, backend: backend))
                #expect(alarms.isForbidden)
                #expect(alarms.message != generic)
                let parts = try #require(AdminSparePartsFailure.from(error, action: .read, backend: backend))
                #expect(parts.isForbidden)
                #expect(parts.message != generic)

                #expect(AdminLLMUsageFailure.message(for: error, backend: backend) != generic)
            }
            // Un errore qualunque resta il suo testo (e non un rifiuto dei diritti).
            let other = AriaError.http(status: 500, detail: "boom")
            #expect(AdminAssetsFailure.message(for: other, backend: backend) == other.localizedDescription)
            let notForbidden = try #require(AdminAlarmsFailure.from(other, action: .read, backend: backend))
            #expect(!notForbidden.isForbidden)
        }
    }
}
