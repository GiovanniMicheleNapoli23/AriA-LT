//
//  AgentMessageTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 20/11/26.
//
//  AriaAgentMessage: `revision` cresce a ogni modifica di quello che si mostra, e `displayText` (calcolato solo quando
//  cambiano testo, domanda o checklist) segue sempre il testo.
//

import Foundation
import Testing
@testable import AriaLite

struct AgentMessageTests {
    @Test func revisionGrowsWithEveryChangeOfWhatTheMessageShows() {
        var message = AriaAgentMessage.pendingAssistant()
        let start = message.revision
        message.apply(.textDelta("Hi"))
        let afterText = message.revision
        #expect(afterText > start)
        message.finished = true
        #expect(message.revision > afterText)
    }

    @Test func displayTextFollowsTheTextAsItGrows() {
        var message = AriaAgentMessage.pendingAssistant()
        message.apply(.textDelta("Hello\n```elicit\n{}"))
        #expect(message.displayText == "Hello", "il blocco elicit ancora aperto non si vede")
        message.apply(.textDone("Plain final"))
        #expect(message.displayText == "Plain final")
    }

    @Test func displayTextIsReadyRightAfterInit() {
        let message = AriaAgentMessage(id: "a", role: .assistant, text: "Ready")
        #expect(message.displayText == "Ready")
    }

    @Test func aRebuiltMessageWithTheSameIdIsNotTakenForTheOldOne() {
        var streamed = AriaAgentMessage(id: "a", role: .assistant, text: "")
        let before = streamed.revision
        streamed.apply(.textDelta("Hi"))
        #expect(streamed.revision != before, "ogni modifica cambia la revisione")
        let fromServer = AriaAgentMessage(id: "a", role: .assistant, text: "Hi there")
        #expect(fromServer.revision != streamed.revision)
    }
}
