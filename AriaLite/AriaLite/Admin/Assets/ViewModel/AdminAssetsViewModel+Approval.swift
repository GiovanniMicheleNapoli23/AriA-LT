//
//  AdminAssetsViewModel+Approval.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Selezione multipla delle bozze e approvazione in blocco (POST /v1/assets/bulk-approve). Si chiede sempre
//  conferma; a fine chiamata la lista si rilegge e si dice quante ne sono passate.
//

import Foundation

extension AdminAssetsViewModel {
    /// Lo stato mostrato ha bozze da approvare, e il ruolo può approvare.
    var canSelect: Bool {
        statusFilter.isPending && !assets.isEmpty && backend.rights.can(.approve, in: .assets)
    }

    func startSelecting() {
        selection = []
        isSelecting = true
    }

    func endSelecting() {
        isSelecting = false
        selection = []
    }

    func toggle(_ asset: AdminAsset) {
        if selection.contains(asset.id) { selection.remove(asset.id) } else { selection.insert(asset.id) }
    }

    /// Tutte le righe visibili sono scelte.
    var allVisibleSelected: Bool {
        let ids = Set(visibleAssets.map(\.id))
        return !ids.isEmpty && ids.isSubset(of: selection)
    }

    func toggleSelectAll() {
        if allVisibleSelected {
            selection.subtract(visibleAssets.map(\.id))
        } else {
            selection.formUnion(visibleAssets.map(\.id))
        }
    }

    /// Gli id del server delle righe scelte e ancora nell'elenco (senza id l'asset non si approva).
    private var selectedIds: [String] {
        assets.filter { selection.contains($0.id) }.compactMap(\.serverId)
    }

    var selectedCount: Int { selectedIds.count }

    var approveConfirmationTitle: String {
        String(localized: "Approve the selected assets?")
    }

    var approveConfirmationMessage: String {
        String(localized: "Selected: \(selectedCount). Approved assets become part of your site's asset list.")
    }

    var isShowingApproveError: Bool {
        get { approveError != nil }
        set { if !newValue { approveError = nil } }
    }

    func approveSelected() async {
        let ids = selectedIds
        guard !ids.isEmpty, !isApproving, backend.rights.can(.approve, in: .assets) else { return }
        isApproving = true
        approveError = nil
        defer { isApproving = false }
        let result: AdminAssetBulkApproveResult
        do {
            result = try await backend.api.call(AdminAssetsAPI.bulkApprove(ids: ids))
        } catch {
            approveError = AdminAssetsFailure.message(for: error, backend: backend)
            return
        }
        // Gli id non trovati il server li salta: si dice quanti sono passati davvero.
        let approved = result.approved ?? ids.count
        endSelecting()
        await load()
        notice = String(localized: "Assets approved: \(approved)")
    }
}
