//
//  AdminAlarmsViewModel+Approval.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Selezione multipla delle bozze e approvazione in blocco (POST /v1/alarms/bulk-approve, che sincronizza
//  anche la conoscenza). Si chiede sempre conferma.
//

import Foundation

extension AdminAlarmsViewModel {
    /// Lo stato mostrato ha bozze da approvare.
    var canSelect: Bool { statusFilter.isPending && !alarms.isEmpty }

    func startSelecting() {
        selection = []
        isSelecting = true
    }

    func endSelecting() {
        isSelecting = false
        selection = []
    }

    func toggle(_ alarm: AdminAlarm) {
        if selection.contains(alarm.id) { selection.remove(alarm.id) } else { selection.insert(alarm.id) }
    }

    /// Tutte le righe visibili sono scelte.
    var allVisibleSelected: Bool {
        let ids = Set(visibleAlarms.map(\.id))
        return !ids.isEmpty && ids.isSubset(of: selection)
    }

    func toggleSelectAll() {
        if allVisibleSelected {
            selection.subtract(visibleAlarms.map(\.id))
        } else {
            selection.formUnion(visibleAlarms.map(\.id))
        }
    }

    /// Solo gli id ancora nell'elenco (uno rimosso nel frattempo non si manda).
    private var selectedIds: [String] {
        alarms.map(\.id).filter(selection.contains)
    }

    var selectedCount: Int { selectedIds.count }

    var approveConfirmationTitle: String {
        String(localized: "Approve the selected alarms?")
    }

    var approveConfirmationMessage: String {
        String(localized: """
            Selected: \(selectedCount). Approved alarms are added to the knowledge base the assistant draws on.
            """)
    }

    var isShowingApproveError: Bool {
        get { approveError != nil }
        set { if !newValue { approveError = nil } }
    }

    func approveSelected() async {
        let ids = selectedIds
        guard !ids.isEmpty, !isApproving else { return }
        isApproving = true
        approveError = nil
        defer { isApproving = false }
        do {
            try await AdminAlarmsAPI(api: backend.api).approve(ids: ids)
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend) {
                approveError = failure.message
            }
            return
        }
        // Le approvate escono dall'elenco delle bozze; quello degli approvati è da rileggere.
        let approved = Set(ids)
        alarmsByStatus[statusFilter]?.removeAll { approved.contains($0.id) }
        alarmsByStatus[.approved] = nil
        notice = String(localized: "Alarms approved: \(ids.count)")
        endSelecting()
    }
}

extension AdminAlarmsViewModel {
    /// Un allarme è stato approvato altrove (dal dettaglio): l'elenco degli approvati è da rileggere.
    func invalidateApproved() {
        alarmsByStatus[.approved] = nil
    }
}
