//
//  AdminConnectorWebAuthentication.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il ponte fra la sessione web dell'ambiente SwiftUI e il flusso di consenso dei view model: le viste passano
//  `webAuthenticationSession.authenticateConsent` e basta, senza ripetere i parametri della sessione.
//

import AuthenticationServices
import SwiftUI

extension WebAuthenticationSession {
    /// Apre il consenso e aspetta il ritorno sull'https dell'app. La sessione condivisa del browser: l'utente
    /// ritrova l'accesso già fatto al provider.
    func authenticateConsent(_ url: URL, _ host: String, _ path: String) async throws -> URL {
        try await authenticate(using: url, callback: .https(host: host, path: path),
                               preferredBrowserSession: .shared, additionalHeaderFields: [:])
    }
}
