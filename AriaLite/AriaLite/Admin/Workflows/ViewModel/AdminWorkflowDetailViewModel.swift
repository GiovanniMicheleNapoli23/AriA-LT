//
//  AdminWorkflowDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un flusso: intestazione, grafo letto come lista di passi, esito del controllo. Tiene
//  il flusso più fresco (lo rilegge all'apertura: serve la `revision` giusta per ogni azione) e avvisa la
//  lista dei cambiamenti. Azioni in +Actions, versioni in +Versions.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkflowDetailViewModel {
    let list: AdminWorkflowsViewModel
    let flowId: String

    /// `nil` dopo l'eliminazione (o se il server dice che non esiste più).
    var flow: AdminWorkflow?
    var isRefreshing = false

    // MARK: Fogli

    /// Il modulo di modifica aperto (sheet).
    var editForm: AdminWorkflowFormViewModel?
    var showsVersions = false

    // MARK: Controllo

    var validation: AdminWorkflowValidation?
    var isValidating = false

    // MARK: Azioni (vedi +Actions)

    var isBusy = false
    var actionError: String?
    var actionNotice: String?
    var pendingConfirmation: AdminWorkflowConfirmation?

    // MARK: Versioni (vedi +Versions)

    var versions: [AdminWorkflowVersion] = []
    var isLoadingVersions = false
    var versionsLoaded = false
    var versionsError: String?
    /// Il numero della versione appena ripristinata: lo si annuncia a foglio chiuso.
    var restoredVersion: Int?

    init(list: AdminWorkflowsViewModel, flowId: String) {
        self.list = list
        self.flowId = flowId
        flow = list.knownFlows[flowId]
    }

    var backend: AriaBackend { list.backend }

    // MARK: Lettura

    /// I passi del grafo nell'ordine del flusso, ognuno con le sue uscite.
    var steps: [AdminWorkflowStep] {
        guard let flow else { return [] }
        return AdminWorkflowOutline.steps(of: flow.graph, unavailableKinds: list.unavailableKinds)
    }

    /// Il nome di un nodo, per dare un volto agli id dei problemi del controllo.
    func nodeTitle(_ id: String?) -> String? {
        guard let id else { return nil }
        return steps.first { $0.id == id }?.title ?? id
    }

    struct Stat: Identifiable {
        let id: String
        let title: String
        let value: String
        let systemImage: String
    }

    var stats: [Stat] {
        guard let flow else { return [] }
        let published = flow.isPublished
            ? String(localized: "Version \(flow.definitionVersion)") : String(localized: "Never")
        return [
            Stat(id: "revision", title: String(localized: "Revision"), value: "\(flow.revision)",
                 systemImage: "number"),
            Stat(id: "published", title: String(localized: "Published"), value: published, systemImage: "paperplane"),
            Stat(id: "steps", title: String(localized: "Steps"), value: "\(flow.graph.nodes.count)",
                 systemImage: "square.stack.3d.up"),
            Stat(id: "links", title: String(localized: "Connections"), value: "\(flow.graph.edges.count)",
                 systemImage: "arrow.triangle.branch"),
        ]
    }

    /// "Updated 3 days ago · Created 2 weeks ago": la riga sotto il nome.
    var datesLine: String {
        guard let flow else { return "" }
        let relative = Date.RelativeFormatStyle(presentation: .named)
        var parts: [String] = []
        if let updated = flow.updatedAt { parts.append(String(localized: "Updated \(updated.formatted(relative))")) }
        if let created = flow.createdAt { parts.append(String(localized: "Created \(created.formatted(relative))")) }
        if let archived = flow.archivedAt {
            parts.append(String(localized: "Archived \(archived.formatted(relative))"))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Caricamento

    /// Rilegge il flusso: serve la revisione aggiornata, e se è stato eliminato da altri lo si scopre qui.
    func refresh() async {
        guard let companyId = backend.activeCompanyId, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let fresh = try await backend.api.call(AdminWorkflowsAPI.flow(companyId: companyId, flowId: flowId))
            flow = fresh
            list.apply(fresh)
        } catch {
            if AdminWorkflowFailure.isNotFound(error) {
                flow = nil
                list.remove(id: flowId)
            } else if let message = AdminWorkflowFailure.message(for: error, backend: backend), flow != nil {
                // Il flusso a schermo resta (è quello della lista): il motivo va in un avviso.
                actionError = message
            }
        }
    }
}
