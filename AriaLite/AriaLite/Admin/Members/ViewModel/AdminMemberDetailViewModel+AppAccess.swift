//
//  AdminMemberDetailViewModel+AppAccess.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il blocco "Accesso all'app" della scheda, solo per owner e admin: stato, azioni della tabella del §6.4
//  (dai accesso, rimanda invito, sospendi, riattiva, togli) e dispositivi. Dare l'accesso e rinnovare l'invito sono
//  due passi: se il secondo (l'email) non va, l'accesso resta dato e lo si dice come avviso, non come errore.
//

import Foundation

extension AdminMemberDetailViewModel {
    // MARK: - Stato

    var mobileRow: AdminMobileUser? { owner.mobileRow(for: userId) }

    /// `nil`: il blocco non c'è (chi guarda non è admin, o il record non ha membership).
    var appState: AdminAppAccessState? {
        guard viewer.isAdmin, let member, member.access != nil else { return nil }
        return AdminMemberRules.appAccessState(member, row: mobileRow)
    }

    var appOffers: [AdminAppAccessOffer] {
        appState.map { AdminMemberRules.appOffers($0, seats: owner.seats) } ?? []
    }

    /// Cosa dice il blocco, una riga per stato (tabella del §6.4).
    var appStatusText: String {
        guard let state = appState else { return String(localized: "Doesn't use the app.") }
        switch state {
        case .ownerOrAdmin: return String(localized: "Enters the app as an owner or admin, without a seat.")
        case .companySuspended(let hasRow):
            return hasRow
                ? String(localized: "Suspended in the company: their app access, if any, comes back as it was when you reactivate them.")
                : String(localized: "Doesn't use the app.")
        case .none: return String(localized: "Doesn't use the app.")
        case .invited: return String(localized: "Invited to the app.")
        case .expired: return String(localized: "The invitation has expired.")
        case .active: return String(localized: "App active.")
        case .appSuspended: return String(localized: "App suspended.")
        }
    }

    /// "Valid until 24 Nov, 10:30" / "Expired on 20 Nov, 10:30".
    var inviteLine: String? {
        guard let state = appState else { return nil }
        switch state {
        case .invited(let until):
            return until.map { String(localized: "Valid until \($0.formatted(date: .abbreviated, time: .shortened))") }
        case .expired(let on):
            return on.map { String(localized: "Expired on \($0.formatted(date: .abbreviated, time: .shortened))") }
        default:
            return nil
        }
    }

    /// La disponibilità (libero, occupato, fuori turno), per l'app attiva.
    var availability: String? {
        guard let state = appState, case .active(let raw) = state, !raw.isEmpty else { return nil }
        return raw
    }

    /// "App seats: 7 of 10".
    var seatsText: String? { owner.seatsText }

    /// Le licenze sono finite e ci sono azioni che ne prenderebbero una: lo si spiega.
    var seatsFullNote: String? {
        appOffers.contains { !$0.isEnabled } ? String(localized: "The app seats are full.") : nil
    }

    // MARK: - Presentazione delle azioni

    func title(for action: AdminAppAccessAction) -> String {
        switch action {
        case .giveAccess: String(localized: "Give app access")
        case .resendInvite, .renewAndResend: String(localized: "Resend invitation")
        case .suspendApp: String(localized: "Suspend the app only")
        case .reactivateApp: String(localized: "Reactivate the app")
        case .revokeAccess: String(localized: "Remove access")
        }
    }

    func systemImage(for action: AdminAppAccessAction) -> String {
        switch action {
        case .giveAccess: "iphone.badge.plus"
        case .resendInvite, .renewAndResend: "paperplane"
        case .suspendApp: "pause.circle"
        case .reactivateApp: "play.circle"
        case .revokeAccess: "iphone.slash"
        }
    }

    /// Le azioni che aprono o riprendono l'accesso sono quelle in evidenza.
    func isProminent(_ action: AdminAppAccessAction) -> Bool {
        switch action {
        case .giveAccess, .resendInvite, .renewAndResend, .reactivateApp: true
        case .suspendApp, .revokeAccess: false
        }
    }

    func isDestructive(_ action: AdminAppAccessAction) -> Bool { action == .revokeAccess }

    func isEnabled(_ offer: AdminAppAccessOffer) -> Bool { offer.isEnabled && !isWorking }

    // MARK: - Azioni

    func perform(_ action: AdminAppAccessAction) async {
        guard let member, let state = appState,
              appOffers.contains(where: { $0.action == action && $0.isEnabled }) else { return }
        switch action {
        case .giveAccess:
            await giveAccess()
        case .resendInvite:
            await sendInvite(renewing: false)
        case .renewAndResend:
            await sendInvite(renewing: true)
        case .reactivateApp:
            await setAppStatus("active")
        case .suspendApp:
            pendingConfirmation = .suspendApp
        case .revokeAccess:
            var appWasActive = false
            if case .active = state { appWasActive = true }
            pendingConfirmation = .revokeAccess(freesSeat: AdminMemberRules.holdsSeat(member, row: mobileRow),
                                                appWasActive: appWasActive)
        }
    }

    /// POST …/mobile-users, poi l'email d'invito.
    private func giveAccess() async {
        guard let companyId else { return }
        await exclusive {
            emailNotice = nil
            appInfo = nil
            do {
                _ = try await backend.api.call(
                    AdminMobileUsersAPI.add(companyId: companyId, AdminMobileUserAdd(userId: userId)))
            } catch {
                await report(error)
                return
            }
            notices.removeAll { if case .appNotGiven = $0 { true } else { false } }
            await emailInvite(.given)
            await reloadAfterAction()
        }
    }

