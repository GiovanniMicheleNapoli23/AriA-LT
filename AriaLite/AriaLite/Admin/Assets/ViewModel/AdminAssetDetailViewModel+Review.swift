//
//  AdminAssetDetailViewModel+Review.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La revisione dell'asset dal dettaglio, in ogni stato: Approve, Unapprove, Reject, Back to draft (quelle che
//  il ruolo permette, AriaRights.canMove). Ognuna è un PATCH del solo `status` (PATCH /v1/assets/{asset_id}).
//

import SwiftUI

extension AdminAssetDetailViewModel {
    private var storedStatus: String { asset.status ?? "draft" }

    var reviewStage: AdminReviewStage { AdminReviewStage(stored: storedStatus) }

    /// Le decisioni possibili ora (restano mentre una è in corso, ferme): nessuna senza id del server, né mentre
    /// l'eliminazione è in corso.
    var reviewActions: [AdminReviewAction] {
        guard canEdit, !isDeletingAsset else { return [] }
        return AdminReviewAction.available(from: storedStatus, in: .assets, rights: backend.rights)
    }

    var reviewMessage: LocalizedStringKey {
        switch reviewStage {
        case .pending: "Approve this asset to add it to your site's asset list."
        case .approved: "In use. Unapprove sends it back to draft; Reject takes it out of use."
        case .rejected: "Not in use. Back to draft reopens it for review; Approve puts it back in use."
        }
    }

    /// Il riquadro di revisione: almeno una decisione, o una in corso.
    var showsReview: Bool { !reviewActions.isEmpty || reviewing != nil }

    /// Reject e Unapprove chiedono conferma; le altre partono subito.
    func requestReview(_ action: AdminReviewAction) {
        if action.needsConfirmation {
            confirmingReview = action
        } else {
            Task { await review(action) }
        }
    }

    func review(_ action: AdminReviewAction) async {
        guard reviewing == nil, reviewActions.contains(action), let id = asset.serverId else { return }
        reviewing = action
        reviewError = nil
        defer { reviewing = nil }
        var changes = AdminPatchBody()
        changes.value("status", .string(action.target), was: .null)
        do {
            assetSaved(try await backend.api.call(AdminAssetsAPI.update(assetId: id, changes)))
        } catch {
            reviewError = AdminAssetsFailure.message(for: error, backend: backend)
        }
    }
}
