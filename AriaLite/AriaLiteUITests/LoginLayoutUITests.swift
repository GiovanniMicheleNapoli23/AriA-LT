//
//  LoginLayoutUITests.swift
//  AriaLiteUITests
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il login con la tastiera aperta, anche con l'iPhone in orizzontale: il campo e "Send sign-in link"
//  restano sopra la tastiera. Non serve una sessione (gira su un simulatore senza account salvato).
//

import XCTest

final class LoginLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testTheSendButtonStaysAboveTheKeyboardInPortrait() throws {
        try assertFormAboveKeyboard(.portrait)
    }

    func testTheSendButtonStaysAboveTheKeyboardInLandscape() throws {
        try assertFormAboveKeyboard(.landscapeLeft)
    }

    private func assertFormAboveKeyboard(_ orientation: UIDeviceOrientation) throws {
        let email = app.textFields["Work email"]
        guard email.waitForExistence(timeout: 15) else {
            // `xcrun simctl keychain <device> reset` la cancella.
            throw XCTSkip("Il login non c'è: sul simulatore è rimasta una sessione salvata")
        }
        XCUIDevice.shared.orientation = orientation
        email.tap()
        let keyboard = app.keyboards.firstMatch
        guard keyboard.waitForExistence(timeout: 5) else {
            throw XCTSkip("Tastiera software assente (tastiera hardware collegata al simulatore)")
        }
        email.typeText("operator@example.com")
        // La scroll view si riassesta dopo la tastiera.
        let send = app.buttons["Send sign-in link"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "login-\(orientation == .portrait ? "portrait" : "landscape")-keyboard"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertLessThanOrEqual(email.frame.maxY, keyboard.frame.minY, "Il campo email finisce sotto la tastiera")
        XCTAssertLessThanOrEqual(send.frame.maxY, keyboard.frame.minY, "\"Send sign-in link\" finisce sotto la tastiera")
        XCTAssertTrue(send.isHittable, "\"Send sign-in link\" non si può toccare")
    }
}
