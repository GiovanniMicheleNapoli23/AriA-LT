//
//  AdminMobileUserDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un operatore: info, specialità, telefoni su cui è entrato e ordini di lavoro aperti.
//  L'operatore lo legge dalla lista, così sospendi, riattiva e specialità valgono subito per entrambe;
//  sospendere e togliere sono le azioni della lista. Le uscite dai telefoni sono di questo view model.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMobileUserDetailViewModel {
    let list: AdminMobileUsersViewModel
    let userId: String

    var sessions: [AdminMobileUserSession] = []
    private(set) var isLoadingSessions = false
    private(set) var sessionsLoaded = false
    private(set) var sessionsError: String?

    private(set) var workOrders: [AdminMobileUserWorkOrder] = []
    private(set) var isLoadingWorkOrders = false
    private(set) var workOrdersLoaded = false
    private(set) var workOrdersError: String?

    var pendingConfirmation: AdminMobileUserConfirmation?
    /// Il foglio delle specialità, aperto quando c'è.
    var specialtiesForm: AdminMobileUserSpecialtiesViewModel?
    var actionError: String?
    var isRevoking = false

    init(list: AdminMobileUsersViewModel, userId: String) {
        self.list = list
        self.userId = userId
    }

    /// `nil` dopo la rimozione: la vista torna indietro.
    var user: AdminMobileUser? { list.user(id: userId) }

    var showsConfirmation: Bool {
        get { pendingConfirmation != nil }
        set { if !newValue { pendingConfirmation = nil } }
    }

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    // MARK: Info

    func infoFields(of user: AdminMobileUser) -> [AdminAssetField] {
        var rows = [AdminAssetField(title: String(localized: "Email"), value: user.email)]
        if user.knownStatus == .active {
            let since = user.availabilityAt.map { " · " + $0.formatted(.relative(presentation: .named)) } ?? ""
            rows.append(AdminAssetField(title: String(localized: "Availability"),
                                        value: AdminMobileUserAvailability.label(for: user.availability) + since))
        }
        if let added = user.addedAt {
            rows.append(AdminAssetField(title: String(localized: "Added"),
                                        value: added.formatted(date: .abbreviated, time: .omitted)))
        }
        if let invited = invitationLine(of: user) {
            rows.append(AdminAssetField(title: String(localized: "Invitation"), value: invited))
        }
        return rows
    }

    /// "Valid until 24 Oct" per chi è invitato, "Expired on 20 Oct" per chi non ha risposto in tempo.
    func invitationLine(of user: AdminMobileUser) -> String? {
        guard user.knownStatus?.canResend == true, let until = user.invitedUntil else { return nil }
        let day = until.formatted(date: .abbreviated, time: .shortened)
        if user.knownStatus == .expired { return String(localized: "Expired on \(day)") }
        return String(localized: "Valid until \(day)")
    }

    func workLoadText(of user: AdminMobileUser) -> String {
        list.workLoadText(of: user)
    }

    // MARK: Caricamento

    /// Telefoni e ordini aperti insieme; chi non è ancora entrato non ha telefoni.
    func load() async {
        async let sessionsLoad: Void = loadSessions()
        async let ordersLoad: Void = loadWorkOrders()
        _ = await (sessionsLoad, ordersLoad)
    }

    func loadSessions() async {
        guard let companyId = list.backend.activeCompanyId else { return }
        guard user?.knownStatus?.hasSessions ?? true else {
            sessions = []
            sessionsLoaded = true
            sessionsError = nil
            return
        }
        isLoadingSessions = true
        defer { isLoadingSessions = false }
        do {
            let rows = try await list.backend.api.call(
                AdminMobileUsersAPI.sessions(companyId: companyId, userId: userId))
            sessions = rows.items.sorted { ($0.lastActiveAt ?? .distantPast) > ($1.lastActiveAt ?? .distantPast) }
            sessionsLoaded = true
            sessionsError = nil
        } catch {
            if let message = AdminMobileUserFailure.message(for: error, backend: list.backend) {
                sessionsError = message
            }
        }
    }

    func loadWorkOrders() async {
        isLoadingWorkOrders = true
        defer { isLoadingWorkOrders = false }
        do {
            let rows = try await list.backend.api.call(AdminMobileUsersAPI.openWorkOrders(userId: userId))
            workOrders = rows.items
            workOrdersLoaded = true
            workOrdersError = nil
        } catch {
            if let message = AdminMobileUserFailure.message(for: error, backend: list.backend) {
                workOrdersError = message
            }
        }
    }

    func startEditingSpecialties(of user: AdminMobileUser) {
        specialtiesForm = AdminMobileUserSpecialtiesViewModel(list: list, user: user)
    }

    func makeStepReportsViewModel(for order: AdminMobileUserWorkOrder) -> AdminMobileUserStepReportsViewModel {
        AdminMobileUserStepReportsViewModel(backend: list.backend, order: order)
    }
}
