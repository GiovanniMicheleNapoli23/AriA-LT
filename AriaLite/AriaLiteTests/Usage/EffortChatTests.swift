//
//  EffortChatTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il livello di effort nella chat: cosa porta il corpo di ogni invio, quando si salva e si ripristina sulla
//  sessione, il costo di una risposta (evento e storico), il 402 al limite di spesa e il negozio dei crediti
//  (cambio azienda, 503, rotta mancante). Con la rete finta, come gli altri test della chat.
//

import Foundation
import Testing
@testable import AriaLite

private func sse(_ events: [(name: String, data: String)]) -> Reply {
    let text = events.map { "event: \($0.name)\ndata: \($0.data)\n\n" }.joined()
    return Reply(status: 200, headers: ["Content-Type": "text/event-stream"], body: Data(text.utf8))
}

private let chargedEvent = #"{"type":"aria.turn_usage","action_id":"a1","action_type":"chat.reply","status":"charged","action_status":"completed","credits":"2.4","overage":false,"continuation":false,"effort":{"requested":"high","effective":"high","degraded":false,"multiplier":"2.4","reason":null},"degraded_model":false}"#

private let continuationEvent = #"{"type":"aria.turn_usage","action_id":"a2","action_type":"chat.reply","status":"not_charged","action_status":"completed","credits":"0","overage":false,"continuation":true,"effort":{"requested":"high","effective":"base","degraded":true,"multiplier":"1.0","reason":"tier"},"degraded_model":false}"#

