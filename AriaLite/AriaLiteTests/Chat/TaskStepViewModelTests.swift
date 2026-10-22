//
//  TaskStepViewModelTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica di uno step di procedura senza interfaccia: il task in corso è il primo non spuntato,
//  "Fatto" e "Indietro" spostano la spunta, l'ultimo task completa lo step, e gli haptic seguono le spunte.
//

import Foundation
import SwiftUI
import Testing
@testable import AriaLite

extension BackendTests {
    @Suite("Task step view model")
    @MainActor
    struct TaskStepViewModelTests {
        init() { TestEnv.reset() }

        private func model() throws -> AriaTaskStepViewModel {
            let json = #"{"agent":"step","step_number":2,"step_title":"Open the panel","revision":1,"tasks":[{"id":"t1","index":1,"text":"Unscrew"},{"id":"t2","index":2,"text":"Lift"},{"id":"t3","index":3,"text":"Check"}]}"#
            let list = try JSONDecoder().decode(AriaTaskList.self, from: Data(json.utf8))
            let chat = AriaAgentChat(backend: AriaBackend(), progressStore: AriaTaskProgressStore(inMemory: true))
            return AriaTaskStepViewModel(chat: chat, list: list, messageId: "m1")
        }

        @Test("All'inizio il task in corso è il primo e non c'è niente a cui tornare")
        func startsAtFirstTask() throws {
            let model = try model()
            #expect(model.next?.id == "t1")
            #expect(model.previous == nil)
            #expect(model.doneCount == 0)
            #expect(model.outcome == .inProgress)
        }

        @Test("«Fatto» passa al task successivo; «Indietro» torna a quello prima")
        func completeAndGoBack() throws {
            let model = try model()
            model.complete(model.next!)
            #expect(model.next?.id == "t2")
            #expect(model.previous?.id == "t1")
            #expect(model.forward)
            model.goBack()
            #expect(model.next?.id == "t1")
            #expect(!model.forward)
            #expect(!model.isChecked(model.tasks[0]))
        }

        @Test("L'ultimo task rimasto completa lo step")
        func lastTaskCompletesStep() throws {
            let model = try model()
            model.complete(model.tasks[0])
            model.complete(model.tasks[1])
            #expect(model.isLastRemaining(model.tasks[2]))
            #expect(!model.isLastRemaining(model.tasks[1]))
            model.complete(model.tasks[2])
            #expect(model.next == nil)
            #expect(model.isDone)
            #expect(model.outcome == .completed)
        }

        @Test("Haptic: spunta decisa, successo all'ultima, selezione togliendo una spunta")
        func feedback() {
            #expect(AriaTaskStepViewModel.feedback(from: 0, to: 1, of: 3) == .impact(weight: .medium))
            #expect(AriaTaskStepViewModel.feedback(from: 2, to: 3, of: 3) == .success)
            #expect(AriaTaskStepViewModel.feedback(from: 2, to: 1, of: 3) == .selection)
            #expect(AriaTaskStepViewModel.feedback(from: 2, to: 2, of: 3) == nil)
        }

        @Test("La domanda su un task si apre e si chiude dall'alert")
        func askingAboutATask() throws {
            let model = try model()
            model.ask(about: model.tasks[1])
            #expect(model.isAsking)
            model.isAsking = false
            #expect(!model.isAsking)
        }
    }
}
