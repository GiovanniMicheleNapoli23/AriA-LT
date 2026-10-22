//
//  AdminMobileUserDetailViewModel+Sessions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I telefoni di un operatore: uscire da uno o da tutti. Entrambe le azioni passano dalla conferma.
//

import Foundation

extension AdminMobileUserDetailViewModel {
    /// "iPhone 15 · active 3 minutes ago · signed in 12 Oct".
    func sessionLine(_ session: AdminMobileUserSession) -> String {
        var parts: [String] = []
        if let active = session.lastActiveAt {
            parts.append(String(localized: "Active \(active.formatted(.relative(presentation: .named)))"))
        }
        if let created = session.createdAt {
            parts.append(String(localized: "Signed in \(created.formatted(date: .abbreviated, time: .omitted))"))
        }
        return parts.joined(separator: " · ")
    }

    func sessionTitle(_ session: AdminMobileUserSession) -> String {
        session.device.isEmpty ? String(localized: "Unknown device") : session.device
    }

    func askToLogOutAll(_ user: AdminMobileUser) { pendingConfirmation = .logoutAll(user) }
    func askToLogOut(_ session: AdminMobileUserSession, of user: AdminMobileUser) {
        pendingConfirmation = .logoutDevice(user, session)
    }

    /// Il pulsante del dialogo.
    func confirm(_ confirmation: AdminMobileUserConfirmation) async {
        pendingConfirmation = nil
        guard let companyId = list.backend.activeCompanyId, !isRevoking else { return }
        isRevoking = true
        defer { isRevoking = false }
        do {
            switch confirmation {
            case .logoutAll(let user):
                _ = try await list.backend.api.call(
                    AdminMobileUsersAPI.revokeAllSessions(companyId: companyId, userId: user.id))
                sessions = []
            case .logoutDevice(let user, let session):
                _ = try await list.backend.api.call(
                    AdminMobileUsersAPI.revokeSession(companyId: companyId, userId: user.id, sessionId: session.id))
                sessions.removeAll { $0.id == session.id }
            case .suspend, .remove:
                break
            }
        } catch {
            // Già uscito sul server: si aggiorna l'elenco e basta.
            if case .http(let status, _)? = error as? AriaError, status == 404 {
                await loadSessions()
            } else {
                actionError = AdminMobileUserFailure.message(for: error, backend: list.backend)
            }
        }
    }
}
