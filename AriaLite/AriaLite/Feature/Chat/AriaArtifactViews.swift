//
//  AriaArtifactViews.swift
//  AriaLite
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
                .font(.system(size: 12, design: .monospaced))
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
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

    var body: some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(value).font(.system(size: 13, weight: .medium)).multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct AriaBulletSection: View {
    let title: LocalizedStringKey
    let items: [String]
    var icon = "circle.fill"
    var tint: Color = .secondary

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Label {
                        Text(AriaMarkdown.inline(item)).font(.system(size: 13))
                    } icon: {
                        Image(systemName: icon).font(.system(size: icon == "circle.fill" ? 4 : 11)).foregroundStyle(tint)
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(data["title"]?.stringValue ?? "")
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                Image(systemName: "wrench.and.screwdriver.fill").foregroundStyle(Color.liteAccent)
            }
            HStack(spacing: 6) {
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
                    .font(.system(size: 13))
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
                .font(.system(size: 13, weight: .medium))
            }
            HStack {
                if let id = data["id"]?.stringValue {
                    Button("Open work order") { actions.open("/work-orders/\(id)") }
                }
                Spacer()
                if let raw = data["external_url"]?.nonEmptyString, let url = URL(string: raw) {
                    Button("Open in MaintainX") { openURL(url) }
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Tabella

struct AriaTableArtifact: View {
    let data: [String: AriaJSON]
    var actions = AriaArtifactActions()

    private var columns: [(key: String, label: String)] {
        data["columns"]?.arrayValue.compactMap { c in
            c["key"]?.stringValue.map { ($0, c["label"]?.stringValue ?? $0) }
        } ?? []
    }

    private var rows: [[String: AriaJSON]] { data["rows"]?.arrayValue.compactMap(\.objectValue) ?? [] }

    var body: some View {
        AriaCard {
            if let title = data["title"]?.nonEmptyString {
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            if rows.isEmpty {
                Text(data["empty_hint"]?.nonEmptyString ?? String(localized: "No results."))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 9) {
                        GridRow {
                            ForEach(columns, id: \.key) { column in
                                Text(column.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(columns, id: \.key) { column in
                                    Text(row[column.key]?.stringValue ?? "—")
                                        .font(.system(size: 13))
                                        .lineLimit(2)
                                        .frame(maxWidth: 220, alignment: .leading)
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
        guard var path = data["row_link_template"]?.nonEmptyString else { return }
        for (key, value) in row { path = path.replacingOccurrences(of: "{\(key)}", with: value.stringValue ?? "") }
        actions.open(path)
    }
}

// MARK: - KPI

struct AriaKPIGrid: View {
    let data: [String: AriaJSON]
    var actions = AriaArtifactActions()

    var body: some View {
        AriaCard {
            if let title = data["title"]?.nonEmptyString {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    if let subtitle = data["subtitle"]?.nonEmptyString {
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array((data["kpis"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, kpi in
                    let tone = AriaTone.named(kpi["tone"]?.stringValue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kpi["label"]?.stringValue ?? "")
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                        Text(kpi["value"]?.stringValue ?? "—")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(tone == .secondary ? Color.primary : tone)
                        if let sub = kpi["sub"]?.nonEmptyString {
                            Text(sub).font(.system(size: 11)).foregroundStyle(.secondary)
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AriaTone.named(insight["tone"]?.stringValue ?? "warn"))
                    Text(AriaMarkdown.inline(insight["body"]?.stringValue ?? "")).font(.system(size: 13))
                    if let action = insight["action"], let label = action["label"]?.nonEmptyString,
                       let prompt = action["prompt"]?.nonEmptyString {
                        Button(label) { actions.ask(prompt) }
                            .font(.system(size: 13, weight: .semibold))
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

    private struct Point: Identifiable {
        let id: Int
        let x: String
        let y: Double
    }

    private var points: [Point] {
        let xKey = data["x_key"]?.stringValue ?? "x"
        let yKey = data["y_key"]?.stringValue ?? "y"
        return (data["series"]?.arrayValue ?? []).enumerated().compactMap { i, row in
            guard let y = row[yKey]?.doubleValue else { return nil }
            return Point(id: i, x: row[xKey]?.stringValue ?? "\(i)", y: y)
        }
    }

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
            Text(title).font(.system(size: 15, weight: .semibold))
        }
        if points.isEmpty {
            Text(data["empty_hint"]?.nonEmptyString ?? String(localized: "No data for this period."))
                .font(.system(size: 13)).foregroundStyle(.secondary)
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
                    Text(data["tag"]?.stringValue ?? "").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text(data["name"]?.stringValue ?? data["tag"]?.stringValue ?? "").font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                Image(systemName: "gearshape.2.fill").foregroundStyle(Color.liteAccent)
            }
            HStack(spacing: 6) {
                if let status = data["operational_status"]?.nonEmptyString { AriaBadge(text: status) }
                if let criticality = data["criticality"]?.nonEmptyString { AriaBadge(text: criticality, tint: AriaTone.priority(criticality)) }
            }
            if let description = data["description"]?.nonEmptyString {
                Text(description).font(.system(size: 13)).foregroundStyle(.secondary)
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
                    Text("Maintenance plan").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text(data["name"]?.stringValue ?? "").font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                Image(systemName: "calendar.badge.clock").foregroundStyle(Color.liteAccent)
            }
            HStack(spacing: 6) {
                if let frequency = data["frequency"]?.nonEmptyString { AriaBadge(text: frequency) }
                if let status = data["status"]?.nonEmptyString { AriaBadge(text: status) }
            }
            if let description = data["description"]?.nonEmptyString {
                Text(description).font(.system(size: 13)).foregroundStyle(.secondary)
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
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    if let description = data["alarm_description"]?.nonEmptyString {
                        Text(description).font(.system(size: 15, weight: .semibold))
                    }
                }
                Spacer()
                if let confidence = data["confidence"]?.doubleValue {
                    AriaBadge(text: "\(Int((confidence <= 1 ? confidence * 100 : confidence).rounded()))%", tint: .liteAccent)
                }
            }
            HStack(spacing: 6) {
                if let severity = data["severity"]?.nonEmptyString { AriaBadge(text: severity, tint: AriaTone.priority(severity)) }
                if let asset = data["asset_tag"]?.nonEmptyString { AriaBadge(text: asset) }
            }
            if let cause = data["root_cause"]?.nonEmptyString {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Probable root cause").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    Text(AriaMarkdown.inline(cause)).font(.system(size: 13))
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
                .font(.system(size: 13, weight: .medium))
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
                    Text(data["alarm_code"]?.stringValue ?? "").font(.system(size: 15, weight: .semibold))
                    Text(data["alarm_description"]?.stringValue ?? "").font(.system(size: 13))
                    Text([data["source"]?.stringValue, AriaDate.parse(data["timestamp"]?.stringValue)?.formatted(date: .abbreviated, time: .shortened)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
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
                    Text(title).font(.system(size: 17, weight: .bold))
                    if let subtitle = data["subtitle"]?.nonEmptyString {
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
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
                            .font(.system(size: 13, weight: .semibold))
                        Text(panel["error"]?.stringValue ?? "").font(.system(size: 12)).foregroundStyle(.secondary)
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

    private struct Item: Hashable {
        let title: String
        let detail: String
        let path: String?
    }

    private var headline: String {
        data["headline"]?.nonEmptyString ?? data["title"]?.nonEmptyString ?? data["summary"]?.nonEmptyString ?? kind
    }

    private var items: [Item] {
        switch kind {
        case "reassignment-plan":
            return (data["moves"]?.arrayValue ?? []).map { m in
                Item(title: m["wo_title"]?.stringValue ?? "",
                     detail: [m["from_team_name"]?.stringValue, "→", m["to_team_name"]?.stringValue].compactMap { $0 }.joined(separator: " "),
                     path: m["wo_id"]?.stringValue.map { "/work-orders/\($0)" })
            }
        case "member-absence-plan":
            return (data["moves"]?.arrayValue ?? []).map { m in
                Item(title: m["wo_title"]?.stringValue ?? "",
                     detail: [m["from_name"]?.stringValue, "→", m["to_name"]?.stringValue].compactMap { $0 }.joined(separator: " "),
                     path: m["wo_id"]?.stringValue.map { "/work-orders/\($0)" })
            }
        case "assignment-suggestion":
            return (data["candidates"]?.arrayValue ?? []).map { c in
                Item(title: c["member_name"]?.stringValue ?? c["team_name"]?.stringValue ?? "",
                     detail: [c["team_name"]?.stringValue, c["suggested_due_date"]?.stringValue, c["motivation"]?.stringValue]
                        .compactMap { $0 }.joined(separator: " · "),
                     path: nil)
            }
        case "similar-wo-list":
            return (data["items"]?.arrayValue ?? []).map { w in
                Item(title: w["title"]?.stringValue ?? "",
                     detail: [w["status"]?.stringValue, w["asset_tag"]?.stringValue, w["resolution_notes"]?.nonEmptyString]
                        .compactMap { $0 }.joined(separator: " · "),
                     path: w["wo_id"]?.stringValue.map { "/work-orders/\($0)" })
            }
        case "spare-parts-recommendation":
            return (data["items"]?.arrayValue ?? []).map { p in
                let stock = p["stock_quantity"]?.doubleValue.map { "\(String(localized: "stock")) \(Int($0))" }
                return Item(title: p["name"]?.stringValue ?? p["code"]?.stringValue ?? "",
                            detail: [p["code"]?.stringValue, stock, p["low_stock"]?.boolValue == true ? String(localized: "low stock") : nil]
                                .compactMap { $0 }.joined(separator: " · "),
                            path: nil)
            }
        case "triage-plan":
            return (data["alarms"]?.arrayValue ?? []).map { a in
                Item(title: a["alarm_code"]?.stringValue ?? "",
                     detail: a["suggested_work_order"]?["title"]?.stringValue ?? "",
                     path: a["wo_id"]?.stringValue.map { "/work-orders/\($0)" })
            }
        case "team-kanban":
            return (data["columns"]?.arrayValue ?? []).map { c in
                let titles = (c["wos"]?.arrayValue ?? []).prefix(3).compactMap { $0["title"]?.stringValue }
                return Item(title: "\(c["title"]?.stringValue ?? "") · \(c["count"]?.stringValue ?? "0")",
                            detail: titles.joined(separator: ", "), path: nil)
            }
        default:
            return []
        }
    }

    var body: some View {
        AriaCard {
            Text(AriaMarkdown.inline(headline)).font(.system(size: 15, weight: .semibold))
            let all = items
            ForEach(Array(all.prefix(expanded ? all.count : 4).enumerated()), id: \.offset) { _, item in
                Button {
                    if let path = item.path { actions.open(path) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                        if !item.detail.isEmpty {
                            Text(item.detail).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
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
                .font(.system(size: 13, weight: .medium))
                .buttonStyle(.borderless)
            }
            if kind == "team-kanban", let url = data["board_url"]?.nonEmptyString {
                Button(data["open_board_label"]?.nonEmptyString ?? String(localized: "Open board")) { actions.open(url) }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.borderless)
            }
        }
    }
}
