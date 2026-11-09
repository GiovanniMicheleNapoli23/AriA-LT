//
//  AdminWorkOrderTemplatesViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I modelli di ordine (/v1/work-order-templates): elenco, creazione, modifica, eliminazione e "crea ordine dal modello".
//  L'elenco è dello stabilimento attivo (più i modelli senza stabilimento) e si cerca per titolo, categoria,
//  asset e zona. "Crea ordine" chiede al server i campi del modello (apply) e con quelli crea l'ordine.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderTemplatesViewModel {
    let backend: AriaBackend
    /// Un ordine creato da un modello: la lista degli ordini si ricarica.
    var onOrderCreated: () -> Void = {}
    /// Ricambi e asset per il form.
    let catalog: AdminWorkOrderPartCatalog

    private(set) var templates: [AdminWorkOrderTemplate] = []
    var searchText = ""

    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isForbidden = false
    /// Il modello che sta creando un ordine o che si sta eliminando.
    private(set) var busyId: String?
    /// "Work order created" dopo "Crea ordine".
    private(set) var notice: String?

    /// Il form aperto (sheet).
    var form: AdminWorkOrderTemplateFormViewModel?
    /// In attesa di conferma.
    var pendingDelete: AdminWorkOrderTemplate?
    var pendingApply: AdminWorkOrderTemplate?

    @ObservationIgnored private var loadedPlantId: String?
    @ObservationIgnored private var generation = 0

    init(backend: AriaBackend) {
        self.backend = backend
        catalog = AdminWorkOrderPartCatalog(backend: backend)
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        generation += 1
        templates = []
        searchText = ""
        hasLoaded = false
        isLoading = false
        errorMessage = nil
        isForbidden = false
        busyId = nil
        notice = nil
        form = nil
        pendingDelete = nil
        pendingApply = nil
        loadedPlantId = nil
        catalog.reset()
    }

    // MARK: Caricamento

    func loadIfNeeded() async {
        guard !hasLoaded || loadedPlantId != backend.activePlantId else { return }
        await load()
    }

    func load() async {
        generation += 1
        let current = generation, plantId = backend.activePlantId
        isLoading = true
        defer { if current == generation { isLoading = false } }
        do {
            let rows = try await api.templateList()
            guard current == generation else { return }
            templates = rows.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            errorMessage = nil
            isForbidden = false
            hasLoaded = true
            loadedPlantId = plantId
        } catch {
            guard current == generation,
                  let message = AdminWorkOrderFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
            isForbidden = AdminWorkOrderFailure.isForbidden(error)
        }
    }

    // MARK: Righe

    /// I modelli dello stabilimento attivo (e quelli senza stabilimento) che corrispondono alla ricerca.
    var visibleTemplates: [AdminWorkOrderTemplate] {
        let plantId = backend.activePlantId
        let inPlant = templates.filter { plantId == nil || $0.plantId == nil || $0.plantId == plantId }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return inPlant }
        return inPlant.filter {
            [$0.title, $0.category, $0.assetTag, $0.zone].contains { $0?.localizedStandardContains(query) == true }
        }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func subtitle(_ template: AdminWorkOrderTemplate) -> String {
        AdminWorkOrderFormat.joined([
            template.type == .unknown ? nil : template.type.localized,
            template.category,
            template.assetTag,
            template.estimatedDurationMin.map { AdminWorkOrderFormat.duration(minutes: $0) },
        ])
    }

    func stepsLabel(_ template: AdminWorkOrderTemplate) -> String {
        String(localized: "\(template.steps.count) steps")
    }

    func partsLabel(_ template: AdminWorkOrderTemplate) -> String? {
        template.parts.isEmpty ? nil : String(localized: "\(template.parts.count) parts")
    }

    func priority(_ template: AdminWorkOrderTemplate) -> AdminWorkOrderPriority? {
        template.priority == .unknown ? nil : template.priority
    }

    var canCreate: Bool { !isForbidden && backend.activePlantId != nil }

    // MARK: Form

    func startCreating() {
        notice = nil
        form = AdminWorkOrderTemplateFormViewModel(template: nil, backend: backend, catalog: catalog) { [weak self] saved in
            self?.didSave(saved)
        }
    }

    func startEditing(_ template: AdminWorkOrderTemplate) {
        notice = nil
        form = AdminWorkOrderTemplateFormViewModel(template: template, backend: backend, catalog: catalog) { [weak self] saved in
            self?.didSave(saved)
        }
    }

    private func didSave(_ saved: AdminWorkOrderTemplate) {
        if let index = templates.firstIndex(where: { $0.id == saved.id }) {
            templates[index] = saved
        } else {
            templates.append(saved)
            templates.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    // MARK: Eliminazione

    func confirmDelete(_ template: AdminWorkOrderTemplate) { pendingDelete = template }

    var isConfirmingDelete: Bool {
        get { pendingDelete != nil }
        set { if !newValue { pendingDelete = nil } }
    }

    /// Riceve il modello dal dialogo: alla chiusura `pendingDelete` è già `nil`.
    func delete(_ template: AdminWorkOrderTemplate) async {
        pendingDelete = nil
        guard busyId == nil else { return }
        busyId = template.id
        errorMessage = nil
        notice = nil
        defer { busyId = nil }
        do {
            try await api.deleteTemplate(template.id)
            templates.removeAll { $0.id == template.id }
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Crea ordine

    func confirmApply(_ template: AdminWorkOrderTemplate) { pendingApply = template }

    var isConfirmingApply: Bool {
        get { pendingApply != nil }
        set { if !newValue { pendingApply = nil } }
    }

    /// apply restituisce i campi dell'ordine; se arrivasse già un ordine creato (id e data di creazione)
    /// non se ne crea un secondo.
    func apply(_ template: AdminWorkOrderTemplate) async {
        pendingApply = nil
        guard busyId == nil else { return }
        busyId = template.id
        errorMessage = nil
        notice = nil
        defer { busyId = nil }
        let api = api
        do {
            var fields = try await api.applyTemplate(template.id)
            let alreadyCreated = fields["id"].map { $0 != .null } == true && fields["created_at"] != nil
            if !alreadyCreated {
                if fields["title"] == nil || fields["title"] == .null { fields["title"] = .string(template.title) }
                if fields["plant_id"] == nil || fields["plant_id"] == .null {
                    guard let plantId = template.plantId ?? backend.activePlantId else {
                        errorMessage = String(localized: "Choose a plant first.")
                        return
                    }
                    fields["plant_id"] = .string(plantId)
                }
                _ = try await api.createOrder(from: fields)
            }
            notice = String(localized: "Work order created from “\(template.title)”.")
            onOrderCreated()
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    func dismissNotice() { notice = nil }
}
