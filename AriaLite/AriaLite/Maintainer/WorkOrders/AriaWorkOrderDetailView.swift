//
//  AriaWorkOrderDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Il dettaglio di un lavoro Aria. Il lavoro vero sta nei passi della procedura, che si eseguono uno
//  alla volta (AriaStepRunnerView): la schermata risponde a "cosa faccio adesso?" con la checklist, dove
//  il prossimo passo è evidenziato, e un pulsante sempre in vista in basso. Sicurezza prima di partire;
//  la descrizione (anche lunghissima), i dettagli e i passi già fatti stanno sotto o ripiegati.
//

import SwiftUI

struct AriaWorkOrderDetailView: View {
    @State var order: AriaWorkOrder
    let store: AriaWorkOrderStore
    @Environment(\.dismiss) private var dismiss

    @State private var showDoneSteps = false
    /// Le sezioni della scheda informazioni aperte: di partenza sono tutte chiuse.
    @State private var openInfo: Set<InfoSection>
    /// `nil`: si decide da sé (aperte prima di iniziare, ripiegate dopo).
    @State private var safetyOverride: Bool?
    @State private var isLoaded = false
    @State private var runner: RunnerTarget?
    @State private var showComplete = false
    /// Il cerchio del numero di passo cresce col testo (Dynamic Type).
    @ScaledMetric(relativeTo: .caption) private var markerSize: CGFloat = 22
    /// La colonna delle icone nelle sezioni informative, idem.
    @ScaledMetric(relativeTo: .subheadline) private var infoIconWidth: CGFloat = 20

    nonisolated enum InfoSection: Hashable { case description, notes, details }

    init(order: AriaWorkOrder, store: AriaWorkOrderStore, openInfo: Set<InfoSection> = []) {
        _order = State(initialValue: order)
        self.store = store
        _openInfo = State(initialValue: openInfo)
    }

    /// Da quale passo si apre l'esecuzione.
    private struct RunnerTarget: Identifiable {
        let id: String
    }

    private var steps: [AriaProcedureStep] { order.procedure?.steps ?? [] }
    private var reportedCount: Int { steps.filter { $0.report != nil }.count }
    private var allReported: Bool { !steps.isEmpty && reportedCount == steps.count }
    private var safetyWarnings: [String] { order.procedure?.safetyWarnings ?? [] }

    /// Il primo passo senza risultato: è "cosa faccio adesso".
    private var nextStep: AriaProcedureStep? { steps.first { $0.report == nil } }

