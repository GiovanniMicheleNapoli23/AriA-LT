//
//  ChatTaskProgressTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 17/10/26.
//
//  Le spunte e le segnalazioni sui task di una procedura sopravvivono a chiusura e riapertura della chat:
//  si salvano per sessione, con una chiave che non dipende dall'id del messaggio (in streaming è un UUID,
//  ricaricato dal server è "db-…").
//

import Foundation
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Chat task progress")
    struct ChatTaskProgress {
        private let server = StubServer.shared
        private let defaults = UserDefaults.standard
        /// Archivio in memoria: i test non toccano le spunte vere del dispositivo.
        private let progress = AriaTaskProgressStore(inMemory: true)

        init() {
            TestEnv.reset()
            defaults.removeObject(forKey: "aria.chat.current_session")
        }

        private func rows(messageId: String) -> String {
            let list = #"{"type":"aria.task_list","agent":"step","step_number":2,"step_title":"Open the panel","revision":1,"tasks":[{"id":"t1","index":1,"text":"Unscrew"},{"id":"t2","index":2,"text":"Lift"}]}"#
            return #"[{"id":"u\#(messageId)","role":"user","text":"go"},{"id":"\#(messageId)","role":"assistant","text":"Ok","pipeline":[\#(list)]}]"#
        }

        private func signedInChat() async throws -> AriaAgentChat {
            TestEnv.stubSignIn()
            let backend = AriaBackend()
            try await TestEnv.requestLink(backend)
            try await backend.completeSignIn(with: AriaSignInLink(token: "t"))
            return AriaAgentChat(backend: backend, remembersSession: true, progressStore: progress)
        }

        private func firstTask(_ chat: AriaAgentChat) throws -> (messageId: String, task: AriaTaskList.Task) {
            let step = try #require(chat.sessionTaskLists.first)
            return (step.messageId, step.list.tasks[0])
        }

        @Test func tickedTasksComeBackWhenTheConversationIsReopened() async throws {
            let chat = try await signedInChat()
            server.route("GET /v1/agent/sessions/S1/messages", .json(rows(messageId: "m1")))
            await chat.open(sessionId: "S1")
            var (id, task) = try firstTask(chat)
            chat.toggleTask(task, in: id)
            #expect(chat.isTaskChecked(task, in: id))

            // Un'altra conversazione e poi di nuovo questa: il server rende lo stesso step con un altro id di riga.
            chat.newConversation()
            server.route("GET /v1/agent/sessions/S1/messages", .json(rows(messageId: "m9")))
            await chat.open(sessionId: "S1")
            (id, task) = try firstTask(chat)
            #expect(id == "db-m9")
            #expect(chat.isTaskChecked(task, in: id))
        }

        @Test func tickedTasksSurviveARelaunch() async throws {
            let chat = try await signedInChat()
            server.route("GET /v1/agent/sessions/S1/messages", .json(rows(messageId: "m1")))
            await chat.open(sessionId: "S1")
            let (id, task) = try firstTask(chat)
            chat.toggleTask(task, in: id)

            let relaunched = AriaAgentChat(backend: AriaBackend(), remembersSession: true, progressStore: progress)
            #expect(relaunched.sessionId == "S1")
            #expect(relaunched.checkedTasks == chat.checkedTasks)
        }

        /// Una checklist arrivata in streaming: il backend non la mette nello storico (niente `pipeline`).
        private let streamedStep = """
        event: response.created
        data: {"id":"resp_7"}

        event: response.output_text.done
        data: {"text":"Step 2"}

        event: aria.task_list
        data: {"type":"aria.task_list","agent":"step","step_number":2,"step_title":"Open the panel","revision":1,"tasks":[{"id":"t1","index":1,"text":"Unscrew"},{"id":"t2","index":2,"text":"Lift"}]}

        event: response.completed
        data: {"status":"completed"}


        """

        private func waitForTurn(_ chat: AriaAgentChat) async throws {
            for _ in 0..<200 where chat.isStreaming { try await Task.sleep(for: .milliseconds(20)) }
            #expect(!chat.isStreaming)
        }

        @Test func streamedStepsComeBackWhenTheHistoryHasNone() async throws {
            let chat = try await signedInChat()
            server.route("GET /v1/agent/sessions/S1/messages", .json("[]"))
            await chat.open(sessionId: "S1")
            server.route("POST /v1/responses",
                         Reply(status: 200, headers: ["Content-Type": "text/event-stream"], body: Data(streamedStep.utf8)))
            chat.send("go")
            try await waitForTurn(chat)
            let (id, task) = try firstTask(chat)
            chat.toggleTask(task, in: id)

            // Uscita e ritorno: lo storico ha la risposta (con il suo responseId) ma non la checklist.
            chat.newConversation()
            #expect(chat.sessionTaskLists.isEmpty)
            server.route("GET /v1/agent/sessions/S1/messages", .json(
                #"[{"id":"u1","role":"user","text":"go"},{"id":"a1","role":"assistant","text":"Step 2","responseId":"resp_7"}]"#))
            await chat.open(sessionId: "S1")

            let restored = try #require(chat.sessionTaskLists.first)
            #expect(restored.messageId == "db-a1")
            #expect(restored.list.stepTitle == "Open the panel")
            #expect(chat.isTaskChecked(restored.list.tasks[0], in: restored.messageId))
            #expect(!chat.isTaskChecked(restored.list.tasks[1], in: restored.messageId))
        }

        @Test func aDeletedConversationLeavesNoSteps() {
            let list = AriaTaskList(agent: "step", stepNumber: 1, stepTitle: "T", stepLabel: nil, revision: 1,
                                    tasks: [.init(id: "t1", index: 1, text: "A")])
            progress.saveTaskList(list, sessionId: "S1", responseId: "resp_1", assistantIndex: 0)
            progress.forget(sessionId: "S1")
            #expect(progress.taskLists(sessionId: "S1").isEmpty)
        }

        @Test func aNewConversationStartsClean() async throws {
            let chat = try await signedInChat()
            server.route("GET /v1/agent/sessions/S1/messages", .json(rows(messageId: "m1")))
            await chat.open(sessionId: "S1")
            let (id, task) = try firstTask(chat)
            chat.toggleTask(task, in: id)

            chat.newConversation()
            #expect(chat.checkedTasks.isEmpty)
            #expect(AriaAgentChat(backend: AriaBackend(), remembersSession: true, progressStore: progress).checkedTasks.isEmpty)
        }
    }
}
