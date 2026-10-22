//
//  AriaUITestCase.swift
//  AriaLiteUITests
//
//  Created by Giovanni Michele on 21/10/26.
//
//  Base dei test UI contro il backend vero (api.ariaplt.com). Non girano mai da soli: servono variabili
//  d'ambiente (nello schema, "Test" › Environment Variables, oppure `TEST_RUNNER_NOME=… xcodebuild test`).
//
//      ARIA_LIVE_SESSION=<token>   sessione di un OPERATORE (il `set-auth-token` di POST /api/auth/mobile/verify),
//                                  la stessa dei test live in AriaLiteTests. Una sessione admin non va bene: le rotte
//                                  nuove sono quelle dell'operatore ("operator member parity") e i limiti
//                                  dell'operatore (niente "sposta gli altri", assegnatario solo sé stesso) sono
//                                  quello che si prova. Il token passa all'app come `ARIA_UITEST_SESSION`.
//      ARIA_LIVE_WRITE=1           abilita i test che scrivono davvero: l'ordine di lavoro del closeout
//                                  (ARIA, e MaintainX se collegato) e la segnalazione di un fatto agli admin.
//
//  Senza ARIA_LIVE_WRITE ogni test legge soltanto, con una eccezione: ogni test che manda un messaggio crea
//  una conversazione nuova nello storico dell'operatore (e usa un turno vero dell'agente).
//

import XCTest

class AriaUITestCase: XCTestCase {
    var app: XCUIApplication!

    // MARK: Ambiente

    static func environment(_ key: String) -> String? {
        let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw?.isEmpty == false ? raw : nil
    }

    var writesEnabled: Bool { Self.environment("ARIA_LIVE_WRITE") == "1" }

    // MARK: Avvio

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let session = Self.environment("ARIA_LIVE_SESSION") else {
            throw XCTSkip("ARIA_LIVE_SESSION mancante (token di sessione di un operatore)")
        }
        app = XCUIApplication()
        // Lingua fissa: i suggerimenti arrivano nella lingua dell'app (Accept-Language) e i testi si leggono uguali.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["ARIA_UITEST_SESSION"] = session
        app.launch()
        allowSystemAlerts()
        XCTAssertTrue(element("chat.input").waitForExistence(timeout: 45),
                      "La chat non si apre: la sessione ARIA_LIVE_SESSION è scaduta o non è di un operatore?")
    }

    // MARK: Elementi

    /// Per identificatore, qualunque sia il tipo (un TextField verticale è un textView, un Menu un button…).
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func elements(_ identifier: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: identifier)
    }

    // MARK: Avvisi di sistema

    /// Notifiche, microfono, riconoscimento vocale: i permessi sono avvisi di SpringBoard, non dell'app.
    @discardableResult
    func allowSystemAlerts(timeout: TimeInterval = 4) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        var handled = false
        while alert.waitForExistence(timeout: timeout) {
            let preferred = ["Allow", "Allow While Using App", "OK", "Allow Once"]
            guard let button = preferred.map({ alert.buttons[$0] }).first(where: \.exists) ?? alert.buttons.allElementsBoundByIndex.last
            else { break }
            button.tap()
            handled = true
        }
        return handled
    }

    // MARK: Chat

    /// Scrive e invia un messaggio; non aspetta la risposta.
    func send(_ text: String) {
        let input = element("chat.input")
        input.tap()
        input.typeText(text)
        element("chat.send").tap()
    }

    /// Aspetta la fine di un turno dell'agente: il pulsante "Stop" compare e poi sparisce.
    func waitForTurnToEnd(timeout: TimeInterval = 150, file: StaticString = #filePath, line: UInt = #line) {
        let stop = element("chat.stop")
        // Un turno brevissimo può finire prima che si veda lo Stop: non è un errore.
        _ = stop.waitForExistence(timeout: 20)
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: stop)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: timeout), .completed,
                       "L'agente non ha finito di rispondere in \(Int(timeout)) s", file: file, line: line)
    }

    /// Una domanda breve e un turno finito: la sessione esiste sul server (serve al contatore del contesto).
    func completeATurn(_ prompt: String = "Reply with just the word OK.") {
        send(prompt)
        waitForTurnToEnd()
    }

    func openOptions() {
        let more = element("chat.more")
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
    }

    /// Una chat con una procedura (checklist) è il presupposto del closeout e del report: dipende da cosa risponde
    /// l'agente, quindi se non la propone il test si salta invece di fallire.
    func startProcedureChat() throws {
        completeATurn("Give me a short step-by-step procedure with a checklist to replace the oil filter of a compressor.")
        openOptions()
        let step = element("options.currentStep")
        if !step.waitForExistence(timeout: 10) {
            app.buttons["Done"].tap()
            throw XCTSkip("L'agente non ha proposto una procedura in questa chat: niente da chiudere né da riportare.")
        }
    }
}
