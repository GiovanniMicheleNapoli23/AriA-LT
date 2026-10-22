//
//  ChatDictationUITests.swift
//  AriaLiteUITests
//
//  Created by Giovanni Michele on 21/10/26.
//
//  GET /v1/audio/transcriptions/capabilities e /v1/audio/vocabulary decidono chi scrive il testo dettato;
//  POST /v1/audio/polish lo ripulisce. Da qui si vede solo l'esito delle capacità (la riga sotto il microfono):
//  un testo dettato non si può far dire al simulatore, quindi polish e la trascrizione sul server non si provano.
//  In produzione CloudFront ferma i body da 8 KB in su, quindi la trascrizione sul server oggi fallisce: non si
//  asserisce che riesca.
//

import XCTest

final class ChatDictationUITests: AriaUITestCase {
    /// Le tre possibilità di `dictationSourceTitle` (inglese: la lingua è fissata all'avvio).
    private let sources = [
        "Aria transcribes when you stop",
        "Written on this phone, tidied up by Aria",
        "Written on this phone",
    ]

    func testTheMicrophoneSaysWhoWritesTheDictatedText() throws {
        let mic = element("chat.mic")
        XCTAssertTrue(mic.waitForExistence(timeout: 10))
        mic.tap()
        // Microfono e riconoscimento vocale chiedono il permesso la prima volta.
        allowSystemAlerts()

        let source = element("chat.dictation.source")
        let error = element("chat.dictation.error")
        let outcome = NSPredicate { _, _ in source.exists || error.exists }
        let appeared = XCTNSPredicateExpectation(predicate: outcome, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [appeared], timeout: 15), .completed,
                       "Il microfono non ha avviato la dettatura né ha dato un errore")
        if error.exists {
            throw XCTSkip("Dettatura non disponibile su questo simulatore: \(error.label)")
        }

        XCTAssertTrue(sources.contains(source.label), "Riga della dettatura inattesa: «\(source.label)»")
        // Quale delle tre dice cosa ha risposto il server: lo si allega al risultato.
        add(XCTAttachment(string: "Fonte della dettatura: \(source.label)"))

        element("chat.dictation.discard").tap()
        XCTAssertFalse(source.waitForExistence(timeout: 2), "«Scarta» non ha chiuso la dettatura")
    }
}
