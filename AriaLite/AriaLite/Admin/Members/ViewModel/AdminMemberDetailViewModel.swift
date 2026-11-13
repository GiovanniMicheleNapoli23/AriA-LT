//
//  AdminMemberDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di una persona (GET /v1/members/{id}): stato e caricamento, i turni dei prossimi giorni e gli avvisi
//  della creazione. "In azienda" è in +Company, "Lavoro" in +Work, "Accesso all'app" in +AppAccess. Le regole su chi
//  può fare cosa stanno in AdminMemberRules.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemberDetailViewModel {
    let owner: AdminMembersViewModel
    let userId: String
    var backend: AriaBackend { owner.backend }

    /// Quanti giorni avanti si guardano i turni.
    static let horizonDays = 60

    // MARK: - Stato
    // Le proprietà che le estensioni scrivono non sono `private(set)`: Swift non lo permette fra file.

    /// La persona come l'ha mandata l'ultima GET; prima, quella dell'elenco del proprietario.
    var loaded: AdminMember?
    /// La persona non c'è più (404 vero): la vista torna indietro.
    var isGone = false
    private(set) var isLoading = false
    private(set) var failure: AdminMembersFailure?

    /// Gli avvisi della creazione (si leggono una volta sola, nel primo `load`).
    var notices: [AdminMemberCreationNotice] = []
    private var hasTakenNotices = false
    /// L'esito dell'ultima email d'invito: "L'email non è partita" (avviso) o "Invito mandato" (informazione).
    var emailNotice: String?
    var appInfo: String?

    var shifts: [AdminMemberShift] = []
    private(set) var hasLoadedShifts = false
    private(set) var shiftsFailure: AdminMembersFailure?
    private(set) var isRemoving = false

    /// Il modulo di assegnazione aperto (sheet).
    var assignForm: AdminMemberAssignShiftViewModel?
    /// Il foglio con nome, qualifica e specialità.
    var profileForm: AdminMemberProfileFormViewModel?
    /// "Togliere questo turno?" (conferma): il turno in questione.
    var shiftToRemove: AdminMemberShift?
    /// La conferma aperta di un'azione della scheda.
    var pendingConfirmation: AdminMemberConfirmation?
    /// Un'azione sulla persona è in corso: gli altri pulsanti aspettano.
    var isWorking = false
    /// Errore di una modifica (alert).
    var actionError: String?

    /// I ruoli di Roles & Rights, solo per chi può darli.
    var roles: [AdminRole] = []
    var hasLoadedRoles = false

    /// Gli ordini aperti assegnati alla persona, per chi ha la sezione Work Orders.
    var orders: [AdminMobileUserWorkOrder] = []
    var hasLoadedOrders = false
    var ordersError: String?

    /// I dispositivi, solo con l'app attiva o sospesa.
    var sessions: [AdminMobileUserSession] = []
    var hasLoadedSessions = false
    var sessionsMessage: String?

    init(userId: String, owner: AdminMembersViewModel) {
        self.userId = userId
        self.owner = owner
    }

    // MARK: - Chi

    var viewer: AdminPeopleViewer { owner.viewer }

    /// Quella dell'ultima GET; finché non arriva, quella dell'elenco.
    var member: AdminMember? { loaded ?? owner.members.first { $0.id == userId } }

    /// Un record senza membership (`access: null`): la scheda è solo da guardare.
    var isReadOnly: Bool { member?.access == nil }

    var companyId: String? { backend.activeCompanyId }

    // MARK: - Caricamento

    func load() async {
        if !hasTakenNotices {
            hasTakenNotices = true
            notices = owner.takeCreationNotices(for: userId)
        }
        isLoading = true
        defer { isLoading = false }
        // L'elenco serve per le licenze, la riga mobile e i titolari: se non c'è ancora, si carica con la persona.
        async let list: Void = owner.loadIfNeeded()
        async let fresh: Void = reloadMember()
        _ = await (list, fresh)
        guard !isGone else { return }
        async let upcoming: Void = reloadShifts()
        async let roleList: Void = loadRolesIfNeeded()
        async let openOrders: Void = loadOrders()
        async let devices: Void = loadSessionsIfNeeded()
        _ = await (upcoming, roleList, openOrders, devices)
    }

    /// Dopo un'azione riuscita: l'elenco e la lista mobile (licenze e righe), poi la persona, gli ordini e i dispositivi.
    func reloadAfterAction() async {
        await owner.refresh()
        await reloadMember()
        guard !isGone else { return }
        async let openOrders: Void = loadOrders()
        async let devices: Void = loadSessionsIfNeeded()
        _ = await (openOrders, devices)
    }

    func reloadMember() async {
        do {
            let fresh = try await AdminMembersAPI(api: backend.api).member(id: userId)
            loaded = fresh
            owner.didRefresh(fresh)
            failure = nil
        } catch {
            guard let failure = AdminMembersFailure.from(error, action: .read, backend: backend) else { return }
            if failure.isNotFound {
                await didDisappear()
            } else {
                self.failure = failure
            }
        }
    }

    /// La persona non c'è più: si ricarica l'elenco e la vista torna indietro.
    func didDisappear() async {
        await owner.refresh()
        isGone = true
    }

    func reloadShifts() async {
        let window = AdminMemberDay.window(days: Self.horizonDays)
        do {
            let fresh = try await AdminMembersAPI(api: backend.api)
                .shifts(userId: userId, from: window.from, to: window.to)
            shifts = fresh.sorted { ($0.shiftDate, $0.shiftType) < ($1.shiftDate, $1.shiftType) }
            hasLoadedShifts = true
            shiftsFailure = nil
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .read, backend: backend) {
                shiftsFailure = failure
            }
        }
    }

    // MARK: - Presentazione

    var workload: AdminMemberWorkload { member?.workload ?? AdminMemberWorkload() }

    /// "Next 60 days": il titolo dell'elenco dei turni.
    var horizonText: String { String(localized: "Next \(Self.horizonDays) days") }

    var title: String { member?.displayName ?? "" }

    /// La riga sotto il nome: "Owner", "Admin", il ruolo o "Needs a role".
    var roleLine: String? {
        member.flatMap { owner.roleLine(for: $0) }
    }

    /// Senza ruolo la riga si legge in grigio.
    var roleLineIsMuted: Bool {
        member.map { !$0.isOwnerOrAdmin && $0.accessRole == nil } ?? false
    }

    var badge: AdminMemberBadgeKind? {
        member.flatMap { AdminMemberRules.badge($0, row: owner.mobileRow(for: userId)) }
    }

    // MARK: - Avvisi

    /// Le righe di avviso in cima: quelle della creazione, poi l'esito dell'email.
    var noticeLines: [String] {
        var lines = notices.map(Self.text(for:))
        if let emailNotice { lines.append(emailNotice) }
        return lines
    }

    static func text(for notice: AdminMemberCreationNotice) -> String {
        switch notice {
        case .alreadyOwnerOrAdmin: String(localized: "They were already in the company as an owner or admin.")
        case .noRoleChooseOne: String(localized: "No role: choose one.")
        case .roleUnchanged: String(localized: "They were already in the company: their role was not changed.")
        case .appSkippedOwnerOrAdmin: String(localized: "They already enter the app as an owner or admin.")
        case .appSkippedSuspended: String(localized: "Suspended in the company: app access not given.")
        case .appNotGiven(let reason): String(localized: "Created, but without app access: \(reason)")
        case .emailNotSent: String(localized: "Access given, but the email wasn't sent.")
        }
    }

    // MARK: - Turni

    /// Un turno assegnato: si rileggono turni e scheda (il team di oggi può essere cambiato).
    func didAssign() async {
        await reloadShifts()
        await reloadAfterAction()
    }

    func confirmRemoval(of shift: AdminMemberShift) {
        guard canAssignShifts else { return }
        shiftToRemove = shift
    }

    var isConfirmingRemoval: Bool {
        get { shiftToRemove != nil }
        set { if !newValue { shiftToRemove = nil } }
    }

    var isShowingActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    /// Il testo della conferma, con giorno e team del turno.
    func removalMessage(for shift: AdminMemberShift) -> String {
        String(localized: "\(title) will no longer be on \(shift.teamTitle) on \(shift.dateText).")
    }

    /// Toglie il turno, dopo la conferma. Un 404 vuol dire che non c'era già più.
    func remove(_ shift: AdminMemberShift) async {
        guard !isRemoving, canAssignShifts else { return }
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await AdminMembersAPI(api: backend.api).removeAssignment(id: shift.id)
        } catch {
            guard let failure = AdminMembersFailure.from(error, action: .write, backend: backend) else { return }
            guard failure.isNotFound else {
                await absorb(failure)
                return
            }
        }
        shifts.removeAll { $0.id == shift.id }
        await reloadAfterAction()
    }
}
