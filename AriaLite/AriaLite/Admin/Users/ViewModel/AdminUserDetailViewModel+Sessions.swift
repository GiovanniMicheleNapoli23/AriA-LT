//
//  AdminUserDetailViewModel+Sessions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le sessioni aperte della persona (§5.5, solo titolari): si leggono all'apertura e dopo ogni chiusura, mai a
//  tempo. Chiudere la propria sessione fa rispondere `session_ended` alla prossima richiesta: lo gestiscono
//  AdminUsersFailure e `absorb` (si lascia l'azienda).
//

import Foundation

extension AdminUserDetailViewModel {
    func loadSessions() async {
        guard controls.sessions, row?.isInvitation == false, let api = owner.api else { return }
        do {
            sessions = try await api.sessions(userId: userId)
            sessionsLoaded = true
            sessionsFailed = false
        } catch {
            if let failure = AdminUsersFailure.from(error, backend: owner.backend) {
                if !sessionsLoaded { sessionsFailed = true }
                if failure.personGone || failure.sessionEnded { await owner.absorb(failure) }
            }
        }
    }

    /// Con due o più sessioni c'è "End all sessions".
    var canEndAll: Bool { sessions.count >= 2 }

    func askEnd(_ session: AdminUserSession) {
        guard !isWorking else { return }
        confirmation = .endSession(session)
    }

    func askEndAll() {
        guard !isWorking else { return }
        confirmation = .endAllSessions
    }

    func endSession(_ session: AdminUserSession) async {
        guard let api = owner.api else { return }
        await write {
            try await api.endSession(userId: userId, sessionId: session.id)
            return String(localized: "Session ended.")
        }
        await loadSessions()
    }

    func endAllSessions() async {
        guard let api = owner.api else { return }
        await write {
            try await api.endAllSessions(userId: userId)
            return String(localized: "All sessions ended.")
        }
        await loadSessions()
    }

    /// "App" o "Browser", poi "Signed in {date} · Used {when}".
    func timesText(_ session: AdminUserSession) -> String? {
        let now = owner.now
        let created = session.createdAt.flatMap(AdminUserPresence.date(from:)).map { Self.when($0, now: now) }
        let used = session.lastUsedAt.flatMap(AdminUserPresence.date(from:)).map { Self.when($0, now: now) }
        switch (created, used) {
        case let (created?, used?): return String(localized: "Signed in \(created) · Used \(used)")
        case let (created?, nil): return String(localized: "Signed in \(created)")
        case let (nil, used?): return String(localized: "Used \(used)")
        case (nil, nil): return nil
        }
    }
}
