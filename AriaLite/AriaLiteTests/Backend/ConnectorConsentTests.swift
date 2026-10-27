//
//  ConnectorConsentTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il consenso dei connettori: quando la sessione web è stata davvero annullata e quando invece iOS
//  rifiuta il ritorno https (app non associata al dominio) e si deve passare dal browser.
//

import AuthenticationServices
import Foundation
import Testing
@testable import AriaLite

@MainActor
struct ConnectorConsentTests {
    private func sessionError(reason: String?) -> NSError {
        var info: [String: Any] = [:]
        if let reason { info[NSLocalizedFailureReasonErrorKey] = reason }
        return NSError(domain: ASWebAuthenticationSessionErrorDomain,
                       code: ASWebAuthenticationSessionError.canceledLogin.rawValue, userInfo: info)
    }

    @Test func userCancelIsACancellation() {
        #expect(AdminConnectorConsentFlow.isCancellation(sessionError(reason: nil)))
        #expect(AdminConnectorConsentFlow.isCancellation(CancellationError()))
    }

    /// Il testo che iOS manda davvero quando l'associazione non è verificata.
    @Test func missingAssociationIsNotACancellation() {
        let error = sessionError(reason: "Application with identifier com.giovanniMichele.AriaLite is not associated "
            + "with domain app.ariaplt.com. Using HTTPS callbacks requires Associated Domains using the "
            + "`webcredentials` service type for app.ariaplt.com.")
        #expect(!AdminConnectorConsentFlow.isCancellation(error))
    }

    @Test func otherSessionErrorsAreNotCancellations() {
        let error = NSError(domain: ASWebAuthenticationSessionErrorDomain,
                            code: ASWebAuthenticationSessionError.presentationContextInvalid.rawValue)
        #expect(!AdminConnectorConsentFlow.isCancellation(error))
    }
}
