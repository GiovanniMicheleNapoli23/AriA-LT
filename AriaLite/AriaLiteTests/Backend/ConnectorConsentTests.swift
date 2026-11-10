//
//  ConnectorConsentTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il consenso dei connettori: quando la sessione web è stata davvero annullata e quando invece iOS
//  rifiuta il ritorno https (app non associata al dominio) e si deve passare dal browser; quali card sono
//  Composio; `membership` di /v1/me che decide chi gestisce i connettori.
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

    /// Le dieci card one-click di Composio si riconoscono dal provider anche senza `mcp_url`.
    @Test(arguments: ["gmail-personal", "calendar-personal", "drive-personal", "teams", "outlook",
                      "dynamics-crm", "salesforce-crm", "slack-chat", "asana", "hubspot-crm"])
    func composioCardsAreRecognisedByProvider(provider: String) {
        #expect(AdminConnectorConsentFlow.isComposio(provider: provider, mcpUrl: nil))
    }

    @Test func otherConnectorsAreNotComposio() {
        #expect(!AdminConnectorConsentFlow.isComposio(provider: "maintainx", mcpUrl: nil))
        #expect(!AdminConnectorConsentFlow.isComposio(provider: "notion", mcpUrl: "https://mcp.notion.com/mcp"))
        #expect(AdminConnectorConsentFlow.isComposio(provider: "custom", mcpUrl: "https://backend.composio.dev/aria-toolkit/gmail"))
        #expect(!AdminConnectorConsentFlow.isComposio(provider: "custom", mcpUrl: "http://backend.composio.dev/x"))
    }

    /// GET /v1/me con `Company-Id`: `membership.restricted` decide l'accesso pieno; senza il campo resta nil.
    @Test func meDecodesMembershipTolerantly() throws {
        let full = try JSONDecoder().decode(AriaMe.self, from: Data(
            #"{"id":"u1","name":"Ada","email":"a@x.it","operatorProfile":null,"membership":{"role":"admin","restricted":false}}"#.utf8))
        #expect(full.membership == AriaMeMembership(role: "admin", restricted: false))
        #expect(full.account.kind == .admin)
        let old = try JSONDecoder().decode(AriaMe.self, from: Data(#"{"id":"u1","name":"Ada","email":"a@x.it"}"#.utf8))
        #expect(old.membership == nil)
        let odd = try JSONDecoder().decode(AriaMe.self, from: Data(#"{"id":"u1","membership":{"role":"admin"}}"#.utf8))
        #expect(odd.membership == nil, "una forma inattesa non rompe /v1/me")
    }

    /// Un connettore personale è collegato per chi guarda solo con il suo account: la riga dell'azienda
    /// (`configured`) non conta, come sulla web.
    @Test func perMemberConnectorFollowsTheViewersGrant() throws {
        func connector(_ json: String) throws -> AdminConnector {
            try JSONDecoder().decode(AdminConnector.self, from: Data(json.utf8))
        }
        let mine = try connector(#"{"provider":"gmail-personal","status":"configured","connectionScope":"user","myGrant":{"status":"connected"}}"#)
        #expect(mine.knownStatus == .connected)
        let notYet = try connector(#"{"provider":"gmail-personal","status":"configured","connectionScope":"user"}"#)
        #expect(notYet.knownStatus == .disconnected)
        let expired = try connector(#"{"provider":"gmail-personal","status":"configured","connectionScope":"user","myGrant":{"status":"expired"}}"#)
        #expect(expired.knownStatus == .attention)
        let shared = try connector(#"{"provider":"hubspot","status":"connected","connectionScope":"company","myGrant":{"status":"expired"}}"#)
        #expect(shared.knownStatus == .connected, "un connettore dell'azienda segue la sua riga")
    }
}
