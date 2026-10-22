//
//  ChatMemoryUITests.swift
//  AriaLiteUITests
//
//  Created by Giovanni Michele on 21/10/26.
//
//  La card «Should Aria remember this?»: POST …/memory-facts/{id}/confirm, con il testo riscritto
//  dall'operatore (`content`). Compare solo se l'agente propone di imparare qualcosa: dipende dal modello,
//  quindi se non c'è i test si saltano. La traduzione dei fatti (POST …/memory-facts/translations) è
//  asincrona e il testo tradotto non è prevedibile: non si asserisce.
//

import XCTest

final class ChatMemoryUITests: AriaUITestCase {
    private func chatWithAMemoryProposal() throws {
        completeATurn("Remember this for the future: the nominal pressure of pump P-101 is 6 bar.")
        guard element("memory.card").waitForExistence(timeout: 20) else {
            throw XCTSkip("L'agente non ha proposto di ricordare niente in questa chat.")
        }
    }

    func testTheProposalCanBeEditedBeforeItIsSent() throws {
        try chatWithAMemoryProposal()

        element("memory.edit").tap()
        let editor = element("memory.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "«Edit» non apre l'editor")
        XCTAssertFalse((editor.value as? String ?? "").isEmpty, "L'editor parte vuoto: deve avere il testo del fatto")

        // Svuotato, non si può inviare: il server vuole un contenuto.
        editor.tap()
        editor.press(forDuration: 1.0)
        app.menuItems["Select All"].firstMatch.tap()
        app.keys["delete"].tap()
        XCTAssertFalse(element("memory.send").isEnabled, "«Send for review» è attivo con il testo vuoto")

        // Annullare non manda niente e rimette il testo del fatto.
        element("memory.cancelEdit").tap()
        XCTAssertTrue(element("memory.text").waitForExistence(timeout: 5))
        XCTAssertTrue(element("memory.card").exists, "La card è sparita senza una decisione")
    }

    func testSendingTheEditedFactForReviewRemovesTheCard() throws {
        try XCTSkipUnless(writesEnabled, "Segnala un fatto vero agli admin dell'azienda: serve ARIA_LIVE_WRITE=1")
        try chatWithAMemoryProposal()

        element("memory.edit").tap()
        let editor = element("memory.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(" (test UI)")
        element("memory.send").tap()

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element("memory.card"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 30), .completed, "La card è ancora lì dopo l'invio")
    }

    func testDiscardingTheProposalRemovesTheCard() throws {
        try XCTSkipUnless(writesEnabled, "Registra la decisione sul server: serve ARIA_LIVE_WRITE=1")
        try chatWithAMemoryProposal()

        element("memory.discard").tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element("memory.card"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 30), .completed, "La card è ancora lì dopo «Discard»")
    }
}
