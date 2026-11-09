//
//  RoleGatedChatTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 05/11/26.
//
//  La chat con ruoli e diritti: senza `work_orders` la chiusura della sessione non offre "report e ordine di
//  lavoro" (né i passi che servono solo all'ordine), e un rifiuto del ruolo dentro lo stream fa rileggere i diritti.
//

import Foundation
import Testing
@testable import AriaLite

private func sse(_ events: [(name: String, data: String)]) -> Reply {
    let text = events.map { "event: \($0.name)\ndata: \($0.data)\n\n" }.joined()
    var reply = Reply(status: 200, headers: ["Content-Type": "text/event-stream"], body: Data(text.utf8))
    reply.headers["X-Response-ID"] = "resp_r1"
    return reply
}

/// La domanda di fine sessione come la manda il server: scelta, assegnatario, priorità e scadenza, una nota.
private let closeoutJSON = #"""
{"id":"q1","question":"","steps":[
 {"id":"s1","question":"How do you want to close?","key":"closeout","options":[
  {"id":"a","label":"Report only","value":"report"},
  {"id":"b","label":"Report and work order","value":"report_wo"},
  {"id":"c","label":"Nothing","value":"nothing"}]},
 {"id":"s2","question":"Who?","key":"assignee","options":[{"id":"me","label":"Me"},{"id":"team","label":"Team"}]},
 {"id":"s3","question":"When?","key":"priority_due","options":[{"id":"h","label":"High"},{"id":"l","label":"Low"}]},
 {"id":"s4","question":"Anything else?","key":"notes","options":[{"id":"y","label":"Yes"},{"id":"n","label":"No"}]}]}
