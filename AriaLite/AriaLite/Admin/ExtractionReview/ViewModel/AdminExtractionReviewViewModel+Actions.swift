//
//  AdminExtractionReviewViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Selezione multipla, approvazione in blocco e decisione su un singolo elemento (approva / rifiuta).
//  Il singolo è ottimista: esce subito dalla lista e torna al suo posto se il server dice di no.
//

import Foundation

extension AdminExtractionReviewViewModel {
    // MARK: Selezione

    var selectableItems: [AdminExtractionItem] { visibleItems.filter { $0.canEdit && !isBusy($0) } }

    var allSelected: Bool { !selectableItems.isEmpty && selectableItems.allSatisfy { selection.contains($0.id) } }

    var canApproveSelection: Bool { !selection.isEmpty && !isBulkApproving }

    func isSelected(_ item: AdminExtractionItem) -> Bool { selection.contains(item.id) }

    func toggleSelection(_ item: AdminExtractionItem) {
        guard item.canEdit else { return }
        if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
    }

    func toggleSelectAll() {
        selection = allSelected ? [] : Set(selectableItems.map(\.id))
    }

    func beginSelection() {
        selection = []
        isSelecting = true
    }

    func endSelection() {
        isSelecting = false
        selection = []
    }

    // MARK: Approvazione in blocco

    /// Asset e allarmi con POST bulk-approve (se il server non accetta il body, una PATCH per elemento);
    /// piani e ricambi con una PATCH per elemento. Non ottimista: la risposta non dice cosa è passato.
    func approveSelection() async {
        let kind = kind
        let chosen = pendingItems(kind).filter { selection.contains($0.id) && $0.serverId != nil }
        guard !chosen.isEmpty, !isBulkApproving else { return }
        isBulkApproving = true
        busyIds.formUnion(chosen.map(\.id))
        defer {
            isBulkApproving = false
            busyIds.subtract(chosen.map(\.id))
        }

        var approved: Set<String> = []
        var failure: (any Error)?
        if kind.hasBulkApprove {
            do {
                try await client.bulkApprove(kind, ids: chosen.compactMap(\.serverId))
                approved = Set(chosen.map(\.id))
            } catch where AdminExtractionReviewFailure.isUnsupported(error) {
                (approved, failure) = await approveOneByOne(chosen)
            } catch {
                failure = error
            }
        } else {
            (approved, failure) = await approveOneByOne(chosen)
        }

        remove(approved, kind: kind)
        if approved.count == chosen.count { endSelection() }
        if let failure, let message = AdminExtractionReviewFailure.message(for: failure, backend: backend) {
            let missed = chosen.count - approved.count
            actionError = approved.isEmpty ? message : String(localized: "\(missed) items weren't approved: \(message)")
        }
    }

    /// PATCH `status: approved` in parallelo: gli id approvati e il primo errore.
    private func approveOneByOne(_ chosen: [AdminExtractionItem]) async -> (Set<String>, (any Error)?) {
        let client = client
        return await withTaskGroup(of: (String, (any Error)?).self) { group in
            for item in chosen {
                group.addTask {
                    do {
                        _ = try await client.setStatus(item, AdminExtractionStatus.approved)
                        return (item.id, nil)
                    } catch {
                        return (item.id, error)
                    }
                }
            }
            var approved: Set<String> = []
            var firstError: (any Error)?
            for await (id, error) in group {
                if let error { firstError = firstError ?? error } else { approved.insert(id) }
            }
            return (approved, firstError)
        }
    }

    // MARK: Singolo

    /// Approva o rifiuta un elemento: esce subito dalla lista, torna se il server rifiuta.
    /// `true` se è andata (il dettaglio allora si chiude).
    @discardableResult
    func decide(_ item: AdminExtractionItem, status: String) async -> Bool {
        guard item.canEdit, !isBusy(item) else { return false }
        let kind = item.kind
        let previous = items[kind] ?? []
        busyIds.insert(item.id)
        defer { busyIds.remove(item.id) }
        remove([item.id], kind: kind)
        do {
            let saved = try await client.setStatus(item, status)
            // Il server può lasciarlo pending (stato non cambiato): allora resta in lista.
            if saved.isPending { apply(saved) }
            return true
        } catch {
            items[kind] = previous
            if let message = AdminExtractionReviewFailure.message(for: error, backend: backend) { actionError = message }
            return false
        }
    }

    func approve(_ item: AdminExtractionItem) async { await decide(item, status: AdminExtractionStatus.approved) }
    func reject(_ item: AdminExtractionItem) async { await decide(item, status: AdminExtractionStatus.rejected) }

    func makeDetailViewModel(for item: AdminExtractionItem) -> AdminExtractionDetailViewModel {
        AdminExtractionDetailViewModel(
            backend: backend, item: item,
            onSaved: { [weak self] in self?.apply($0) },
            onDecision: { [weak self] item, status in await self?.decide(item, status: status) ?? false }
        )
    }
}
