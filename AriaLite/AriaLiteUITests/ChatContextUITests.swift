//
//  ChatContextUITests.swift
//  AriaLiteUITests
//
//  Created by Giovanni Michele on 21/10/26.
//
//  GET /v1/chat/sessions/{id}/context e POST …/context/compact: l'anello della memoria nel composer
//  e "Fai spazio" (la conversazione salvata resta intera, si riassume solo quello che Aria legge).
//

import XCTest

final class ChatContextUITests: AriaUITestCase {
    /// Una chat nuova non ha ancora il contatore (404 = sessione sconosciuta al server): compare dopo un turno.
    func testTheMemoryRingIsHiddenInANewChatAndAppearsAfterATurn() throws {
        XCTAssertFalse(element("chat.contextRing").exists, "L'anello c'è già in una chat vuota")

        completeATurn()

        let ring = element("chat.contextRing")
        XCTAssertTrue(ring.waitForExistence(timeout: 30), "Dopo un turno il contatore del contesto non compare")
        let percent = try XCTUnwrap(ring.value as? String)
        XCTAssertTrue(percent.contains("%"), "Il valore dell'anello non è una percentuale: «\(percent)»")
    }

    func testTheRingOpensTheUsageDetails() {
        completeATurn()
        let ring = element("chat.contextRing")
        XCTAssertTrue(ring.waitForExistence(timeout: 30))
        ring.tap()

        let usage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'tokens'")).firstMatch
        XCTAssertTrue(usage.waitForExistence(timeout: 10), "Il popover non mostra «X of Y tokens»")
    }

    /// "Fai spazio" c'è solo se il server dice `canCompact`: serve una conversazione con qualcosa da riassumere.
    func testMakeRoomCompactsAndKeepsTheConversation() throws {
        let marker = "Reply with just the word OK."
        var found = false
        for _ in 0..<3 {
            completeATurn(marker)
            let ring = element("chat.contextRing")
            guard ring.waitForExistence(timeout: 30) else { continue }
            ring.tap()
            if element("chat.makeRoom").waitForExistence(timeout: 5) { found = true; break }
            // Si chiude il popover toccando fuori, in alto a sinistra.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12)).tap()
        }
        guard found else { throw XCTSkip("Dopo 3 turni il server non offre ancora di fare spazio (canCompact = false).") }

        let before = app.staticTexts.matching(NSPredicate(format: "label == %@", marker)).count
        element("chat.makeRoom").tap()
        // Finita la compattazione l'uso è quello dopo il riassunto: il pulsante torna attivo o sparisce (niente più da riassumere).
        let settled = NSPredicate { _, _ in
            let button = self.element("chat.makeRoom")
            return !button.exists || button.isEnabled
        }
        let done = XCTNSPredicateExpectation(predicate: settled, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 60), .completed, "La compattazione non finisce")
        XCTAssertFalse(app.alerts.firstMatch.exists, "La compattazione ha dato un errore")
        let after = app.staticTexts.matching(NSPredicate(format: "label == %@", marker)).count
        XCTAssertEqual(after, before, "Fare spazio non deve toccare i messaggi mostrati in chat")
    }
}
