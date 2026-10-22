//
//  AriaArtifactViews.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Le card che Aria manda in chat (`aria.ui_artifact`): work order, tabelle,
//  KPI, grafici, asset, piani, diagnostica, allarmi, dashboard e le liste
//  di pianificazione. Stessi tipi e campi della web (types/agent-stream.ts).
//

import Charts
import SwiftUI

/// Cosa possono fare le card: mandare un prompt, chiamare un tool diretto, aprire una pagina della web.
struct AriaArtifactActions {
    var ask: (String) -> Void = { _ in }
    var quick: (_ label: String, _ tool: String, _ args: [String: AriaJSON]) -> Void = { _, _, _ in }
    var open: (String) -> Void = { _ in }
}

struct AriaArtifactView: View {
    let artifact: AriaArtifact
    var actions = AriaArtifactActions()

    private var d: [String: AriaJSON] { artifact.data }

    var body: some View {
        switch artifact.kind {
        case "wo-card": AriaWOCardView(data: d, actions: actions)
        case "table": AriaTableArtifact(data: d, actions: actions)
        case "kpi-grid": AriaKPIGrid(data: d, actions: actions)
        case "chart": AriaChartArtifact(data: d)
        case "asset-card": AriaAssetCard(data: d)
        case "maintenance-plan-card": AriaPlanCard(data: d)
        case "diagnostic-card": AriaDiagnosticCard(data: d, actions: actions)
        case "alarm-toast": AriaAlarmCard(data: d)
        case "dashboard": AriaDashboardArtifact(data: d, actions: actions)
        case "reassignment-plan", "assignment-suggestion", "similar-wo-list", "spare-parts-recommendation",
             "triage-plan", "member-absence-plan", "team-kanban":
            AriaListArtifact(kind: artifact.kind, data: d, actions: actions)
        default:
            Text("Artifact \(artifact.kind)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.tertiary))
        }
    }
}

// MARK: - Contenitore comune

struct AriaCard<Content: View>: View {
    var tint: Color = .liteAccent
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.14), lineWidth: 1))
    }
}

struct AriaBadge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Badge affiancati; se a testo grande non stanno sulla riga, uno sotto l'altro.
private struct AriaBadgeRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { content }
            VStack(alignment: .leading, spacing: 6) { content }
        }
    }
}

enum AriaTone {
    static func priority(_ value: String?) -> Color {
        switch value?.lowercased() {
        case "high", "critical", "alta": .red
        case "medium", "media": .orange
        case "low", "bassa": .green
        default: .secondary
        }
    }

    static func named(_ value: String?) -> Color {
        switch value {
        case "good": .green
        case "warn": .orange
        case "danger": .red
        default: .secondary
        }
    }
}

private struct AriaFactRow: View {
    let label: LocalizedStringKey
    let value: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let value, !value.isEmpty {
            // A testo molto grande etichetta e valore affiancati non stanno: il valore va sotto.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.footnote.weight(.medium))
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(value).font(.footnote.weight(.medium)).multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

private struct AriaBulletSection: View {
    let title: LocalizedStringKey
    let items: [String]
    var icon = "circle.fill"
    var tint: Color = .secondary
    /// Il pallino resta piccolo ma cresce con il testo.
    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 4

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Label {
                        Text(AriaMarkdown.inline(item)).font(.footnote)
                    } icon: {
                        Image(systemName: icon).font(icon == "circle.fill" ? .system(size: dotSize) : .caption2).foregroundStyle(tint)
                    }
                }
            }
        }
    }
}

private func strings(_ value: AriaJSON?) -> [String] {
    (value?.arrayValue ?? []).compactMap { $0.nonEmptyString ?? $0["text"]?.nonEmptyString }
}

// MARK: - Work order

