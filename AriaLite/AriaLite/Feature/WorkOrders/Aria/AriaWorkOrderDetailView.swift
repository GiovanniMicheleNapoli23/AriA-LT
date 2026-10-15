//
//  AriaWorkOrderDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Il dettaglio di un lavoro Aria. Il lavoro vero sta nei passi della procedura, che si eseguono uno
//  alla volta (AriaStepRunnerView): la schermata risponde a "cosa faccio adesso?" con la scheda del
//  prossimo passo e un pulsante sempre in vista in basso. Sicurezza prima di partire; la descrizione
//  (anche lunghissima), i dettagli e i passi già fatti stanno sotto o ripiegati.
//

import SwiftUI

struct AriaWorkOrderDetailView: View {
    @State var order: AriaWorkOrder
    let store: AriaWorkOrderStore
    @Environment(\.dismiss) private var dismiss

    @State private var descriptionExpanded = false
    @State private var showDoneSteps = false
    /// `nil`: si decide da sé (aperte prima di iniziare, ripiegate dopo).
    @State private var safetyOverride: Bool?
    @State private var isLoaded = false
    @State private var runner: RunnerTarget?
    @State private var showComplete = false

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
                header
                if !isLoaded && order.procedure == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
                } else if !steps.isEmpty {
                    // Prima di partire la sicurezza viene prima di tutto; a lavoro iniziato sta sotto, ripiegata.
                    if reportedCount == 0, !safetyWarnings.isEmpty { safetyCard }
                    focusCard
                    if reportedCount > 0, !safetyWarnings.isEmpty { safetyCard }
                    stepsCard
                }
                descriptionCard
                resourcesCard
                detailsCard
                if let notes = order.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes").font(.headline)
                        Text(notes).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
                }
                if isLoaded, steps.isEmpty, !order.isClosed { noProcedureCard }
            }
            .padding(20)
        }
        .liteBackground()
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { if !steps.isEmpty { actionBar } }
        .refreshable { await reload() }
        .task { await reload() }
        .fullScreenCover(item: $runner, onDismiss: { Task { await reload() } }) { target in
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
            HStack {
                Text(order.statusLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                if let level = order.priorityLevel { AriaPriorityBadge(level: level) }
                Spacer()
                if let due = order.dueDate, !order.isClosed {
                    let text = due.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                    Label(order.isOverdue ? String(localized: "Overdue · \(text)") : text,
                          systemImage: order.isOverdue ? "exclamationmark.clock.fill" : "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(order.isOverdue ? Color.red : Color.secondary)
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

    // MARK: Cosa faccio adesso

    /// Il prossimo passo (o "tutto fatto") con l'avanzamento: la prima cosa da leggere.
    private var focusCard: some View {
        let fraction = Double(reportedCount) / Double(steps.count)
        return VStack(alignment: .leading, spacing: 12) {
            if order.isClosed {
                Label("Task closed", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else if let step = nextStep {
                Button { runner = RunnerTarget(id: step.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next step · \(step.number) of \(steps.count)")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(Color.liteAccent)
                        Text(step.displayText)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Label("All steps reported", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("Complete the task to send it for verification.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: fraction)
                    .tint(allReported ? .green : Color.liteAccent)
                HStack {
                    Text("\(reportedCount) of \(steps.count) steps reported")
                    Spacer()
                    Text(verbatim: "\(Int((fraction * 100).rounded()))%")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
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
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(order.isClosed ? Color.liteAccent : allReported ? .green : Color.liteAccent)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
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
                        .font(.system(size: 12, weight: .semibold))
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

    private var stepsCard: some View {
        // Finché c'è lavoro da fare i passi già fatti si ripiegano: restano quelli che contano.
        let done = steps.filter { $0.report?.status == "done" }
        let canFold = !done.isEmpty && done.count < steps.count
        let visible = canFold && !showDoneSteps ? steps.filter { $0.report?.status != "done" } : steps
        return VStack(alignment: .leading, spacing: 0) {
            Text("Steps").font(.headline).padding(.bottom, 6)
            if canFold {
                Button {
                    withAnimation(.snappy) { showDoneSteps.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("\(done.count) steps done")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(showDoneSteps ? 180 : 0))
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }
            ForEach(visible) { step in
                Button { runner = RunnerTarget(id: step.id) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        stepMarker(step)
                        Text(step.displayText)
                            .font(.subheadline.weight(step.id == nextStep?.id && !order.isClosed ? .semibold : .regular))
                            .foregroundStyle(step.report?.status == "done" ? Color.secondary : Color.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        Spacer(minLength: 4)
                        if let report = step.report, !report.photos.isEmpty || report.note != nil {
                            Image(systemName: report.photos.isEmpty ? "note.text" : "photo")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if step.id != visible.last?.id { Divider() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
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
                    .foregroundStyle(isNext ? Color.white : Color.liteAccent)
                    .frame(width: 22, height: 22)
                    .background(isNext ? Color.liteAccent : Color.liteAccent.opacity(0.12), in: Circle())
            }
        }
        .font(.system(size: 22))
        .frame(width: 24, height: 24)
    }

    // MARK: Contesto

    /// La descrizione, ripulita (righe vuote, elenchi) e compressa: le diagnosi lunghe non spingono giù il resto.
    @ViewBuilder
    private var descriptionCard: some View {
        if let description = order.description.map(Self.tidy), !description.isEmpty {
            let isLong = description.count > 200 || description.filter(\.isNewline).count > 2
            VStack(alignment: .leading, spacing: 8) {
                Text("Description").font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(descriptionExpanded || !isLong ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if isLong {
                    Button(descriptionExpanded ? "Show less" : "Show more") {
                        withAnimation(.snappy) { descriptionExpanded.toggle() }
                    }
                    .font(.footnote.weight(.semibold))
                    .tint(Color.liteAccent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        }
    }

    /// Niente righe vuote di troppo, elenchi "- voce" come punti.
    private static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                for marker in ["- ", "* "] where line.hasPrefix(marker) { return "• " + line.dropFirst(2) }
                return line
            }
            .joined(separator: "\n")
    }

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

    /// Tipo, categoria, date: servono di rado, restano ripiegati.
    private var detailsCard: some View {
        DisclosureGroup("Details") {
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
            .padding(.top, 6)
        }
        .font(.headline)
        .tint(.secondary)
        .padding(16)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    /// Ordine senza passi: si può chiudere solo descrivendo cosa è stato fatto.
    private var noProcedureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("This task has no procedure steps.", systemImage: "list.bullet.clipboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { showComplete = true } label: {
                Label("Complete task", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.liteAccent)
        }
        .padding(16)
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
