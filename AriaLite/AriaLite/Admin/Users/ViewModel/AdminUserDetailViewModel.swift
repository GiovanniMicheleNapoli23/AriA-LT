//
//  AdminUserDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda di una persona (contratto Users §4, §5): la riga si legge sempre dall'elenco del titolare (mai una
//  copia vecchia), i dettagli (carico, specialità) da GET /v1/members/{id}, le sessioni da …/sessions. Ogni scrittura
//  passa da `write`: blocca la persona, manda, mostra l'avviso, rilegge l'elenco (regola 5) e dice i rifiuti (§8).
//  Il livello sta in +Level, gli interruttori in +Switches, le sessioni in +Sessions, lo stato in +Status.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminUserDetailViewModel {
    let userId: String
    let owner: AdminUsersViewModel
    /// Oggi, Schedule e History: li scrive un altro view model, che rilegge i dettagli da qui.
    @ObservationIgnored private(set) var shifts: AdminUserShiftsViewModel!

    // MARK: - Stato

    /// GET /v1/members/{id}: carico, specialità, team di oggi. Se la lettura fallisce manca e basta.
    private(set) var details: AdminMember?
    var sessions: [AdminUserSession] = []
    var sessionsLoaded = false
    var sessionsFailed = false
    /// Una scrittura di questa persona è in corso: interruttori e pulsanti di stato spenti.
    private(set) var isWorking = false
    var isSendingEmail = false

    /// La conferma aperta sulla scheda.
    var confirmation: AdminUserConfirmation?
    /// Le conferme e il foglio del livello, aperti sulla pagina del livello.
    var levelConfirmation: AdminUserLevelConfirmation?
    var demotion: AdminUserDemotion?
    var demotionRoleId: String?
    /// La conferma da aprire quando il foglio di scelta del ruolo si è chiuso.
    @ObservationIgnored var afterDemotion: AdminUserLevelConfirmation?
    /// Sale quando la pagina del livello deve chiudersi (livello cambiato o scelto lo stesso).
    var levelPageCloses = 0

    /// Le specialità scelte nella pagina di modifica; `specialtyPageCloses` sale quando sono state salvate.
    var specialtyDraft: Set<String> = []
    var specialtyPageCloses = 0
    /// Il foglio "Assign a work order".
    var assignment: AdminUserAssignWorkOrderViewModel?

    init(userId: String, owner: AdminUsersViewModel) {
        self.userId = userId
        self.owner = owner
        shifts = AdminUserShiftsViewModel(userId: userId, owner: owner,
                                          reloadDetails: { @MainActor [weak self] in await self?.loadDetails() })
    }

    // MARK: - Dalla riga

    /// Sempre la riga dell'elenco del titolare.
    var row: AdminUserRow? { owner.row(for: userId) }

    /// La riga è sparita da un elenco già letto: la scheda si chiude.
    var isGone: Bool { owner.hasLoaded && row == nil }

    var viewer: AdminUsersViewer { owner.viewer }

    /// Chi guarda non apre la sezione Users (§2): la scheda non ha una riga da leggere.
    var cannotOpen: Bool { owner.entry == .hidden }

    var name: String { row?.displayName ?? "" }

    var isSelf: Bool { row.map { viewer.isSelf($0) } ?? false }

    /// Cosa mostra la scheda a chi guarda (§5, §7).
    var controls: AdminUsersRules.AccessControls {
        row.map { AdminUsersRules.accessControls(for: $0, viewer: viewer) } ?? AdminUsersRules.AccessControls()
    }

    var showsSchedule: Bool { AdminUsersRules.showsSchedule(viewer) }

    // MARK: - Caricamento

    /// All'apertura e col trascinamento: l'elenco se manca, i dettagli, le sessioni e i turni.
    func load() async {
        if !owner.hasLoaded { await owner.loadIfNeeded() }
        async let readDetails: Void = loadDetails()
        async let readSessions: Void = loadSessions()
        async let readShifts: Void = shifts.load()
        _ = await (readDetails, readSessions, readShifts)
    }

    func loadDetails() async {
        do {
            details = try await AdminMembersAPI(api: owner.backend.api).member(id: userId)
        } catch {
            // Senza dettagli manca solo il carico: si dice altro solo se la sessione è finita.
            if let failure = AdminUsersFailure.from(error, backend: owner.backend) { await owner.absorb(failure) }
        }
    }

    // MARK: - Scrivere

    /// Una scrittura di questa persona: la blocca, la manda, mostra l'avviso e rilegge l'elenco (anche dopo un
    /// rifiuto: i conti sono cambiati sotto i piedi, §8). `true` se è andata.
    @discardableResult
    func write(rolesChanged: Bool = false, _ work: () async throws -> String?) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        let touchedSelf = isSelf
        do {
            let message = try await work()
            if let message { owner.show(message) }
            await owner.afterWrite(touchedSelf: touchedSelf, rolesChanged: rolesChanged)
            return true
        } catch {
            guard let failure = AdminUsersFailure.from(error, backend: owner.backend) else { return false }
            owner.show(failure.message, isError: true)
            await owner.absorb(failure)
            if !failure.sessionEnded { await owner.afterWrite(rolesChanged: rolesChanged) }
            return false
        }
    }
}