struct AriaWOCardView: View {
    let data: [String: AriaJSON]
    var actions = AriaArtifactActions()
    @State private var expanded = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        AriaCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WO \(data["id"]?.stringValue ?? "—")")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(data["title"]?.stringValue ?? "")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "wrench.and.screwdriver.fill").foregroundStyle(Color.liteAccent)
            }
            AriaBadgeRow {
                if let status = data["status"]?.nonEmptyString { AriaBadge(text: status.replacingOccurrences(of: "_", with: " ")) }
                if let priority = data["priority"]?.nonEmptyString { AriaBadge(text: priority, tint: AriaTone.priority(priority)) }
                if data["source_system"]?.stringValue == "maintainx" { AriaBadge(text: "MaintainX", tint: .blue) }
            }
            AriaFactRow(label: "Asset", value: data["asset_tag"]?.nonEmptyString)
            AriaFactRow(label: "Alarm", value: data["alarm_code"]?.nonEmptyString)
            AriaFactRow(label: "Zone", value: data["zone"]?.nonEmptyString)
            AriaFactRow(label: "Estimated duration", value: data["estimated_duration_min"]?.doubleValue.map { "\(Int($0)) min" })

            if let description = data["description"]?.nonEmptyString {
                Text(AriaMarkdown.inline(description))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(expanded ? nil : 3)
            }
            if let checklist = data["checklist"], checklist.objectValue != nil {
                if expanded {
                    AriaBulletSection(title: "Safety", items: strings(checklist["safety_warnings"]), icon: "exclamationmark.triangle.fill", tint: .orange)
                    AriaBulletSection(title: "Steps", items: strings(checklist["steps"]), icon: "circle", tint: .liteAccent)
                    AriaBulletSection(title: "Tools", items: strings(checklist["tools_needed"]))
                    AriaBulletSection(title: "Parts", items: strings(checklist["parts_needed"]))
                }
                Button(expanded ? "Show less" : "Show checklist") {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
                .font(.footnote.weight(.medium))
            }
            // A testo grande i due pulsanti non stanno affiancati: vanno uno sotto l'altro.
            ViewThatFits(in: .horizontal) {
                HStack {
                    openButtons(spaced: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    openButtons(spaced: false)
                }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderless)
        }
    }

    /// "Apri work order" e "Apri in MaintainX"; `spaced` li spinge ai due lati della riga.
    @ViewBuilder
    private func openButtons(spaced: Bool) -> some View {
        if let id = data["id"]?.stringValue {
            Button("Open work order") { actions.open("/work-orders/\(id)") }
        }
        if spaced { Spacer() }
        if let url = data["external_url"]?.nonEmptyString.flatMap(URL.init(string:)).flatMap(AriaURLPolicy.external) {
            Button("Open in MaintainX") { openURL(url) }
        }
    }
}

// MARK: - Tabella

struct AriaTableArtifact: View {
    let data: [String: AriaJSON]
    var actions = AriaArtifactActions()

    private var columns: [AriaArtifactContent.TableColumn] { AriaArtifactContent.tableColumns(data) }
    private var rows: [[String: AriaJSON]] { AriaArtifactContent.tableRows(data) }
    /// Le celle si allargano con il testo, così a testo grande le due righe bastano ancora.
    @ScaledMetric(relativeTo: .footnote) private var cellMaxWidth: CGFloat = 220

