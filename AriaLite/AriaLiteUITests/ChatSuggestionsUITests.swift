//
//  ChatSuggestionsUITests.swift
//  AriaLiteUITests
//
//  Created by Giovanni Michele on 21/10/26.
//
//  GET /v1/chat/suggestions: i chip di una chat vuota, nella lingua dell'app.
//

import XCTest

final class ChatSuggestionsUITests: AriaUITestCase {
    private var chips: XCUIElementQuery { app.buttons.matching(identifier: "chat.suggestion") }

    /// Una lista vuota è una risposta valida del server (utente nuovo, generazione non disponibile): niente chip.
    private func firstChip() throws -> XCUIElement {
        guard chips.firstMatch.waitForExistence(timeout: 20) else {
            throw XCTSkip("Il server non ha dato suggerimenti per questo operatore (lista vuota: risposta valida).")
        }
        return chips.firstMatch
    }

    func testAnEmptyChatShowsUpToFourSuggestionChips() throws {
        _ = try firstChip()
        XCTAssertTrue((1...4).contains(chips.count), "I chip sono al massimo 4, trovati \(chips.count)")
        for index in 0..<chips.count {
            XCTAssertFalse(chips.element(boundBy: index).label.isEmpty, "Il chip \(index) è senza testo")
        }
    }

    func testTappingAChipSendsItAsTheFirstMessage() throws {
        let chip = try firstChip()
        let text = chip.label
        chip.tap()

        // La chat non è più vuota: i chip spariscono e il testo del chip è il messaggio dell'operatore.
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: chips.firstMatch)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 15), .completed, "I chip sono ancora lì dopo il tocco")
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 15), "Il messaggio «\(text)» non è in chat")
        waitForTurnToEnd()
    }
}