    /// "Rimanda invito": con l'invito scaduto prima lo si rinnova (…/resend, che non manda email), poi l'email;
    /// con l'invito ancora valido solo l'email.
    private func sendInvite(renewing: Bool) async {
        guard let companyId else { return }
        await exclusive {
            emailNotice = nil
            appInfo = nil
            if renewing {
                do {
                    _ = try await backend.api.call(AdminMobileUsersAPI.resend(companyId: companyId, userId: userId))
                } catch {
                    await report(error)
                    return
                }
            }
            await emailInvite(renewing ? .renewed : .resent)
            await reloadAfterAction()
        }
    }

    /// Che passo ha portato all'email: dice come raccontare l'esito.
    private enum InviteKind {
        case given, renewed, resent

        var sentText: String {
            switch self {
            case .given, .resent: String(localized: "Invitation sent by email.")
            case .renewed: String(localized: "Invitation renewed and sent by email.")
            }
        }

        var notSentText: String {
            switch self {
            case .given: String(localized: "Access given, but the email wasn't sent.")
            case .renewed: String(localized: "Invitation renewed, but the email wasn't sent.")
            case .resent: String(localized: "The email wasn't sent: they already have valid sign-in links.")
            }
        }
    }

    /// L'email d'invito (`sent: false`: la persona ha già tre link validi, l'invito resta valido). Un 404 vuol dire
    /// che l'invito non è più aperto. Dopo aver dato l'accesso un errore qui è un avviso, non un errore.
    private func emailInvite(_ kind: InviteKind) async {
        guard let companyId else { return }
        do {
            let sent = try await backend.api.auth.sendMobileInviteLink(companyId: companyId, userId: userId)
            if sent {
                notices.removeAll { $0 == .emailNotSent }
                appInfo = kind.sentText
            } else {
                emailNotice = kind.notSentText
            }
        } catch AriaError.http(404, _) {
            actionError = String(localized: "The invitation is no longer open.")
        } catch AriaError.signedOut {
            await report(AriaError.signedOut)
        } catch {
            if kind == .resent {
                await report(error)
            } else {
                emailNotice = kind.notSentText
            }
        }
    }

    /// PATCH …/mobile-users/{id}: solo l'app (`active` o `suspended`); la web resta com'è.
    func setAppStatus(_ status: String) async {
        guard let companyId else { return }
        await attempt {
            _ = try await backend.api.call(
                AdminMobileUsersAPI.update(companyId: companyId, userId: userId, AdminMobileUserUpdate(status: status)))
        }
    }

    /// DELETE …/mobile-users/{id}: funziona anche con la persona sospesa in azienda.
    func revokeAppAccess() async {
        guard let companyId else { return }
        await attempt {
            _ = try await backend.api.call(AdminMobileUsersAPI.remove(companyId: companyId, userId: userId))
        }
    }

    // MARK: - Dispositivi

    /// Solo con l'app attiva o sospesa.
    var showsDevices: Bool {
        guard let state = appState else { return false }
        switch state {
        case .active, .appSuspended: return true
        default: return false
        }
    }

    func loadSessionsIfNeeded() async {
        guard showsDevices else {
            sessions = []
            hasLoadedSessions = false
            sessionsMessage = nil
            return
        }
        await loadSessions()
    }

    /// Un 404 vale "nessun dispositivo"; `sessions_shared` si spiega, non è un guasto.
    func loadSessions() async {
        guard let companyId else { return }
        do {
            let rows = try await backend.api.call(AdminMobileUsersAPI.sessions(companyId: companyId, userId: userId))
            sessions = rows.items.sorted { ($0.lastActiveAt ?? .distantPast) > ($1.lastActiveAt ?? .distantPast) }
            hasLoadedSessions = true
            sessionsMessage = nil
        } catch AriaError.http(404, _) {
            sessions = []
            hasLoadedSessions = true
            sessionsMessage = nil
        } catch {
            guard let failure = AdminMembersFailure.from(error, action: .read, backend: backend) else { return }
            if failure.refusal == .sessionsShared { sessions = [] }
            hasLoadedSessions = true
            sessionsMessage = failure.message
        }
    }

    /// "Active 3 minutes ago · Signed in 12 Oct".
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

    func askToLogOutAll() { pendingConfirmation = .logoutAll }

    func askToLogOut(_ session: AdminMobileUserSession) { pendingConfirmation = .logoutDevice(session) }

    func logOutAll() async {
        guard let companyId else { return }
        await exclusive {
            do {
                _ = try await backend.api.call(AdminMobileUsersAPI.revokeAllSessions(companyId: companyId, userId: userId))
                sessions = []
            } catch AriaError.http(404, _) {
                await loadSessions()
            } catch {
                await report(error)
            }
        }
    }

    func logOut(_ session: AdminMobileUserSession) async {
        guard let companyId else { return }
        await exclusive {
            do {
                _ = try await backend.api.call(
                    AdminMobileUsersAPI.revokeSession(companyId: companyId, userId: userId, sessionId: session.id))
                sessions.removeAll { $0.id == session.id }
            } catch AriaError.http(404, _) {
                // Già uscito sul server: si rilegge l'elenco e basta.
                await loadSessions()
            } catch {
                await report(error)
            }
        }
    }
}