    var body: some View {
        AriaCard {
            if let title = data["title"]?.nonEmptyString {
                Text(title).font(.subheadline.weight(.semibold))
            }
            if rows.isEmpty {
                Text(data["empty_hint"]?.nonEmptyString ?? String(localized: "No results."))
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 9) {
                        GridRow {
                            ForEach(columns, id: \.key) { column in
                                Text(column.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(columns, id: \.key) { column in
                                    AriaCappedWidth(max: cellMaxWidth) {
                                        Text(row[column.key]?.stringValue ?? "—")
                                            .font(.footnote)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { openRow(row) }
                        }
                    }
                }
            }
        }
    }

    /// row_link_template: "/work-orders/{id}" → pagina della web.
    private func openRow(_ row: [String: AriaJSON]) {
        if let path = AriaArtifactContent.rowLink(data, row: row) { actions.open(path) }
    }
}

/// Una ScrollView orizzontale non propone una larghezza: la proposta si limita a `max`,
/// così il testo va a capo (e la riga si alza) invece di troncarsi su una riga.
private struct AriaCappedWidth: Layout {
    var max: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = Swift.min(proposal.width ?? max, max)
        return subviews.first?.sizeThatFits(ProposedViewSize(width: width, height: nil)) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

// MARK: - KPI

struct AriaKPIGrid: View {
    let data: [String: AriaJSON]
    var actions = AriaArtifactActions()
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Due colonne; a testo molto grande una sola, così i valori non vanno a capo.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        AriaCard {
            if let title = data["title"]?.nonEmptyString {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    if let subtitle = data["subtitle"]?.nonEmptyString {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array((data["kpis"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, kpi in
                    let tone = AriaTone.named(kpi["tone"]?.stringValue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kpi["label"]?.stringValue ?? "")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        Text(kpi["value"]?.stringValue ?? "—")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(tone == .secondary ? Color.primary : tone)
                        if let sub = kpi["sub"]?.nonEmptyString {
                            Text(sub).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.tertiarySystemFill).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { if let link = kpi["link"]?.nonEmptyString { actions.open(link) } }
                }
            }
            ForEach(Array((data["insights"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, insight in
                VStack(alignment: .leading, spacing: 4) {
                    Label(insight["title"]?.stringValue ?? "", systemImage: "lightbulb.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AriaTone.named(insight["tone"]?.stringValue ?? "warn"))
                    Text(AriaMarkdown.inline(insight["body"]?.stringValue ?? "")).font(.footnote)
                    if let action = insight["action"], let label = action["label"]?.nonEmptyString,
                       let prompt = action["prompt"]?.nonEmptyString {
                        Button(label) { actions.ask(prompt) }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}

// MARK: - Grafico

struct AriaChartArtifact: View {
    let data: [String: AriaJSON]
    var framed = true

    private var points: [AriaArtifactContent.ChartPoint] { AriaArtifactContent.chartPoints(data) }

    var body: some View {
        if framed {
            AriaCard { content }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let title = data["title"]?.nonEmptyString {
            Text(title).font(.subheadline.weight(.semibold))
        }
        if points.isEmpty {
            Text(data["empty_hint"]?.nonEmptyString ?? String(localized: "No data for this period."))
                .font(.footnote).foregroundStyle(.secondary)
        } else {
            switch data["type"]?.stringValue {
            case "line":
                Chart(points) {
                    LineMark(x: .value("x", $0.x), y: .value("y", $0.y)).foregroundStyle(Color.liteAccent)
                    PointMark(x: .value("x", $0.x), y: .value("y", $0.y)).foregroundStyle(Color.liteAccent)
                }
                .frame(height: 200)
            case "pie":
                Chart(points) {
                    SectorMark(angle: .value("y", $0.y), innerRadius: .ratio(0.55), angularInset: 1.5)
                        .foregroundStyle(by: .value("x", $0.x))
                }
                .frame(height: 220)
            default:
                Chart(points) {
                    BarMark(x: .value("x", $0.x), y: .value("y", $0.y)).foregroundStyle(Color.liteAccent.gradient)
                }
                .frame(height: 200)
            }
        }
    }
}

// MARK: - Asset / piano / diagnostica / allarme

struct AriaAssetCard: View {
    let data: [String: AriaJSON]

    var body: some View {
        AriaCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data["tag"]?.stringValue ?? "").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    Text(data["name"]?.stringValue ?? data["tag"]?.stringValue ?? "").font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "gearshape.2.fill").foregroundStyle(Color.liteAccent)
            }
            AriaBadgeRow {
                if let status = data["operational_status"]?.nonEmptyString { AriaBadge(text: status) }
                if let criticality = data["criticality"]?.nonEmptyString { AriaBadge(text: criticality, tint: AriaTone.priority(criticality)) }
            }
            if let description = data["description"]?.nonEmptyString {
                Text(description).font(.footnote).foregroundStyle(.secondary)
            }
            AriaFactRow(label: "Category", value: data["category"]?.nonEmptyString)
            AriaFactRow(label: "Zone", value: data["zone"]?.nonEmptyString)
            AriaFactRow(label: "Manufacturer", value: data["manufacturer"]?.nonEmptyString)
            AriaFactRow(label: "Model", value: data["model"]?.nonEmptyString)
            AriaFactRow(label: "Serial number", value: data["serial_number"]?.nonEmptyString)
        }
    }
}

struct AriaPlanCard: View {
    let data: [String: AriaJSON]

    var body: some View {
        AriaCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Maintenance plan").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    Text(data["name"]?.stringValue ?? "").font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "calendar.badge.clock").foregroundStyle(Color.liteAccent)
            }
            AriaBadgeRow {
                if let frequency = data["frequency"]?.nonEmptyString { AriaBadge(text: frequency) }
                if let status = data["status"]?.nonEmptyString { AriaBadge(text: status) }
            }
            if let description = data["description"]?.nonEmptyString {
                Text(description).font(.footnote).foregroundStyle(.secondary)
            }
            AriaFactRow(label: "Asset", value: data["asset_tag"]?.nonEmptyString)
            AriaFactRow(label: "Category", value: data["category"]?.nonEmptyString)
            AriaFactRow(label: "Estimated duration", value: data["estimated_duration_min"]?.doubleValue.map { "\(Int($0)) min" })
            if let checklist = data["checklist"] {
                AriaBulletSection(title: "Steps", items: strings(checklist["steps"]), icon: "circle", tint: .liteAccent)
            }
        }
    }
}

struct AriaDiagnosticCard: View {
    let data: [String: AriaJSON]
    var actions = AriaArtifactActions()

    var body: some View {
        AriaCard(tint: .orange) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diagnostic · \(data["alarm_code"]?.stringValue ?? "")")
                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    if let description = data["alarm_description"]?.nonEmptyString {
                        Text(description).font(.subheadline.weight(.semibold))
                    }
                }
                Spacer()
                if let confidence = data["confidence"]?.doubleValue {
                    AriaBadge(text: "\(Int((confidence <= 1 ? confidence * 100 : confidence).rounded()))%", tint: .liteAccent)
                }
            }
            AriaBadgeRow {
                if let severity = data["severity"]?.nonEmptyString { AriaBadge(text: severity, tint: AriaTone.priority(severity)) }
                if let asset = data["asset_tag"]?.nonEmptyString { AriaBadge(text: asset) }
            }
            if let cause = data["root_cause"]?.nonEmptyString {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Probable root cause").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    Text(AriaMarkdown.inline(cause)).font(.footnote)
                }
            }
            AriaBulletSection(title: "Failure modes", items: strings(data["failure_modes"]))
            AriaBulletSection(title: "Recommended actions", items: strings(data["recommended_actions"]), icon: "checkmark.circle", tint: .green)
            AriaBulletSection(title: "Spare parts", items: (data["spare_parts_needed"]?.arrayValue ?? []).compactMap { part in
                let name = part["name"]?.nonEmptyString ?? part["code"]?.nonEmptyString
                let stock = part["stock"]?.doubleValue.map { " · \(String(localized: "stock")) \(Int($0))" } ?? ""
                return name.map { $0 + stock }
            })
            if let code = data["alarm_code"]?.nonEmptyString {
                Button("Regenerate diagnostic", systemImage: "arrow.clockwise") {
                    actions.quick("/diag \(code) --force", "diagnose_alarm",
                                  ["code": .string(code), "include_rag": .bool(true), "force_refresh": .bool(true)])
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.borderless)
            }
        }
    }
}

struct AriaAlarmCard: View {
    let data: [String: AriaJSON]

    private var critical: Bool { (data["severity"]?.doubleValue ?? 0) >= 3 }

    var body: some View {
        AriaCard(tint: critical ? .red : .orange) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data["alarm_code"]?.stringValue ?? "").font(.subheadline.weight(.semibold))
                    Text(data["alarm_description"]?.stringValue ?? "").font(.footnote)
                    Text([data["source"]?.stringValue, AriaDate.parse(data["timestamp"]?.stringValue)?.formatted(date: .abbreviated, time: .shortened)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(critical ? .red : .orange)
            }
        }
    }
}

// MARK: - Dashboard

struct AriaDashboardArtifact: View {
    let data: [String: AriaJSON]
    var actions = AriaArtifactActions()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = data["title"]?.nonEmptyString {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline.weight(.bold))
                    if let subtitle = data["subtitle"]?.nonEmptyString {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(Array((data["panels"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, panel in
                let panelData = panel["data"]?.objectValue ?? [:]
                switch panel["kind"]?.stringValue {
                case "chart": AriaChartArtifact(data: panelData)
                case "kpi-grid": AriaKPIGrid(data: panelData, actions: actions)
                default:
                    AriaCard(tint: .red) {
                        Text(panel["title"]?.stringValue ?? panel["type"]?.stringValue ?? "")
                            .font(.footnote.weight(.semibold))
                        Text(panel["error"]?.stringValue ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Liste (pianificazione, simili, ricambi, kanban…)

/// Le card di pianificazione della web in forma compatta: titolo, voci principali, link alla web.
struct AriaListArtifact: View {
    let kind: String
    let data: [String: AriaJSON]
    var actions = AriaArtifactActions()
    @State private var expanded = false

    private var headline: String { AriaArtifactContent.listHeadline(kind: kind, data: data) }
    private var items: [AriaArtifactContent.ListItem] { AriaArtifactContent.listItems(kind: kind, data: data) }

    var body: some View {
        AriaCard {
            Text(AriaMarkdown.inline(headline)).font(.subheadline.weight(.semibold))
            let all = items
            ForEach(Array(all.prefix(expanded ? all.count : 4).enumerated()), id: \.offset) { _, item in
                Button {
                    if let path = item.path { actions.open(path) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.footnote.weight(.medium)).foregroundStyle(.primary)
                        if !item.detail.isEmpty {
                            Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(item.path == nil)
            }
            if all.count > 4 {
                Button(expanded ? "Show less" : "Show all (\(all.count))") {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.borderless)
            }
            if kind == "team-kanban", let url = data["board_url"]?.nonEmptyString {
                Button(data["open_board_label"]?.nonEmptyString ?? String(localized: "Open board")) { actions.open(url) }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
            }
        }
    }
}
