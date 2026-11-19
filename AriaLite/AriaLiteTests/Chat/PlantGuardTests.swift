//
//  PlantGuardTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 12/11/26.
//
//  L'avviso "manca lo stabilimento" sopra il composer: chi ha stabilimenti ne sceglie uno, un admin senza
//  stabilimenti ne crea uno da lì (la chat parte con quello), chi non ha la sezione Plants lo chiede a un admin.
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Plant guard")
    @MainActor
    struct PlantGuard {
        private let server = StubServer.shared

        init() { TestEnv.reset() }

        /// Collegato con questi stabilimenti; `admin` = layout dell'admin (GET /v1/me senza restrizioni).
        private func chat(plants: String = "[]", admin: Bool) async throws -> AriaAgentChatViewModel {
            let backend = AriaBackend()
            TestEnv.stubSignIn(plants: .json(plants))
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            await TestEnv.grant(nil, to: backend, restricted: !admin)
            let chat = AriaAgentChat(backend: backend, progressStore: AriaTaskProgressStore(inMemory: true))
            return AriaAgentChatViewModel(chat: chat, backend: backend)
        }

        @Test func anAdminWithoutPlantsCreatesOneFromTheChat() async throws {
            let model = try await chat(admin: true)
            #expect(model.needsPlant)
            #expect(model.plantGuard == .create, "\"Scegli\" spento e nessuna strada: era un vicolo cieco")
        }

        @Test func aRestrictedMemberWithoutPlantsAsksAnAdmin() async throws {
            let model = try await chat(admin: false)
            #expect(model.needsPlant)
            #expect(model.plantGuard == .askAdmin, "il layout dell'operatore non ha la sezione Plants")
        }

        @Test func withPlantsOneIsChosen() async throws {
            let model = try await chat(plants: #"[{"id":"p1","name":"Plant 1","code":"P1"}]"#, admin: true)
            #expect(model.plantGuard == .choose)
            #expect(!model.needsPlant, "il primo stabilimento si sceglie da solo")
        }

        @Test func aPlantCreatedFromTheChatStartsTheChat() async throws {
            let model = try await chat(admin: true)
            let plant = #"{"id":"p9","name":"Mestre","code":"MES"}"#
            server.route("POST /v1/plants", .json(plant, status: 201))
            server.route("GET /v1/plants", .json("[\(plant)]"))

            model.startCreatingPlant(in: AdminPlantsViewModel(backend: model.backend))
            let form = try #require(model.plantForm)
            #expect(!form.isEditing)
            form.name = "Mestre"
            form.code = "MES"
            #expect(await form.save())

            let call = try #require(server.calls("POST /v1/plants").first)
            #expect(call.json?["name"] as? String == "Mestre")
            #expect(call.json?["code"] as? String == "MES")
            #expect(model.backend.activePlantId == "p9", "lo stabilimento nuovo diventa quello della chat")
            #expect(!model.needsPlant)
        }
    }
}
