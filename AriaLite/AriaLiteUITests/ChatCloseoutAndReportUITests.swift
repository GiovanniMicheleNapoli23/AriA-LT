//
//  ChatCloseoutAndReportUITests.swift
//  AriaLiteUITests
//
//  Created by Giovanni Michele on 21/10/26.
//
//  POST /v1/companies/{id}/sessions/{id}/closeout (proposta, poi conferma) e GET …/report.docx, dal menu "···".
//  Presuppongono una chat con una procedura: dipende dall'agente, e se non la propone i test si saltano.
//
//  Scrive davvero solo `testConfirmingTheCloseoutWritesTheWorkOrder` (ARIA_LIVE_WRITE=1): crea un ordine in ARIA
//  e, se l'azienda lo collega, in MaintainX. Il report .docx non salva niente sul server.
//  Non coperto: POST …/report (archivia senza closeout), raggiungibile solo da un closeout «solo report»
//  che parte da una domanda dell'agente.
//

import XCTest

final class ChatCloseoutAndReportUITests: AriaUITestCase {
    func testTheReportCanBeDownloadedAsAWordFileAndShared() throws {
        try startProcedureChat()

        let report = reveal("options.report")
        XCTAssertTrue(report.waitForExistence(timeout: 10), "«Intervention report (Word)» non c'è: report non disponibile")
        report.tap()

        let share = element("options.reportShare")
        XCTAssertTrue(share.waitForExistence(timeout: 60), "Il report .docx non è arrivato")
        XCTAssertFalse(element("options.reportError").exists, "Il report ha dato un errore: \(element("options.reportError").label)")
    }

    func testTheCloseoutProposalIsShownWithTheOperatorLimitsAndWritesNothing() throws {
        try startProcedureChat()

        reveal("options.closeOut").tap()
        let title = element("closeout.title")
        let error = element("closeout.error")
        let loaded = NSPredicate { _, _ in title.exists || error.exists }
        let expectation = XCTNSPredicateExpectation(predicate: loaded, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 60), .completed, "La proposta di closeout non arriva")

        if error.exists {
            XCTFail("Il closeout ha risposto con un errore: \(error.label)")
            return
        }
        XCTAssertFalse((title.value as? String ?? "").isEmpty, "La proposta non ha un titolo")
        // Limiti dell'operatore: può assegnare l'ordine solo a sé stesso e non sposta gli ordini dei colleghi.
        XCTAssertTrue(element("closeout.assignToMe").exists, "Manca «Assign to me»")
        XCTAssertFalse(element("closeout.conflictChoice").exists, "L'operatore non deve poter «spostare gli altri»")

        // Niente conferma: la proposta non scrive nulla.
        element("closeout.dismiss").tap()
        XCTAssertTrue(element("chat.input").waitForExistence(timeout: 10))
    }

    func testConfirmingTheCloseoutWritesTheWorkOrder() throws {
        try XCTSkipUnless(writesEnabled, "Scrive un ordine vero in ARIA (e MaintainX): serve ARIA_LIVE_WRITE=1")
        try startProcedureChat()

        reveal("options.closeOut").tap()
        let confirm = element("closeout.confirm")
        XCTAssertTrue(element("closeout.title").waitForExistence(timeout: 60), "La proposta di closeout non arriva")
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()

        XCTAssertTrue(element("closeout.result.ARIA").waitForExistence(timeout: 60), "Nessun esito di ARIA dopo la conferma")
        XCTAssertFalse(element("closeout.error").exists, "Errore dopo la conferma: \(element("closeout.error").label)")
        element("closeout.dismiss").tap()
    }
}