    private var isSafetyOpen: Bool { safetyOverride ?? (reportedCount == 0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AriaSyncStatusView(store: store)
                header
                if !isLoaded && order.procedure == nil, !store.isOffline {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
                } else if !steps.isEmpty {
                    // Prima di partire la sicurezza viene prima di tutto; a lavoro iniziato sta sotto, ripiegata.
                    if reportedCount == 0, !safetyWarnings.isEmpty { safetyCard }
                    if reportedCount > 0, !safetyWarnings.isEmpty { safetyCard }
                    stepsCard
                }
                resourcesCard
                infoCard
                if isLoaded, steps.isEmpty, !order.isClosed {
                    // Offline e mai aperto online: i passi non sono sul telefono, non è che non ci siano.
                    if store.isOffline && order.procedure == nil { offlineStepsCard } else { noProcedureCard }
                }
            }
            .ariaReadableWidth()
            .padding(20)
        }
        .liteBackground()
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .ariaBottomBar { if !steps.isEmpty { actionBar } }
        .refreshable { await reload() }
        .task { await reload() }
        // Uscire dall'esecuzione è la fine (o una pausa) della procedura: il lotto parte subito.
        .fullScreenCover(item: $runner, onDismiss: { Task { await store.flush(); await reload() } }) { target in
            AriaStepRunnerView(order: $order, store: store, startingAt: target.id)
        }
        .sheet(isPresented: $showComplete) {
            AriaCompleteSheet(unreportedCount: steps.count - reportedCount) { notes in
                switch await store.complete(order.id, resolutionNotes: notes) {
                case .updated(let closed):
                    order = closed
                    return nil
                case .gone:
                    dismiss()
                    return nil
                case .failed(let message):
                    return message
                }
            }
        }
        .sensoryFeedback(.success, trigger: order.status) { old, new in old != new && new == "completed" }
    }

    // MARK: Intestazione

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Una riga se ci sta; altrimenti la scadenza va sotto, e con i caratteri enormi tutto in colonna.
            ViewThatFits(in: .horizontal) {
                HStack {
                    statusText
                    priorityBadge
                    Spacer()
                    dueLabel
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack { statusText; priorityBadge }
                    dueLabel
                }
                VStack(alignment: .leading, spacing: 6) {
                    statusText
                    priorityBadge
                    dueLabel
                }
            }
            Text(order.title)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            let place = [order.assetTag, order.zone].compactMap { $0 }.filter { !$0.isEmpty }
            if !place.isEmpty {
                Text(place.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: some View {
        Text(order.statusLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.liteAccent)
    }

    @ViewBuilder
    private var priorityBadge: some View {
        if let level = order.priorityLevel { AriaPriorityBadge(level: level) }
    }

    @ViewBuilder
    private var dueLabel: some View {
        if let due = order.dueDate, !order.isClosed {
            let text = due.formatted(.dateTime.month(.abbreviated).day().hour().minute())
            Label(order.isOverdue ? String(localized: "Overdue · \(text)") : text,
                  systemImage: order.isOverdue ? "exclamationmark.clock.fill" : "clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(order.isOverdue ? Color.red : Color.secondary)
        }
    }

    /// Un pulsante sempre in vista: parte, riprende, chiude o rivede.
    private var actionBar: some View {
        Button {
            if order.isClosed || nextStep != nil {
                if let step = nextStep ?? steps.first { runner = RunnerTarget(id: step.id) }
            } else {
                showComplete = true
            }
        } label: {
            Label(actionTitle, systemImage: actionIcon)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .ariaProminentGlassButtonStyle(tint: !order.isClosed && allReported ? .green : Color.liteAccent,
                                       foreground: !order.isClosed && allReported ? .white : Color.liteOnAccent)
        .ariaReadableWidth()
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var actionTitle: LocalizedStringKey {
        if order.isClosed { "Review steps" }
        else if allReported { "Complete task" }
        else if reportedCount == 0 { "Start" }
        else { "Continue" }
    }

    private var actionIcon: String {
        if order.isClosed { "list.bullet.clipboard" }
        else if allReported { "checkmark.seal.fill" }
        else { "play.fill" }
    }

    // MARK: Sicurezza

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { safetyOverride = !isSafetyOpen }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                    Text("Safety warnings").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isSafetyOpen ? 180 : 0))
                }
                .foregroundStyle(.orange)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isSafetyOpen {
                ForEach(Array(safetyWarnings.enumerated()), id: \.offset) { _, warning in
                    Text(warning)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: Passi

    /// La checklist è l'unica scheda dei passi: in testa l'avanzamento, poi i passi. Quello da fare adesso è
    /// evidenziato e scritto per intero, i successivi sono righe corte, quelli già fatti si ripiegano.
    private var stepsCard: some View {
        let done = steps.filter { $0.report?.status == "done" }
        let canFold = !done.isEmpty && done.count < steps.count
        let visible = canFold && !showDoneSteps ? steps.filter { $0.report?.status != "done" } : steps
        return VStack(alignment: .leading, spacing: 14) {
            progressHeader
            VStack(alignment: .leading, spacing: 2) {
                if canFold { doneToggle(count: done.count) }
                ForEach(visible) { step in
                    Button { runner = RunnerTarget(id: step.id) } label: {
                        if step.id == nextStep?.id && !order.isClosed {
                            currentRow(step)
                        } else {
                            row(step)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    /// "Steps", la percentuale e la barra; a lavoro chiuso o finito, lo stato al posto del conteggio.
    private var progressHeader: some View {
        let fraction = Double(reportedCount) / Double(steps.count)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Steps").font(.headline)
                Spacer()
                if order.isClosed {
                    Label("Task closed", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if allReported {
                    Label("All steps reported", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text("\(reportedCount) of \(steps.count) steps reported")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: fraction)
                .tint(allReported ? .green : Color.liteAccent)
        }
    }

    private func doneToggle(count: Int) -> some View {
        Button {
            withAnimation(.snappy) { showDoneSteps.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("\(count) steps done")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(showDoneSteps ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Il passo da fare adesso: riquadro evidenziato, azione in grassetto e indicazioni sotto.
    private func currentRow(_ step: AriaProcedureStep) -> some View {
        let text = AriaStepText(step.displayText)
        return HStack(alignment: .top, spacing: 12) {
            stepMarker(step)
            VStack(alignment: .leading, spacing: 5) {
                Text("Next step · \(step.number) of \(steps.count)")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Color.liteAccent.opacity(0.7))
                if let tag = text.tag {
                    Text(verbatim: tag)
                        .font(.caption2.weight(.bold))
                        .tracking(0.4)
                        .foregroundStyle(text.isSafetyTag ? Color.orange : Color.liteAccent)
                }
                Text(text.headline)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                if !text.items.isEmpty || !text.notes.isEmpty {
                    Text((text.items.isEmpty ? text.notes : text.items.map { "• " + $0 }).joined(separator: text.items.isEmpty ? " " : "\n"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liteAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.liteAccent.opacity(0.15), lineWidth: 1))
        .contentShape(Rectangle())
    }

    /// Un passo già fatto, non fatto o ancora da fare: una riga corta.
    private func row(_ step: AriaProcedureStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            stepMarker(step)
            Text(step.displayText)
                .font(.subheadline)
                .foregroundStyle(step.report?.status == "done" ? Color.secondary : Color.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Spacer(minLength: 4)
            if let report = step.report, !report.photos.isEmpty || report.note != nil {
                Image(systemName: report.photos.isEmpty ? "note.text" : "photo")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func stepMarker(_ step: AriaProcedureStep) -> some View {
        let isNext = step.id == nextStep?.id && !order.isClosed
        return Group {
            switch step.report?.status {
            case "done":
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case "not_done":
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            default:
                Text(verbatim: "\(step.number)")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isNext ? Color.liteOnAccent : Color.liteAccent)
                    .frame(width: markerSize, height: markerSize)
                    .background(isNext ? Color.liteAccent : Color.liteAccent.opacity(0.12), in: Circle())
            }
        }
        .font(.system(size: markerSize))
        .frame(width: markerSize + 2, height: markerSize + 2)
    }

    // MARK: Contesto

    @ViewBuilder
    private var resourcesCard: some View {
        let tools = order.procedure?.toolsNeeded ?? []
        let parts = order.procedure?.partsNeeded ?? []
        if !tools.isEmpty || !parts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !tools.isEmpty { list("Tools needed", "wrench.and.screwdriver", tools) }
                if !parts.isEmpty { list("Parts needed", "shippingbox", parts) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func list(_ title: LocalizedStringKey, _ icon: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.headline)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(verbatim: "• \(item)").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Informazioni

    private var descriptionText: String? { nonEmpty(order.description) }
    private var notesText: String? { nonEmpty(order.notes) }

    private func nonEmpty(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    /// Descrizione, note e dettagli in un'unica scheda, ogni sezione una riga chiusa con un'anteprima:
    /// si apre solo quello che serve.
    @ViewBuilder
    private var infoCard: some View {
        let detailsPreview = [order.typeLabel, order.category, order.estimatedDurationMin.map { duration($0) }]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        let sections: [(InfoSection, LocalizedStringKey, String, String?)] = [
            (.description, "Description", "text.alignleft", descriptionText.map(Self.preview)),
            (.notes, "Notes", "note.text", notesText.map(Self.preview)),
            (.details, "Details", "info.circle", detailsPreview),
        ].filter { section in
            switch section.0 {
            case .description: descriptionText != nil
            case .notes: notesText != nil
            case .details: true
            }
        }
        VStack(spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                infoRow(section.0, title: section.1, icon: section.2, preview: section.3)
                if index < sections.count - 1 { Divider().padding(.leading, 44) }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(_ section: InfoSection, title: LocalizedStringKey, icon: String, preview: String?) -> some View {
        let isOpen = openInfo.contains(section)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    if isOpen { openInfo.remove(section) } else { openInfo.insert(section) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.liteAccent)
                        .frame(width: infoIconWidth)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        if !isOpen, let preview, !preview.isEmpty {
                            Text(preview)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                infoContent(section)
                    .padding(.leading, 48)
                    .padding(.trailing, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func infoContent(_ section: InfoSection) -> some View {
        switch section {
        case .description:
            if let text = descriptionText { AriaFormattedTextView(text: text) }
        case .notes:
            if let text = notesText { AriaFormattedTextView(text: text) }
        case .details:
            VStack(spacing: 0) {
                row("Type", order.typeLabel)
                row("Category", order.category)
                row("Asset", order.assetTag)
                row("Zone", order.zone)
                row("Scheduled", order.scheduledDate.map(format))
                row("Due", order.dueDate.map(format))
                row("Estimated duration", order.estimatedDurationMin.map { duration($0) })
                row("Assigned", order.assignedAt.map(format))
                row("Assignment", order.assignmentLabel)
            }
        }
    }

    /// La prima riga con del testo, senza i segni di elenco e di titolo.
    nonisolated private static func preview(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return line.replacing(/^[#\-*•–·\s]+/, with: "").replacingOccurrences(of: "**", with: "")
    }

    /// Ordine senza passi: si può chiudere solo descrivendo cosa è stato fatto.
    private var noProcedureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("This task has no procedure steps.", systemImage: "list.bullet.clipboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { showComplete = true } label: {
                Label("Complete task", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.liteAccent)
            .foregroundStyle(Color.liteOnAccent)
        }
        .padding(16)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var offlineStepsCard: some View {
        Label("The steps of this task aren't saved on this phone yet. They download as soon as you're back online.",
              systemImage: "icloud.slash")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Dati

    /// 404: l'ordine è stato riassegnato, si torna alla lista (che lo ha già tolto) senza messaggi.
    private func reload() async {
        switch await store.detail(of: order.id) {
        case .found(let fresh): order = fresh
        case .gone: dismiss()
        case nil: break
        }
        isLoaded = true
    }

    @ViewBuilder
    private func row(_ title: LocalizedStringKey, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(value).multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                .padding(.vertical, 11)
                Divider()
            }
        }
    }

    private func format(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func duration(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

extension AriaProcedureStep {
    /// Il testo del passo senza il prefisso "Step 3:" che il server a volte ci mette davanti:
    /// il numero è già nel segnaposto e nel contatore.
    var displayText: String {
        let stripped = text.replacing(/^\s*step\s*\d+\s*[:.\-–—)]\s*/.ignoresCase(), with: "")
        return stripped.isEmpty ? text : stripped
    }
}
