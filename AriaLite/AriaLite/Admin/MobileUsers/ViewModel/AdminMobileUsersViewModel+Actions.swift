//
//  AdminMobileUsersViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni su un operatore: rimandare l'invito, sospendere e riattivare, cambiare le specialità, toglierlo.
//  Le usano sia la lista (menu della riga) sia il dettaglio: la riga aggiornata vale per entrambi.
//  Sospendere e togliere passano dalla conferma.
//

import Foundation

extension AdminMobileUsersViewModel {
    /// Per gli `.alert`: chiuderli azzera lo stato.
    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    var showsActionNotice: Bool {
        get { actionNotice != nil }
        set { if !newValue { actionNotice = nil } }
    }

    var showsConfirmation: Bool {
        get { pendingConfirmation != nil }
        set { if !newValue { pendingConfirmation = nil } }
    }

    func canResend(_ user: AdminMobileUser) -> Bool { user.knownStatus?.canResend ?? false }
    func canSuspend(_ user: AdminMobileUser) -> Bool { user.knownStatus?.canSuspend ?? false }
    func canReactivate(_ user: AdminMobileUser) -> Bool { user.knownStatus?.canReactivate ?? false }
    /// Un operatore già revocato non ha altro da fare.
    func canRemove(_ user: AdminMobileUser) -> Bool { user.knownStatus != .revoked }
    func canEditSpecialties(_ user: AdminMobileUser) -> Bool { user.knownStatus != .revoked }

    func askToSuspend(_ user: AdminMobileUser) { pendingConfirmation = .suspend(user) }
    func askToRemove(_ user: AdminMobileUser) { pendingConfirmation = .remove(user) }

    /// Il pulsante del dialogo (sospendi o togli; le uscite dai telefoni le gestisce il dettaglio).
    func confirm(_ confirmation: AdminMobileUserConfirmation) async {
        pendingConfirmation = nil
        switch confirmation {
        case .suspend(let user): await setStatus(user, to: "suspended")
        case .remove(let user): await remove(user)
        case .logoutAll, .logoutDevice: break
        }
    }

    func reactivate(_ user: AdminMobileUser) async {
        await setStatus(user, to: "active")
    }

    /// Rimanda il link di accesso a chi non è ancora entrato.
    func resend(_ user: AdminMobileUser) async {
        guard let companyId = backend.activeCompanyId, !isBusy(user) else { return }
        busyUserIds.insert(user.id)
        defer { busyUserIds.remove(user.id) }
        do {
            apply(try await backend.api.call(AdminMobileUsersAPI.resend(companyId: companyId, userId: user.id)))
            actionNotice = String(localized: "A new sign-in link was sent to \(user.email).")
        } catch {
            actionError = AdminMobileUserFailure.message(for: error, backend: backend)
        }
    }

    /// Salva le specialità (la lista intera). Dice se è andata, per chiudere il foglio.
    func saveSpecialties(_ user: AdminMobileUser, _ specialties: [String]) async -> Bool {
        guard let companyId = backend.activeCompanyId, !isBusy(user) else { return false }
        busyUserIds.insert(user.id)
        defer { busyUserIds.remove(user.id) }
        do {
            let body = AdminMobileUserUpdate(specialties: specialties)
            apply(try await backend.api.call(AdminMobileUsersAPI.update(companyId: companyId, userId: user.id, body)))
            return true
        } catch {
            actionError = AdminMobileUserFailure.message(for: error, backend: backend)
            return false
        }
    }

    private func setStatus(_ user: AdminMobileUser, to status: String) async {
        guard let companyId = backend.activeCompanyId, !isBusy(user) else { return }
        busyUserIds.insert(user.id)
        defer { busyUserIds.remove(user.id) }
        do {
            let body = AdminMobileUserUpdate(status: status)
            apply(try await backend.api.call(AdminMobileUsersAPI.update(companyId: companyId, userId: user.id, body)))
        } catch {
            actionError = AdminMobileUserFailure.message(for: error, backend: backend)
        }
    }

    private func remove(_ user: AdminMobileUser) async {
        guard let companyId = backend.activeCompanyId, !isBusy(user) else { return }
        busyUserIds.insert(user.id)
        defer { busyUserIds.remove(user.id) }
        do {
            _ = try await backend.api.call(AdminMobileUsersAPI.remove(companyId: companyId, userId: user.id))
            removeLocally(id: user.id)
            await load()
        } catch {
            // Già tolto sul server: per l'elenco è come averlo tolto.
            if case .http(let status, _)? = error as? AriaError, status == 404 {
                removeLocally(id: user.id)
            } else {
                actionError = AdminMobileUserFailure.message(for: error, backend: backend)
            }
        }
    }
}