"""#

private func elicitation(_ json: String) throws -> AriaElicitation {
    try JSONDecoder().decode(AriaElicitation.self, from: Data(json.utf8))
}

private func event(_ name: String, _ data: String) -> AriaStreamEvent {
    AriaStreamEvent(AriaSSEEvent(event: name, data: data))
}

// MARK: - Valori

struct RoleGatedChatValues {
    @Test func closingWithoutWorkOrdersDropsTheOrderOptionAndItsSteps() throws {
        let question = try elicitation(closeoutJSON).withoutWorkOrderCloseout()
        let steps = try #require(question.steps)

        #expect(steps.map(\.key) == ["closeout", "notes"], "assegnatario e priorità servono solo all'ordine")
        #expect(steps[0].options.map(\.value) == ["report", "nothing"])
        #expect(question.id == "q1")
    }

    @Test func anOptionWithoutValueIsRecognisedByItsId() throws {
        let json = #"{"id":"q","steps":[{"id":"s","question":"Close?","key":"closeout","options":[{"id":"report","label":"R"},{"id":"report_wo","label":"RW"}]}]}"#
        let steps = try #require(try elicitation(json).withoutWorkOrderCloseout().steps)
        #expect(steps[0].options.map(\.id) == ["report"])
    }

    @Test func otherQuestionsPassUnchanged() throws {
        let plain = try elicitation(#"{"id":"m","question":"Which pump?","options":[{"id":"a","label":"A"},{"id":"b","label":"B"}]}"#)
        #expect(plain.withoutWorkOrderCloseout() == plain)

        let chain = try elicitation(#"{"id":"c","steps":[{"id":"s","question":"Q","key":"assignee","options":[{"id":"a","label":"A"},{"id":"b","label":"B"}]}]}"#)
        #expect(chain.withoutWorkOrderCloseout() == chain, "senza il passo closeout non è la chiusura")
    }

    @Test func aModelErrorStartingWithPermissionDeniedIsARoleRefusal() {
        #expect(event("error", #"{"type":"error","message":"permission_denied: assets"}"#).isRoleRefusal)
        #expect(!event("error", #"{"type":"error","message":"Trace storage unavailable"}"#).isRoleRefusal)
    }

    @Test func aToolClosedByTheRoleIsARoleRefusal() {
        #expect(event("aria.tool_call", #"{"id":"t1","name":"create_asset","status":"error","error":"permission_denied: assets"}"#).isRoleRefusal)
        #expect(event("aria.tool_call", #"{"id":"t1","name":"create_asset","status":"rejected","result_preview":"permission_denied"}"#).isRoleRefusal)
        #expect(!event("aria.tool_call", #"{"id":"t1","name":"create_asset","status":"ok","result_preview":"permission_denied is a code"}"#).isRoleRefusal,
                "uno strumento riuscito non è un rifiuto")
        #expect(!event("aria.tool_call", #"{"id":"t1","name":"create_asset","status":"error","error":"timeout"}"#).isRoleRefusal)
        #expect(!event("response.output_text.delta", #"{"delta":"permission_denied"}"#).isRoleRefusal)
    }
}

// MARK: - Chat

extension BackendTests {
    @Suite("Role-gated chat")
    struct RoleGatedChat {
        private let server = StubServer.shared

        init() {
            TestEnv.reset()
            AriaAgentChat.translationDebounce = .milliseconds(10)
        }

        private static let withoutWorkOrders = TestEnv.accessJSON(sections: #"{"work_orders":{"granted":false}}"#)

        /// Chat aperta sulla sessione S1, con i diritti di `access` (`nil` = nessun blocco).
        private func chat(access: String?) async throws -> AriaAgentChat {
            let (backend, _) = try await TestEnv.signedInStore()
            await TestEnv.grant(access, to: backend)
            let chat = AriaAgentChat(backend: backend, progressStore: AriaTaskProgressStore(inMemory: true))
            chat.makeRequestID = { "r1" }
            server.route("GET /v1/agent/sessions/S1/messages", .json("[]"))
            await chat.open(sessionId: "S1")
            return chat
        }

        private func askCloseout(_ chat: AriaAgentChat) async throws -> AriaElicitation {
            server.route("POST /v1/responses", sse([
                ("response.output_text.delta", #"{"delta":"Done."}"#),
                ("aria.elicitation", closeoutJSON.replacingOccurrences(of: "\n", with: "")),
                ("response.completed", #"{"status":"completed"}"#),
            ]))
            chat.send("I'm done")
            #expect(await TestEnv.waitUntil { chat.activeElicitation != nil })
            return try #require(chat.activeElicitation?.elicitation)
        }

        // MARK: Chiusura

        @Test func withoutWorkOrdersTheClosingQuestionHasNoOrderOption() async throws {
            let chat = try await chat(access: Self.withoutWorkOrders)
            #expect(!chat.canFileWorkOrder)

            let question = try await askCloseout(chat)

            #expect(question.steps?.first?.options.map(\.value) == ["report", "nothing"])
            #expect(question.steps?.map(\.key) == ["closeout", "notes"])
            #expect(chat.messages.last?.elicitation?.steps?.count == 4, "il messaggio resta com'è arrivato")
        }

        @Test func withWorkOrdersTheClosingQuestionIsUnchanged() async throws {
            let chat = try await chat(access: nil)
            #expect(chat.canFileWorkOrder)

            let question = try await askCloseout(chat)

            #expect(question.steps?.first?.options.map(\.value) == ["report", "report_wo", "nothing"])
            #expect(question.steps?.count == 4)
        }

        @Test func aWorkOrderChoiceBecomesReportOnlyWithoutWorkOrders() async throws {
            let chat = try await chat(access: Self.withoutWorkOrders)

            let model = AriaCloseoutViewModel(chat: chat, choice: AriaCloseoutChoice(workOrder: true, report: false))

            #expect(!model.choice.workOrder)
            #expect(model.choice.report)
            #expect(model.isReportOnly)
        }

        @Test func aWorkOrderChoiceStaysWithWorkOrders() async throws {
            let chat = try await chat(access: TestEnv.accessJSON())

            let model = AriaCloseoutViewModel(chat: chat, choice: AriaCloseoutChoice(workOrder: true, report: false))

            #expect(model.choice.workOrder)
            #expect(!model.choice.report)
        }

        @Test func aSessionThatFollowsTheRoleClosesOutLikeTheWeb() async throws {
            let chat = try await chat(access: TestEnv.accessJSON(followsRole: true))
            #expect(!chat.hasOperatorLimits)
            let path = "POST /v1/companies/c1/sessions/S1/closeout"
            server.route(path, .json(#"{"confirmed":true,"workOrderId":"wo1","workOrderTitle":"Fix","workOrderStatus":"open"}"#))
            var request = AriaCloseoutRequest(workOrder: true, report: true)
            request.confirm = true
            request.conflictChoice = "shift"
            request.assigneeId = "colleague"

            _ = try await chat.closeout(request)

            let body = try #require(server.calls(path).first?.json)
            #expect(body["conflictChoice"] as? String == "shift")
            #expect(body["assigneeId"] as? String == "colleague", "sceglie l'assegnatario come sulla web")
        }

        @Test func aSessionThatDoesNotFollowTheRoleKeepsTheOperatorLimits() async throws {
            let chat = try await chat(access: TestEnv.accessJSON(followsRole: false))
            #expect(chat.hasOperatorLimits)
            let model = AriaCloseoutViewModel(chat: chat, choice: AriaCloseoutChoice(workOrder: true, report: true))
            #expect(model.isOperator && model.canAssignToMe)
        }

        // MARK: Rifiuti nello stream

        @Test func aRoleRefusalInTheStreamRereadsTheRights() async throws {
            let chat = try await chat(access: TestEnv.accessJSON())
            let before = server.calls("GET /v1/me").count
            server.route("POST /v1/responses", sse([
                ("aria.tool_call", #"{"id":"t1","name":"create_asset","status":"error","error":"permission_denied: assets"}"#),
                ("response.completed", #"{"status":"completed"}"#),
            ]))

            chat.send("Create pump P-3")

            #expect(await TestEnv.waitUntil { server.calls("GET /v1/me").count == before + 1 })
        }

        @Test func anOrdinaryStreamDoesNotRereadTheRights() async throws {
            let chat = try await chat(access: TestEnv.accessJSON())
            let before = server.calls("GET /v1/me").count
            server.route("POST /v1/responses", sse([
                ("response.output_text.delta", #"{"delta":"Ok"}"#),
                ("response.completed", #"{"status":"completed"}"#),
            ]))

            chat.send("Hi")
            #expect(await TestEnv.waitUntil { !chat.isStreaming && chat.messages.last?.text == "Ok" })
            try await Task.sleep(for: .milliseconds(100))

            #expect(server.calls("GET /v1/me").count == before)
        }
    }
}
