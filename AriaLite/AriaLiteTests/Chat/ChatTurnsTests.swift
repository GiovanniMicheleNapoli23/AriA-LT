//
//  ChatTurnsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 19/10/26.
//
//  La chat del telefono con i turni in background che vivono sul server: ogni invio ha la sua Idempotency-Key
//  e l'id della risposta lo dice il server, uno stream che cade si segue fino alla risposta salvata, lo Stop
//  passa dal server, un messaggio già accettato non riparte due volte, e le spunte si salvano sulla sessione.
//  Più le rotte condivise di feedback e learning e il layer generico degli endpoint.
//

import Foundation
import Testing
@testable import AriaLite

private func sse(_ events: [(name: String, data: String)], delay: TimeInterval = 0) -> Reply {
    let text = events.map { "event: \($0.name)\ndata: \($0.data)\n\n" }.joined()
    return Reply(status: 200, headers: ["Content-Type": "text/event-stream"], body: Data(text.utf8), delay: delay)
}

private func answer(_ responseId: String, _ text: String, delay: TimeInterval = 0) -> Reply {
    var reply = sse([("response.created", #"{"id":"\#(responseId)"}"#),
                     ("response.output_text.delta", #"{"delta":"\#(text)"}"#),
                     ("response.output_text.done", #"{"text":"\#(text)"}"#),
                     ("response.completed", #"{"status":"completed"}"#)], delay: delay)
    reply.headers["X-Response-ID"] = responseId
    return reply
}

/// La sessione con un turno che sta rispondendo (GET /v1/agent/sessions/{id}: `active_turn`).
private func session(running responseId: String? = nil) -> Reply {
    let active = responseId.map { #"{"response_id":"\#($0)","status":"running"}"# } ?? "null"
    return .json(#"{"session_id":"S1","checklist":{"checks":{}},"active_turn":\#(active)}"#)
}

private func turn(_ responseId: String, _ status: String) -> Reply {
    .json(#"{"response_id":"\#(responseId)","status":"\#(status)","message":null,"interrupt":null}"#)
}

private func conflict(_ code: String, responseId: String? = nil) -> Reply {
    let id = responseId.map { #","response_id":"\#($0)""# } ?? ""
    return .json(#"{"detail":{"code":"\#(code)","message":"m"\#(id)}}"#, status: 409)
}

private let stepList = #"{"type":"aria.task_list","agent":"technical","step_number":1,"step_title":"Open the panel","revision":1,"tasks":[{"id":"task_1","index":1,"text":"Unscrew"},{"id":"task_2","index":2,"text":"Lift"}]}"#

extension BackendTests {
    @Suite("Chat turns")
    struct ChatTurns {
        private let server = StubServer.shared
        private let base = "/v1/agent/sessions/S1"

        init() {
            TestEnv.reset()
            AriaAgentChat.turnPollInterval = .milliseconds(10)
            AriaAgentChat.turnPollPatience = 5
            AriaAgentChat.checklistDebounce = .milliseconds(10)
        }

        /// Chat dell'operatore sulla sessione S1 (vuota, se il test non dice altro); Idempotency-Key r1, r2, …
        private func chat(messages: Reply...) async throws -> AriaAgentChat {
            let backend = try await TestEnv.signedInStore().backend
            let chat = AriaAgentChat(backend: backend, progressStore: AriaTaskProgressStore(inMemory: true))
            var next = 0
            chat.makeRequestID = { next += 1; return "r\(next)" }
            server.route("GET \(base)/messages", messages.isEmpty ? [.json("[]")] : messages)
            await chat.open(sessionId: "S1")
            return chat
        }

        private func finished(_ chat: AriaAgentChat) async -> Bool {
            await TestEnv.waitUntil { !chat.isStreaming }
        }

        private var sends: [Call] { server.calls("POST /v1/responses") }

        // MARK: Idempotency-Key e background

        @Test func everyMessageIsABackgroundTurnWithItsOwnIdempotencyKey() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", answer("resp_r1", "Uno"), answer("resp_r2", "Due"))

            chat.send("a")
            #expect(await finished(chat))
            chat.send("b")
            #expect(await finished(chat))

            #expect(sends.map { $0.header("idempotency-key") } == ["r1", "r2"])
            #expect(sends.allSatisfy { $0.json?["background"] as? Bool == true && $0.json?["stream"] as? Bool == true })
            #expect(sends.allSatisfy { $0.header("x-request-id") == nil && $0.header("accept") == "text/event-stream" })
            #expect(chat.messages.last?.responseId == "resp_r2", "l'id lo dice il server, non si deduce dalla chiave")
            #expect(chat.messages.last?.text == "Due")
        }

        @Test func aDirectToolCallStaysBoundToTheRequest() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", answer("resp_t1", "Fatto"))

            chat.sendQuick(label: "/diag", tool: "diag", args: [:])
            #expect(await finished(chat))

            let send = try #require(sends.first)
            #expect(send.json?["background"] == nil, "un tool_call diretto non può andare in background")
            #expect(send.header("idempotency-key") == nil)
        }

        // MARK: Lo stream cade, la risposta no

        @Test func aDroppedStreamFollowsTheTurnToTheSavedAnswer() async throws {
            let saved = #"[{"id":"u1","role":"user","text":"a"},{"id":"a1","role":"assistant","text":"Risposta salvata","responseId":"resp_r1"}]"#
            let chat = try await chat(messages: .json("[]"), .json(saved))
            server.route("POST /v1/responses", .failing(.networkConnectionLost))
            // Lo stream è caduto prima di dire l'id: il turno lo dice la sessione.
            server.route("GET \(base)", session(running: "resp_r1"))
            server.route("GET \(base)/turns/resp_r1", turn("resp_r1", "running"), turn("resp_r1", "completed"))

            chat.send("a")
            #expect(await finished(chat))

            #expect(sends.count == 1, "la risposta va avanti sul server: non si rimanda")
            #expect(server.calls("GET \(base)/turns/resp_r1").count == 2)
            #expect(chat.messages.map(\.text) == ["a", "Risposta salvata"])
            #expect(chat.messages.last?.error == nil)
        }

        @Test func aStreamThatClosesAfterTheAcceptedIdFollowsThatTurn() async throws {
            let saved = #"[{"id":"u1","role":"user","text":"a"},{"id":"a1","role":"assistant","text":"Completa","responseId":"resp_r1"}]"#
            let chat = try await chat(messages: .json("[]"), .json(saved))
            // Il proxy chiude lo stream a metà: c'è `response.created` ma non `response.completed`.
            var cut = sse([("response.created", #"{"id":"resp_r1"}"#), ("response.output_text.delta", #"{"delta":"Com"}"#)])
            cut.headers["X-Response-ID"] = "resp_r1"
            server.route("POST /v1/responses", cut)
            server.route("GET \(base)/turns/resp_r1", turn("resp_r1", "running"), turn("resp_r1", "completed"))

            chat.send("a")
            #expect(await finished(chat))

            #expect(sends.count == 1)
            #expect(server.calls("GET \(base)").count == 1, "l'id era noto: la sessione si legge solo all'apertura")
            #expect(chat.messages.map(\.text) == ["a", "Completa"])
        }

        @Test func aMessageThatNeverReachedTheServerIsAnOfflineErrorAndIsResentTheSame() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", .failing(.notConnectedToInternet), answer("resp_r1", "Ok"))
            server.route("GET \(base)", .failing(.notConnectedToInternet))

            chat.send("a")
            #expect(await finished(chat))
            let failed = try #require(chat.messages.last)
            #expect(failed.errorIsOffline)

            chat.regenerate(failed.id)
            #expect(await finished(chat))
            #expect(sends.map { $0.header("idempotency-key") } == ["r1", "r1"], "lo stesso messaggio, la stessa chiave")
        }

        @Test func aMessageThatWasNotAcceptedWhileTheServerIsReachableKeepsItsError() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", .failing(.networkConnectionLost))
            server.route("GET \(base)", session())

            chat.send("a")
            #expect(await finished(chat))

            #expect(sends.count == 1, "senza turno attivo non si rimanda da soli")
            #expect(chat.messages.last?.error != nil)
            #expect(server.calls.allSatisfy { !$0.path.contains("/turns/") })
        }

        @Test func aTurnThatEndedFailedSaysSoOnTheAnswer() async throws {
            let saved = #"[{"id":"u1","role":"user","text":"a"},{"id":"a1","role":"assistant","text":"Mez","responseId":"resp_r1"}]"#
            let chat = try await chat(messages: .json("[]"), .json(saved))
            server.route("POST /v1/responses", .failing(.networkConnectionLost))
            server.route("GET \(base)", session(running: "resp_r1"))
            server.route("GET \(base)/turns/resp_r1", turn("resp_r1", "failed"))

            chat.send("a")
            #expect(await finished(chat))
            #expect(chat.messages.last?.text == "Mez")
            #expect(chat.messages.last?.error != nil)
        }

        @Test func aFailedTurnKeepsTheReasonTheServerGave() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", sse([
                ("response.created", #"{"id":"resp_r1"}"#),
                ("response.output_text.delta", #"{"delta":"Testo"}"#),
                ("error", #"{"type":"error","message":"Trace storage unavailable","code":500}"#),
                ("response.completed", #"{"status":"failed"}"#),
            ]))

            chat.send("a")
            #expect(await finished(chat))

            #expect(chat.messages.last?.error == "Trace storage unavailable", "il motivo del server non si copre con un testo generico")
            #expect(chat.messages.last?.text == "Testo")
        }

        // MARK: Stop

        @Test func stopBeforeTheServerSaidTheIDFindsTheTurnOnTheSession() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", answer("resp_r1", "Lenta", delay: 2))
            server.route("GET \(base)", session(running: "resp_r1"))
            server.route("POST \(base)/turns/resp_r1/cancel",
                         .json(#"{"response_id":"resp_r1","status":"running","cancel_requested":true}"#, status: 202))
            server.route("GET \(base)/turns/resp_r1", turn("resp_r1", "running"), turn("resp_r1", "cancelled"))

            chat.send("a")
            #expect(await TestEnv.waitUntil { !sends.isEmpty })
            chat.stop()

            #expect(await finished(chat))
            #expect(await TestEnv.waitUntil { server.calls("GET \(base)/turns/resp_r1").count == 2 })
            #expect(server.calls("POST \(base)/turns/resp_r1/cancel").count == 1)
            #expect(chat.messages.last?.error == nil, "fermare non è un errore")
        }

        @Test func stoppingATurnThatHadAlreadyEndedIsNotAnError() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", answer("resp_r1", "Lenta", delay: 2))
            server.route("GET \(base)", session(running: "resp_r1"))
            server.route("POST \(base)/turns/resp_r1/cancel", conflict("turn_not_running"))
            server.route("GET \(base)/turns/resp_r1", turn("resp_r1", "cancelled"))

            chat.send("a")
            #expect(await TestEnv.waitUntil { !sends.isEmpty })
            chat.stop()

            #expect(await TestEnv.waitUntil { !server.calls("GET \(base)/turns/resp_r1").isEmpty })
            #expect(chat.lastError == nil)
        }

        // MARK: 409

        @Test func anAlreadyAcceptedMessageReattachesInsteadOfRunningTwice() async throws {
            let saved = #"[{"id":"u1","role":"user","text":"a"},{"id":"a1","role":"assistant","text":"Già fatta","responseId":"resp_r1"}]"#
            let chat = try await chat(messages: .json("[]"), .json(saved))
            server.route("POST /v1/responses", conflict("turn_already_started", responseId: "resp_r1"))
            server.route("GET \(base)/turns/resp_r1", turn("resp_r1", "completed"))

            chat.send("a")
            #expect(await finished(chat))
            #expect(sends.count == 1)
            #expect(chat.messages.map(\.text) == ["a", "Già fatta"])
        }

        @Test func anAcceptedMessageWhoseTurnFailedIsResentWithANewID() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", conflict("turn_already_started", responseId: "resp_r1"), answer("resp_r2", "Ok"))
            server.route("GET \(base)/turns/resp_r1", turn("resp_r1", "interrupted"))

            chat.send("a")
            #expect(await finished(chat))
            #expect(sends.map { $0.header("idempotency-key") } == ["r1", "r2"])
            #expect(chat.messages.last?.text == "Ok")
        }

        @Test func aKeyReusedWithAnotherBodyIsResentWithANewOne() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", conflict("idempotency_conflict"), answer("resp_r2", "Ok"))

            chat.send("a")
            #expect(await finished(chat))
            #expect(sends.map { $0.header("idempotency-key") } == ["r1", "r2"])
            #expect(chat.messages.last?.text == "Ok")
        }

        @Test func aTakenResponseIDIsResentWithANewKey() async throws {
            let chat = try await chat()
            server.route("POST /v1/responses", conflict("response_id_taken"), answer("resp_r2", "Ok"))

            chat.send("a")
            #expect(await finished(chat))
            #expect(sends.map { $0.header("idempotency-key") } == ["r1", "r2"])
            #expect(chat.messages.last?.responseId == "resp_r2")
        }

        @Test func aMessageSentWhileAnotherTurnRunsWaitsForItThenGoes() async throws {
            let other = #"[{"id":"u0","role":"user","text":"prima"},{"id":"a0","role":"assistant","text":"Finita","responseId":"resp_x"}]"#
            let chat = try await chat(messages: .json("[]"), .json(other))
            server.route("POST /v1/responses", conflict("turn_in_progress", responseId: "resp_x"), answer("resp_r1", "Ok"))
            server.route("GET \(base)/turns/resp_x", turn("resp_x", "running"), turn("resp_x", "completed"))

            chat.send("a")
            #expect(await finished(chat))
            #expect(sends.map { $0.header("idempotency-key") } == ["r1", "r1"], "il server non l'aveva accettato: stessa chiave")
            #expect(chat.messages.map(\.text) == ["prima", "Finita", "a", "Ok"])
        }

        // MARK: Riaggancio all'apertura

        @Test func anAnswerStillRunningWhenTheChatOpensIsFollowed() async throws {
            server.route("GET \(base)", .json(#"{"session_id":"S1","checklist":{"checks":{}},"active_turn":{"response_id":"resp_x","status":"running"}}"#))
            server.route("GET \(base)/turns/resp_x", turn("resp_x", "running"), turn("resp_x", "completed"))
            let before = #"[{"id":"u1","role":"user","text":"a"}]"#
            let after = #"[{"id":"u1","role":"user","text":"a"},{"id":"a1","role":"assistant","text":"Arrivata","responseId":"resp_x"}]"#
            let chat = try await chat(messages: .json(before), .json(after))

            #expect(chat.isStreaming, "Aria sta ancora rispondendo: si aspetta, non si mostra un buco")
            #expect(await finished(chat))
            #expect(chat.messages.map(\.text) == ["a", "Arrivata"])
        }

        // MARK: Spunte

        @Test func ticksAreSavedOnTheSessionAndComeBack() async throws {
            server.route("GET \(base)", .json(#"{"session_id":"S1","checklist":{"checks":{"resp_a:task_2":true}},"active_turn":null}"#))
            server.route("PUT \(base)/checklist", .json(#"{"checks":{}}"#))
            let rows = #"[{"id":"u1","role":"user","text":"go"},{"id":"a1","role":"assistant","text":"Step 1","responseId":"resp_a","task_list":\#(stepList)}]"#
            let chat = try await chat(messages: .json(rows))

            let step = try #require(chat.sessionTaskLists.first)
            #expect(step.messageId == "db-a1", "la checklist arriva con la riga del server")
            #expect(!chat.isTaskChecked(step.list.tasks[0], in: step.messageId))
            #expect(chat.isTaskChecked(step.list.tasks[1], in: step.messageId), "spuntato su un altro telefono")

            chat.toggleTask(step.list.tasks[0], in: step.messageId)
            #expect(await TestEnv.waitUntil { !server.calls("PUT \(base)/checklist").isEmpty })
            let put = try #require(server.calls("PUT \(base)/checklist").last?.json)
            #expect(put["checks"] as? [String: Bool] == ["resp_a:task_1": true, "resp_a:task_2": true])
        }

        // MARK: Feedback e learning condivise

        @Test func feedbackReviewAndLearningUseTheSharedRoutes() async throws {
            let backend = try await TestEnv.signedInStore().backend
            let api = AriaChatAPI(api: backend.api)
            let chatBase = "/v1/chat/sessions/S1"
            server.route("POST \(chatBase)/feedback/answer", .json(#"{"recorded":true,"learned":false,"vote":"up"}"#))
            server.route("POST \(chatBase)/feedback/step", .json(#"{"recorded":true}"#))
            server.route("POST \(chatBase)/review", .json(#"{"recorded":true}"#))
            server.route("POST \(chatBase)/learning", .json(#"{"recorded":true,"learned":true}"#, status: 201))
            server.route("POST /v1/companies/c1/memory-facts/validation", .json(#"{"learned":0,"proposals":0,"items":[]}"#))

            let vote = try await api.answerFeedback(sessionId: "S1", vote: "up", messageId: "m1", note: nil, answer: "A", question: "Q")
            #expect(vote.vote == "up")
            let list = try JSONDecoder().decode(AriaTaskList.self, from: Data(stepList.utf8))
            await api.stepFeedback(sessionId: "S1", action: "unclear", taskList: list, task: "Unscrew")
            try await api.review(sessionId: "S1", outcome: "resolved", rating: 5, issues: nil)
            await api.learning(sessionId: "S1", answers: [AriaElicitationAnswer(key: "k", value: "v", text: "t", custom: "")])
            _ = try await api.submitValidation(companyId: "c1", plantId: "p1", sessionId: "S1", question: "Q",
                                               answer: "A", feedback: "giusto")

            #expect(server.calls("POST \(chatBase)/feedback/step").count == 1)
            #expect(server.calls("POST \(chatBase)/review").first?.json?["outcome"] as? String == "resolved")
            #expect(server.calls("POST \(chatBase)/learning").count == 1)
            let validation = try #require(server.calls("POST /v1/companies/c1/memory-facts/validation").first)
            #expect(validation.json?["plantId"] as? String == "p1", "senza stabilimento il server risponde 422")
            #expect(validation.header("company-id") == "c1")
            #expect(server.calls.allSatisfy { !$0.path.hasPrefix("/v1/mobile") }, "le rotte /v1/mobile non esistono più")
        }

        @Test func renameAndDeleteAreAvailableToTheOperator() async throws {
            let backend = try await TestEnv.signedInStore().backend
            let api = AriaChatAPI(api: backend.api)
            server.route("PATCH \(base)", .json(#"{"session_id":"S1","title":"Nuovo"}"#))
            server.route("DELETE \(base)", .json(#"{"deleted":true}"#))

            try await api.rename(sessionId: "S1", title: "Nuovo")
            try await api.delete(sessionId: "S1")

            #expect(server.calls("PATCH \(base)").first?.json?["title"] as? String == "Nuovo")
            #expect(server.calls("DELETE \(base)").count == 1)
        }

        // MARK: Endpoint generici

        @Test func anEndpointIsOneLine() async throws {
            let backend = try await TestEnv.signedInStore().backend
            server.route("GET /v1/thing?a=1&b=2", .json(#"{"name":"x"}"#))
            server.route("DELETE /v1/thing/1", .noContent)

            nonisolated struct Thing: Decodable, Sendable { let name: String }
            let thing: Thing = try await backend.api.call(.get("v1/thing", query: ["a": "1", "b": "2"]))
            let _: AriaNoContent = try await backend.api.call(.delete("v1/thing/1"))

            #expect(thing.name == "x")
            let get = try #require(server.calls("GET /v1/thing").first)
            #expect(get.header("company-id") == "c1")
            #expect(get.header("authorization")?.hasPrefix("Bearer ") == true)
            #expect(server.calls("DELETE /v1/thing/1").count == 1)
        }

        @Test func aTurnConflictCarriesItsCodeAndResponseID() async throws {
            let backend = try await TestEnv.signedInStore().backend
            server.route("POST /v1/x", conflict("turn_in_progress", responseId: "resp_9"))

            await #expect(throws: AriaError.self) {
                let _: AriaNoContent = try await backend.api.call(.post("v1/x"))
            }
            do {
                let _: AriaNoContent = try await backend.api.call(.post("v1/x"))
            } catch AriaError.turnConflict(let conflict) {
                #expect(conflict == AriaTurnConflict(code: .turnInProgress, responseId: "resp_9"))
            }
        }
    }
}