private func answer(_ responseId: String, _ text: String, usage: String? = nil) -> Reply {
    var events: [(name: String, data: String)] = [("response.created", #"{"id":"\#(responseId)"}"#),
                                                  ("response.output_text.delta", #"{"delta":"\#(text)"}"#),
                                                  ("response.output_text.done", #"{"text":"\#(text)"}"#)]
    if let usage { events.append(("aria.turn_usage", usage)) }
    events.append(("response.completed", #"{"status":"completed"}"#))
    var reply = sse(events)
    reply.headers["X-Response-ID"] = responseId
    return reply
}

/// La config di un membro: `chat.reply` abilitato (o no), livello di partenza `base`.
private func effortConfig(default level: String = "base", actions: String = #""chat.reply""#) -> String {
    """
    {"effort":{"default_level":"\(level)","enabled_actions":[\(actions)],
      "levels":{"base":{"multiplier":"1.0","available":true},"medium":{"multiplier":"1.7","available":true},
                "high":{"multiplier":"2.4","available":true}}},
     "charge_rounding_increment":"0.1","ui":{"credit_note_mode":"always"}}
    """
}

private func session(effort: String? = nil, delay: TimeInterval = 0) -> Reply {
    let saved = effort.map { #","effort":"\#($0)""# } ?? ""
    return .json(#"{"session_id":"S1","checklist":{"checks":{}},"active_turn":null\#(saved)}"#, delay: delay)
}

extension BackendTests {
    @Suite("Effort in the chat")
    struct EffortChat {
        private let server = StubServer.shared
        private let base = "/v1/agent/sessions/S1"

        init() {
            TestEnv.reset()
            AriaAgentChat.turnPollInterval = .milliseconds(10)
            AriaAgentChat.turnPollPatience = 5
            AriaAgentChat.usageBackfillDelay = .milliseconds(10)
        }

        private var sends: [Call] { server.calls("POST /v1/responses") }

        /// Un backend collegato con i crediti stubbati PRIMA dell'accesso: la lettura parte da sola al bootstrap.
        private func backend(config: Reply = .json(effortConfig()), allowance: Reply = .json(#"{"enabled":false}"#),
                             settled phase: AriaUsageStore.Phase = .loaded) async throws -> AriaBackend {
            server.route("GET /v1/usage/config", config)
            server.route("GET /v1/usage/allowance", allowance)
            let backend = try await TestEnv.signedInStore().backend
            #expect(await TestEnv.waitUntil { backend.usage.configPhase == phase })
            return backend
        }

        /// Una chat mai aperta: il server non ha la sua sessione.
        private func freshChat(_ backend: AriaBackend) -> AriaAgentChat {
            AriaAgentChat(backend: backend, progressStore: AriaTaskProgressStore(inMemory: true))
        }

        /// La sessione S1 riaperta dallo storico (con il suo livello salvato, se c'è).
        private func openedChat(_ backend: AriaBackend, session reply: Reply = session(),
                                messages: String = "[]", pause: String = "null") async -> AriaAgentChat {
            let chat = freshChat(backend)
            server.route("GET \(base)/messages", .json(messages))
            server.route("GET \(base)/pending-interrupt", .json(#"{"interrupt":\#(pause)}"#))
            server.route("GET \(base)", reply)
            await chat.open(sessionId: "S1")
            return chat
        }

        private func finished(_ chat: AriaAgentChat) async -> Bool {
            await TestEnv.waitUntil { !chat.isStreaming }
        }

        // MARK: Cosa porta l'invio

        @Test func normalSendsCarryTheDefaultLevel() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend)
            server.route("POST /v1/responses", answer("resp_1", "Uno"), answer("resp_2", "Due"), answer("resp_3", "Tre"))

            chat.send("a")
            #expect(await finished(chat))
            chat.send("Reset the drive fault on line 2") // il tocco su un suggerimento è un invio normale
            #expect(await finished(chat))
            chat.regenerate(try #require(chat.messages.last?.id))
            #expect(await finished(chat))

            #expect(sends.map { $0.json?["effort"] as? String } == ["base", "base", "base"])
        }

        @Test func aDirectToolCallCarriesNoLevel() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend)
            server.route("POST /v1/responses", answer("resp_1", "Fatto"))

            chat.sendQuick(label: "/diag", tool: "diag", args: [:])
            #expect(await finished(chat))

            #expect(try #require(sends.first).json?["effort"] == nil)
        }

        @Test func resumingAPauseCarriesNoLevel() async throws {
            let backend = try await backend()
            let rows = #"[{"id":"u1","role":"user","text":"x"},{"id":"a1","role":"assistant","text":"y","responseId":"resp_0"}]"#
            let pause = #"{"interrupt_id":"i1","kind":"tool_approval","name":"close_work_order","id":"c1","args":{}}"#
            let chat = await openedChat(backend, messages: rows, pause: pause)
            server.route("POST /v1/responses", answer("resp_1", "Ripreso"))

            chat.resume(.approve)
            #expect(await finished(chat))

            let send = try #require(sends.first)
            #expect(send.json?["resume"] != nil)
            #expect(send.json?["effort"] == nil)
        }

        @Test func noLevelWhenTheConfigCouldNotBeRead() async throws {
            let backend = try await backend(config: .hostDown(), settled: .failed)
            let chat = await openedChat(backend)
            server.route("POST /v1/responses", answer("resp_1", "Uno"))

            chat.send("a")
            #expect(await finished(chat))

            #expect(try #require(sends.first).json?["effort"] == nil)
        }

        @Test func noLevelWhenChatReplyIsNotEnabled() async throws {
            let backend = try await backend(config: .json(effortConfig(actions: #""rag.diagnostic""#)))
            let chat = await openedChat(backend)
            server.route("POST /v1/responses", answer("resp_1", "Uno"))

            chat.send("a")
            #expect(await finished(chat))

            #expect(try #require(sends.first).json?["effort"] == nil)
        }

        // MARK: Scelta e salvataggio

        @Test func aPickAfterATurnIsSavedOnTheSessionAndTravelsWithTheNextMessage() async throws {
            let backend = try await backend()
            let chat = freshChat(backend)
            server.route("POST /v1/responses", answer("resp_1", "Uno"), answer("resp_2", "Due"))
            server.route("PATCH /v1/agent/sessions/\(chat.sessionId)", .json("{}"))

            chat.send("a")
            #expect(await finished(chat))
            chat.chooseEffort(.high)
            let patches = "PATCH /v1/agent/sessions/\(chat.sessionId)"
            #expect(await TestEnv.waitUntil { server.calls(patches).count == 1 })
            chat.send("b")
            #expect(await finished(chat))

            #expect(try #require(server.calls(patches).first).json?["effort"] as? String == "high")
            #expect(sends.map { $0.json?["effort"] as? String } == ["base", "high"])
        }

        @Test func aPickOnAFreshChatSavesNothingAndTheFirstTurnCarriesIt() async throws {
            let backend = try await backend()
            let chat = freshChat(backend)
            let patches = "PATCH /v1/agent/sessions/\(chat.sessionId)"
            server.route(patches, .json("{}"))
            server.route("POST /v1/responses", answer("resp_1", "Uno"))

            chat.chooseEffort(.high)
            try await Task.sleep(for: .milliseconds(150))
            #expect(server.calls(patches).isEmpty, "il server non ha ancora la conversazione")
            chat.send("a")
            #expect(await finished(chat))

            #expect(try #require(sends.first).json?["effort"] as? String == "high")
            #expect(server.calls(patches).isEmpty)
        }

        @Test func aFailedSaveWarnsWithoutASuccessNoticeAndKeepsThePick() async throws {
            let backend = try await backend()
            let chat = freshChat(backend)
            server.route("POST /v1/responses", answer("resp_1", "Uno"))
            server.route("PATCH /v1/agent/sessions/\(chat.sessionId)", .json(#"{"detail":"no"}"#, status: 400))

            chat.send("a")
            #expect(await finished(chat))
            chat.chooseEffort(.high)

            #expect(await TestEnv.waitUntil { chat.warning != nil })
            #expect(chat.warning?.contains(AriaEffortLevel.high.title) == true)
            #expect(chat.notice == nil, "non è una conferma: niente segno verde")
            #expect(chat.effortChoice == .high)
        }

        // MARK: Riaprire una conversazione

        @Test func reopeningRestoresTheSavedLevelAndTheNextSendCarriesIt() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend, session: session(effort: "high"))
            server.route("POST /v1/responses", answer("resp_1", "Uno"))

            #expect(chat.savedEffort == .high)
            #expect(chat.effortLevel == .high)
            chat.send("a")
            #expect(await finished(chat))

            #expect(try #require(sends.first).json?["effort"] as? String == "high")
            #expect(server.calls("PATCH \(base)").isEmpty, "ripristinare non scrive mai sul server")
        }

        @Test func aPickMadeBeforeTheSessionAnswersWins() async throws {
            let backend = try await backend()
            let chat = freshChat(backend)
            server.route("GET \(base)/messages", .json("[]"))
            server.route("GET \(base)/pending-interrupt", .json(#"{"interrupt":null}"#))
            server.route("GET \(base)", session(effort: "high", delay: 0.4))
            server.route("PATCH \(base)", .json("{}"))
            server.route("POST /v1/responses", answer("resp_1", "Uno"))

            let opening = Task { await chat.open(sessionId: "S1") }
            #expect(await TestEnv.waitUntil { !server.calls("GET \(base)").isEmpty })
            chat.chooseEffort(.medium)
            await opening.value

            #expect(chat.savedEffort == .high)
            #expect(chat.effortLevel == .medium)
            chat.send("a")
            #expect(await finished(chat))
            #expect(try #require(sends.first).json?["effort"] as? String == "medium")
        }

        @Test func aSavedLevelTheAppCannotNameIsNeverOverwrittenWithTheDefault() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend, session: session(effort: "turbo"))
            server.route("POST /v1/responses", answer("resp_1", "Uno"), answer("resp_2", "Due"))

            chat.send("a")
            #expect(await finished(chat))
            #expect(try #require(sends.first).json?["effort"] == nil)

            chat.chooseEffort(.high)
            chat.send("b")
            #expect(await finished(chat))
            #expect(sends.last?.json?["effort"] as? String == "high")
        }

        @Test func aFailedRestoreSendsNoLevelUntilThePersonPicks() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend, session: .json(#"{"detail":"x"}"#, status: 400))
            server.route("POST /v1/responses", answer("resp_1", "Uno"))

            chat.send("a")
            #expect(await finished(chat))

            #expect(try #require(sends.first).json?["effort"] == nil)
        }

        // MARK: Il costo della risposta

        @Test func aTurnUsageEventLandsOnTheReply() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend)
            server.route("POST /v1/responses", answer("resp_1", "Uno", usage: chargedEvent))

            chat.send("a")
            #expect(await finished(chat))

            let usage = try #require(chat.messages.last?.turnUsage)
            #expect(usage.credits == UsageFixture.d("2.4"))
            #expect(usage.status == .charged)
            #expect(usage.effort?.effective == .high)
        }

        @Test func aReplyWithoutTheEventHasNoUsage() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend)
            server.route("POST /v1/responses", answer("resp_1", "Uno"))

            chat.send("a")
            #expect(await finished(chat))

            #expect(chat.messages.last?.turnUsage == nil)
        }

        @Test func aStoredReplyFoldsAContinuationIntoTheEarlierCharge() throws {
            let row = #"""
            {"id":"a1","role":"assistant","text":"ok","responseId":"resp_1","pipeline":[
              {"type":"aria.intent_detected"},\#(chargedEvent),{"type":"aria.turn_usage","credits":"x","status":"charged"},\#(continuationEvent)]}
            """#
            let message = AriaAgentMessage(persisted: try JSONDecoder().decode(AriaPersistedMessage.self, from: Data(row.utf8)))

            #expect(message.turnUsageEvents.count == 2, "l'evento illeggibile si scarta")
            let usage = try #require(message.turnUsage)
            #expect(usage.credits == UsageFixture.d("2.4"), "la continuazione tiene l'addebito di prima")
            #expect(usage.status == .charged)
            #expect(usage.effort?.degraded == true, "il resto viene dalla continuazione")
        }

        // MARK: Limite di spesa

        @Test func theSpendCapIsFinalAndStaysOutOfTheGlobalError() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend)
            let model = AriaAgentChatViewModel(chat: chat, backend: backend)
            server.route("POST /v1/responses", .json(
                #"{"error":{"type":"spend_cap_reached","message":"cap","code":402,"request_id":"r"}}"#, status: 402))

            chat.send("a")
            #expect(await finished(chat))

            let reply = try #require(chat.messages.last)
            #expect(reply.error == AriaError.spendCapReached("").localizedDescription)
            #expect(reply.errorIsFinal)
            #expect(sends.count == 1, "nessun nuovo tentativo")
            #expect(model.failedTurn == nil && !model.canRetry, "niente Riprova")
            #expect(backend.lastError == nil)
            #expect(chat.lastError != nil, "il banner della chat lo dice")
        }

        @Test func anOrdinaryFailureStillOffersRetry() async throws {
            let backend = try await backend()
            let chat = await openedChat(backend)
            let model = AriaAgentChatViewModel(chat: chat, backend: backend)
            server.route("POST /v1/responses", .json(#"{"detail":"bad"}"#, status: 400))

            chat.send("a")
            #expect(await finished(chat))

            #expect(chat.messages.last?.errorIsFinal == false)
            #expect(model.canRetry)
        }

        // MARK: Il negozio dei crediti

        @Test func aCompanySwitchDropsTheFiguresAndReloadsForTheNewCompany() async throws {
            let backend = try await backend()
            #expect(backend.usage.config?.effort?.defaultLevel == .base)
            server.route("GET /v1/usage/config", .json(effortConfig(default: "medium")))

            await backend.selectCompany("c2")

            #expect(backend.usage.config?.effort?.defaultLevel != .base, "mai le cifre dell'altra azienda")
            #expect(await TestEnv.waitUntil { backend.usage.config?.effort?.defaultLevel == .medium })
            #expect(server.calls("GET /v1/usage/config").last?.header("company-id") == "c2")
            #expect(server.calls("GET /v1/usage/allowance").last?.header("company-id") == "c2")
        }

        @Test func aServiceUnavailableAnswerLeavesNoFiguresAndNoGlobalError() async throws {
            let backend = try await backend(config: .hostDown(), allowance: .hostDown(), settled: .failed)

            await backend.usage.refreshAllowance()

            #expect(backend.usage.config == nil && backend.usage.allowance == nil)
            #expect(backend.usage.allowancePhase == .failed)
            #expect(!backend.usage.isUnavailable)
            #expect(backend.lastError == nil)
        }

        @Test func aFailedRefreshDropsTheFiguresOfTheLastGoodAnswer() async throws {
            let backend = try await backend()
            #expect(backend.usage.config != nil)
            server.route("GET /v1/usage/config", .hostDown())

            await backend.usage.loadConfig(force: true)

            #expect(backend.usage.config == nil)
            #expect(backend.usage.configPhase == .failed)
        }

        @Test func aServerWithoutTheRoutesHidesTheFeatureInsteadOfShowingAnError() async throws {
            let backend = try await backend(config: .json("{}", status: 404), allowance: .json("{}", status: 404),
                                            settled: .failed)

            await backend.usage.refreshAllowance()

            #expect(backend.usage.isUnavailable)
            #expect(backend.usage.config == nil && backend.usage.allowance == nil)
        }
    }
}
