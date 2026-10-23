//
//  AdminReportsViewModel+Widgets.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I widget salvati nella pagina Reports: l'apertura (riusa il dettaglio di Crafted, che li riesegue per i
//  dati di oggi) e l'eliminazione con conferma.
//

import Foundation

extension AdminReportsViewModel {
    var visibleWidgets: [AdminCraftedWidget] {
        (widgets.value ?? []).sorted {
            ($0.position ?? .max, $0.displayTitle.lowercased()) < ($1.position ?? .max, $1.displayTitle.lowercased())
        }
    }

    func makeWidgetDetail(for widget: AdminCraftedWidget) -> AdminCraftedWidgetDetailViewModel {
        AdminCraftedWidgetDetailViewModel(backend: backend, widget: widget)
    }

    func canDelete(_ widget: AdminCraftedWidget) -> Bool { widget.serverId != nil && deletingId == nil }

    func askDelete(_ widget: AdminCraftedWidget) {
        guard canDelete(widget) else { return }
        widgetToDelete = widget
        showsDeleteConfirmation = true
    }

    /// Elimina dalla lista dei menu: se il server dice di no il widget resta e l'errore va nell'alert.
    func delete(_ widget: AdminCraftedWidget) async {
        guard let message = await deleteReturningError(widget) else { return }
        actionError = message
        showsActionError = true
    }

    /// Come `delete`, ma l'errore torna a chi chiama (il dettaglio lo mostra sul posto): nil = eliminato
    /// o richiesta annullata.
    func deleteReturningError(_ widget: AdminCraftedWidget) async -> String? {
        guard let id = widget.serverId else { return nil }
        deletingId = id
        defer { deletingId = nil; widgetToDelete = nil }
        do {
            _ = try await backend.api.call(AdminReportsAPI.deleteWidget(id: id))
            removeWidget(id: id)
            return nil
        } catch {
            return AdminCraftedFailure.message(for: error, backend: backend)
        }
    }
}
