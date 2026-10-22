//
//  AdminWorkOrderDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un ordine per l'admin: tutti i campi, l'assegnazione, la procedura con i resoconti dei passi
//  (GET /v1/work-orders/{id}?include=procedure e /step-reports), cambio di stato, assegnazione automatica,
//  traduzione dei testi, modifica ed eliminazione. I passi si spuntano e si refertano (AdminWorkOrderStepActions).
//  Parte dall'ordine della lista, così la schermata non è mai vuota mentre arriva quello completo.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderDetailViewModel {
    private let list: AdminWorkOrdersViewModel
    private(set) var order: AdminWorkOrder
    private(set) var reports: [AdminWorkOrderStepReport] = []

    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var isDeleting = false
    /// Eliminato: la schermata si chiude.
    private(set) var isDeleted = false

    var isConfirmingDelete = false
    /// La scheda aperta; le schede tengono i loro dati finché il dettaglio resta aperto.
    var tab: AdminWorkOrderTab = .overview
    let activity: AdminWorkOrderActivityViewModel
    let costs: AdminWorkOrderCostsViewModel
    let files: AdminWorkOrderFilesViewModel
    /// L'assistente AI aperto (sheet).
    var assistant: AdminWorkOrderAssistantViewModel?
    /// Il form di modifica aperto (sheet).
    var editForm: AdminWorkOrderFormViewModel?
    /// Cambio di stato, completamento e assegnazione automatica.
    let actions: AdminWorkOrderQuickActions
    /// Spunte e risultati dei passi.
    let stepActions: AdminWorkOrderStepActions

    /// I testi dell'ordine in un'altra lingua, mostrati nella panoramica al posto degli originali.
    private(set) var translation: AdminWorkOrderTranslation?
    private(set) var translatingLocale: String?
    private(set) var translationError: String?

    init(order: AdminWorkOrder, list: AdminWorkOrdersViewModel) {
        self.order = order
        self.list = list
        activity = AdminWorkOrderActivityViewModel(orderId: order.id, backend: list.backend)
        costs = AdminWorkOrderCostsViewModel(orderId: order.id, backend: list.backend)
        files = AdminWorkOrderFilesViewModel(orderId: order.id, backend: list.backend)
        actions = AdminWorkOrderQuickActions(backend: list.backend)
        stepActions = AdminWorkOrderStepActions(orderId: order.id, backend: list.backend)
        actions.onUpdated = { [weak self] updated in self?.didSave(updated) }
        actions.onReload = { [weak self] _ in await self?.load() }
        actions.showSteps = { [weak self] in self?.tab = .steps }
        stepActions.reload = { [weak self] in await self?.load() }
    }

    func openAssistant() {
        assistant = AdminWorkOrderAssistantViewModel(order: order, backend: backend) { [weak self] updated in
            self?.didSave(updated)
        }
    }

    private var backend: AriaBackend { list.backend }
    private var directory: AdminWorkOrderDirectory { list.directory }
    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    // MARK: Caricamento

    /// Ordine completo e resoconti insieme; i resoconti sono un di più: se mancano resta la procedura.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        let api = api, id = order.id
        async let detail = api.detail(id)
        async let reports = try? api.stepReports(id)
        do {
            let fresh = try await detail
            order = fresh
            errorMessage = nil
            list.didUpdate(fresh)
        } catch {
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) { errorMessage = message }
        }
        if let rows = await reports { self.reports = rows }
        hasLoaded = true
        await directory.loadIfNeeded()
    }

    /// Pull-to-refresh: l'ordine e, se aperta, la scheda di attività, costi o file.
    func refresh() async {
        await load()
        switch tab {
        case .activity: await activity.load()
        case .files: await files.load()
        case .costs: await costs.load()
        case .overview, .steps: break
        }
    }

    // MARK: Intestazione

    var statusLabel: String? { order.status.map(\.localized) }
    var status: AdminWorkOrderStatus? { order.status }
    var priority: AdminWorkOrderPriority? { order.priority == .unknown ? nil : order.priority }
    var typeLabel: String? { order.type.map(\.localized) }
    var place: String { AdminWorkOrderFormat.joined([order.assetTag, directory.asset(order.assetTag)?.name, order.zone]) }

    /// La scadenza sotto il titolo, in rosso se superata.
    var dueLabel: String? {
        guard let due = order.dueDate, !order.isClosed else { return nil }
        let text = AdminWorkOrderFormat.dateTime(due)
        return order.isOverdue() ? String(localized: "Overdue · \(text)") : String(localized: "Due \(text)")
    }

    var isOverdue: Bool { order.isOverdue() }

    var assigneeName: String? { directory.assigneeName(for: order) }

    /// "3/5" accanto alla scadenza; `nil` senza passi.
    var progressShort: String? {
        let items = steps
        guard !items.isEmpty else { return nil }
        return "\(items.filter { $0.status != nil }.count)/\(items.count)"
    }

    // MARK: Stato

    var statusChoices: [AdminWorkOrderStatus] { actions.statusChoices(for: order) }
    var isChangingStatus: Bool { actions.isBusy(order) }

    func changeStatus(to status: AdminWorkOrderStatus) { actions.change(order, to: status) }

    func autoAssign() async { await actions.autoAssign(order) }

    // MARK: Traduzione

    /// Le lingue offerte, col nome nella lingua dell'app; quella dell'app per prima.
    var translationLanguages: [(code: String, name: String)] {
        let codes = ["it", "en", "es", "fr", "de", "pt", "pl", "ro"]
        let current = Locale.current.language.languageCode?.identifier
        let ordered = codes.filter { $0 == current } + codes.filter { $0 != current }
        return ordered.map { code in
            (code, Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code)
        }
    }

    var translationLanguageName: String? {
        translation.map { Locale.current.localizedString(forLanguageCode: $0.locale)?.localizedCapitalized ?? $0.locale }
    }

    var isTranslating: Bool { translatingLocale != nil }

    func translate(to locale: String) async {
        translatingLocale = locale
        translationError = nil
        tab = .overview
        defer { translatingLocale = nil }
        do {
            let result = try await api.translation(order.id, locale: locale)
            translation = result
            if result.isEmpty { translationError = String(localized: "There's nothing to translate in this work order.") }
        } catch {
            translationError = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    func clearTranslation() {
        translation = nil
        translationError = nil
    }

    // MARK: Campi

    var textBlocks: [AdminWorkOrderTextBlock] {
        [
            order.description.map { AdminWorkOrderTextBlock(title: String(localized: "Description"), icon: "text.alignleft", text: $0) },
            order.notes.map { AdminWorkOrderTextBlock(title: String(localized: "Notes"), icon: "note.text", text: $0) },
            order.resolutionNotes.map {
                AdminWorkOrderTextBlock(title: String(localized: "Resolution notes"), icon: "checkmark.seal", text: $0)
            },
            order.feedback.map { AdminWorkOrderTextBlock(title: String(localized: "Feedback"), icon: "bubble.left", text: $0) },
        ].compactMap { $0 }
    }

    var fieldGroups: [AdminWorkOrderFieldGroup] {
        [assignmentGroup, scheduleGroup, detailsGroup, costsGroup].filter { !$0.fields.isEmpty }
    }

    private var assignmentGroup: AdminWorkOrderFieldGroup {
        let user = directory.user(order.assignedToUserId)
        return group(String(localized: "Assignment"), "person.crop.circle", [
            field(String(localized: "Assignee"), user?.displayName ?? order.assignedTo),
            field(String(localized: "Team"), directory.team(order.assignedToTeamId)?.name ?? order.assignedToTeamId),
            field(String(localized: "Assigned by"), order.assignmentSource.map(\.localized)),
            field(String(localized: "Assigned"), order.assignedAt.map(AdminWorkOrderFormat.dateTime)),
            field(String(localized: "Auto-assign note"), order.autoAssignNote),
            field(String(localized: "Requested by"), order.requestedBy),
            field(String(localized: "Verified by"), order.verifiedBy),
        ])
    }

    private var scheduleGroup: AdminWorkOrderFieldGroup {
        group(String(localized: "Schedule"), "calendar", [
            field(String(localized: "Scheduled"), order.scheduledDate.map(AdminWorkOrderFormat.dateTime)),
            field(String(localized: "Due"), order.dueDate.map(AdminWorkOrderFormat.dateTime), alert: isOverdue),
            field(String(localized: "Started"), order.startedAt.map(AdminWorkOrderFormat.dateTime)),
            field(String(localized: "Completed"), (order.completedAt ?? order.completedDate).map(AdminWorkOrderFormat.dateTime)),
            field(String(localized: "Estimated duration"), order.estimatedDurationMin.map { AdminWorkOrderFormat.duration(minutes: $0) }),
            field(String(localized: "Actual duration"), order.actualDurationMin.map { AdminWorkOrderFormat.duration(minutes: $0) }),
        ])
    }

    private var detailsGroup: AdminWorkOrderFieldGroup {
        group(String(localized: "Details"), "info.circle", [
            field(String(localized: "Type"), typeLabel),
            field(String(localized: "Category"), order.category),
            field(String(localized: "Asset"), order.assetTag),
            field(String(localized: "Zone"), order.zone),
            // Senza il nome (stabilimento di un'altra azienda o non caricato) l'id non dice niente: si omette.
            field(String(localized: "Plant"), directory.plantName(order.plantId)),
            field(String(localized: "Alarm code"), order.alarmCode),
            field(String(localized: "Created"), order.createdAt.map(AdminWorkOrderFormat.dateTime)),
            field(String(localized: "Updated"), order.updatedAt.map(AdminWorkOrderFormat.dateTime)),
        ])
    }

    private var costsGroup: AdminWorkOrderFieldGroup {
        group(String(localized: "Costs"), "eurosign.circle", [
            field(String(localized: "Labor hours"), order.laborHours.map(AdminWorkOrderFormat.hours)),
            field(String(localized: "Labor cost"), order.laborCost.map(AdminWorkOrderFormat.amount)),
            field(String(localized: "Parts cost"), order.partsCost.map(AdminWorkOrderFormat.amount)),
        ])
    }

    private func group(_ title: String, _ icon: String, _ fields: [AdminWorkOrderField?]) -> AdminWorkOrderFieldGroup {
        AdminWorkOrderFieldGroup(title: title, icon: icon, fields: fields.compactMap { $0 })
    }

    private func field(_ label: String, _ value: String?, alert: Bool = false) -> AdminWorkOrderField? {
        guard let value, !value.isEmpty else { return nil }
        return AdminWorkOrderField(label: label, value: value, isAlert: alert)
    }

    // MARK: Procedura

    var safetyWarnings: [String] { order.procedure?.safetyWarnings ?? [] }

    /// Attrezzi e ricambi della procedura, solo gli elenchi non vuoti.
    var resources: [(title: String, icon: String, items: [String])] {
        [
            (String(localized: "Tools needed"), "wrench.and.screwdriver", order.procedure?.toolsNeeded ?? []),
            (String(localized: "Parts needed"), "shippingbox", order.procedure?.partsNeeded ?? []),
        ].filter { !$0.2.isEmpty }
    }

    /// I passi della procedura con il resoconto; senza procedura, i soli resoconti arrivati.
    var steps: [AdminWorkOrderStepRowItem] {
        let byStep = Dictionary(reports.map { ($0.stepId, $0) }) { first, _ in first }
        if let procedure = order.procedure, !procedure.steps.isEmpty {
            return procedure.steps.map { step in
                let report = byStep[step.id]
                let status = report?.status ?? step.report?.status
                let when = report?.statusAt ?? report?.reportedAt ?? step.report?.reportedAt
                return AdminWorkOrderStepRowItem(
                    id: step.id, number: step.number, text: Self.stripStepPrefix(step.text),
                    status: status,
                    note: report?.note ?? step.report?.note,
                    byline: status == nil ? nil : byline(report, at: when),
                    photoCount: max(report?.photoCount ?? 0, step.report?.photoCount ?? 0)
                )
            }
        }
        // Un resoconto per passo (il primo), così gli id delle righe restano unici.
        var seen = Set<String>()
        return reports.filter { seen.insert($0.stepId).inserted }.enumerated().map { index, report in
            AdminWorkOrderStepRowItem(id: report.stepId, number: index + 1, text: String(localized: "Step \(index + 1)"),
                                      status: report.status, note: report.note,
                                      byline: byline(report, at: report.statusAt ?? report.reportedAt),
                                      photoCount: report.photoCount)
        }
    }

    private func byline(_ report: AdminWorkOrderStepReport?, at date: Date?) -> String? {
        let text = AdminWorkOrderFormat.joined([
            report?.statusByName ?? report?.reportedByName,
            date.map(AdminWorkOrderFormat.dateTime),
            report?.statusSource.flatMap { $0 == .unknown ? nil : $0.localized },
        ])
        return text.isEmpty ? nil : text
    }

    /// "Step 3: …" scritto dal server davanti al testo: il numero c'è già.
    private static func stripStepPrefix(_ text: String) -> String {
        let stripped = text.replacing(/^\s*step\s*\d+\s*[:.\-–—)]\s*/.ignoresCase(), with: "")
        return stripped.isEmpty ? text : stripped
    }

    /// "3 of 5 steps reported" e la frazione per la barra; `nil` senza passi.
    var progress: (fraction: Double, text: String)? {
        let items = steps
        guard !items.isEmpty else { return nil }
        let reported = items.filter { $0.status != nil }.count
        return (Double(reported) / Double(items.count), String(localized: "\(reported) of \(items.count) steps reported"))
    }

    /// Ordine aperto con la procedura non ancora caricata: si aspetta invece di dire "nessun passo".
    var isLoadingSteps: Bool { !hasLoaded && order.procedure == nil }

    /// Chiuso: il server rifiuta ogni modifica ai passi (`work_order_closed`).
    var canEditSteps: Bool { !order.isClosed }

    /// Passi con un risultato da togliere: "Reset all checks" ha senso.
    var hasReportedSteps: Bool { steps.contains { $0.status != nil } }

    // MARK: Modifica ed eliminazione

    func startEditing() {
        editForm = AdminWorkOrderFormViewModel(mode: .edit(order), backend: backend, directory: directory) { [weak self] saved in
            self?.didSave(saved)
        }
    }

    private func didSave(_ saved: AdminWorkOrder) {
        // La risposta del PATCH non porta la procedura: si tiene quella che c'è.
        var updated = saved
        if updated.procedure == nil { updated.procedure = order.procedure }
        if updated.stepProgress == nil { updated.stepProgress = order.stepProgress }
        order = updated
        list.didUpdate(updated)
    }

    func confirmDelete() { isConfirmingDelete = true }

    func delete() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await AdminWorkOrdersAPI(api: backend.api).delete(order.id)
            list.didDelete(order.id)
            isDeleted = true
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }
}
