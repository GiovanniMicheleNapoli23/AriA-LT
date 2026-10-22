//
//  AriaArtifactContent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si leggono i dati delle card che Aria manda in chat (`aria.ui_artifact`): colonne e righe delle
//  tabelle, punti dei grafici, voci delle liste di pianificazione. Stessi campi della web (types/agent-stream.ts).
//

import Foundation

enum AriaArtifactContent {
    // MARK: - Tabella

    struct TableColumn: Hashable {
        let key: String
        let label: String
    }

    static func tableColumns(_ data: [String: AriaJSON]) -> [TableColumn] {
        data["columns"]?.arrayValue.compactMap { c in
            c["key"]?.stringValue.map { TableColumn(key: $0, label: c["label"]?.stringValue ?? $0) }
        } ?? []
    }

    static func tableRows(_ data: [String: AriaJSON]) -> [[String: AriaJSON]] {
        data["rows"]?.arrayValue.compactMap(\.objectValue) ?? []
    }

    /// row_link_template: "/work-orders/{id}" → pagina della web, con i valori della riga.
    static func rowLink(_ data: [String: AriaJSON], row: [String: AriaJSON]) -> String? {
        guard var path = data["row_link_template"]?.nonEmptyString else { return nil }
        for (key, value) in row { path = path.replacingOccurrences(of: "{\(key)}", with: value.stringValue ?? "") }
        return path
    }

    // MARK: - Grafico

    struct ChartPoint: Identifiable, Hashable {
        let id: Int
        let x: String
        let y: Double
    }

    /// I punti della serie: le chiavi di x e y le dice la card (`x_key`, `y_key`); senza y il punto si salta.
    static func chartPoints(_ data: [String: AriaJSON]) -> [ChartPoint] {
        let xKey = data["x_key"]?.stringValue ?? "x"
        let yKey = data["y_key"]?.stringValue ?? "y"
        return (data["series"]?.arrayValue ?? []).enumerated().compactMap { i, row in
            guard let y = row[yKey]?.doubleValue else { return nil }
            return ChartPoint(id: i, x: row[xKey]?.stringValue ?? "\(i)", y: y)
        }
    }

    // MARK: - Liste di pianificazione

    struct ListItem: Hashable {
        let title: String
        let detail: String
        /// Pagina della web da aprire con un tocco, se c'è.
        let path: String?
    }

    static func listHeadline(kind: String, data: [String: AriaJSON]) -> String {
        data["headline"]?.nonEmptyString ?? data["title"]?.nonEmptyString ?? data["summary"]?.nonEmptyString ?? kind
    }

    static func listItems(kind: String, data: [String: AriaJSON]) -> [ListItem] {
        switch kind {
        case "reassignment-plan":
            return (data["moves"]?.arrayValue ?? []).map { m in
                ListItem(title: m["wo_title"]?.stringValue ?? "",
                         detail: [m["from_team_name"]?.stringValue, "→", m["to_team_name"]?.stringValue].compactMap { $0 }.joined(separator: " "),
                         path: m["wo_id"]?.stringValue.map { "/work-orders/\($0)" })
            }
        case "member-absence-plan":
            return (data["moves"]?.arrayValue ?? []).map { m in
                ListItem(title: m["wo_title"]?.stringValue ?? "",
                         detail: [m["from_name"]?.stringValue, "→", m["to_name"]?.stringValue].compactMap { $0 }.joined(separator: " "),
                         path: m["wo_id"]?.stringValue.map { "/work-orders/\($0)" })
            }
        case "assignment-suggestion":
            return (data["candidates"]?.arrayValue ?? []).map { c in
                ListItem(title: c["member_name"]?.stringValue ?? c["team_name"]?.stringValue ?? "",
                         detail: [c["team_name"]?.stringValue, c["suggested_due_date"]?.stringValue, c["motivation"]?.stringValue]
                            .compactMap { $0 }.joined(separator: " · "),
                         path: nil)
            }
        case "similar-wo-list":
            return (data["items"]?.arrayValue ?? []).map { w in
                ListItem(title: w["title"]?.stringValue ?? "",
                         detail: [w["status"]?.stringValue, w["asset_tag"]?.stringValue, w["resolution_notes"]?.nonEmptyString]
                            .compactMap { $0 }.joined(separator: " · "),
                         path: w["wo_id"]?.stringValue.map { "/work-orders/\($0)" })
            }
        case "spare-parts-recommendation":
            return (data["items"]?.arrayValue ?? []).map { p in
                let stock = p["stock_quantity"]?.doubleValue.map { "\(String(localized: "stock")) \(Int($0))" }
                return ListItem(title: p["name"]?.stringValue ?? p["code"]?.stringValue ?? "",
                                detail: [p["code"]?.stringValue, stock, p["low_stock"]?.boolValue == true ? String(localized: "low stock") : nil]
                                    .compactMap { $0 }.joined(separator: " · "),
                                path: nil)
            }
        case "triage-plan":
            return (data["alarms"]?.arrayValue ?? []).map { a in
                ListItem(title: a["alarm_code"]?.stringValue ?? "",
                         detail: a["suggested_work_order"]?["title"]?.stringValue ?? "",
                         path: a["wo_id"]?.stringValue.map { "/work-orders/\($0)" })
            }
        case "team-kanban":
            return (data["columns"]?.arrayValue ?? []).map { c in
                let titles = (c["wos"]?.arrayValue ?? []).prefix(3).compactMap { $0["title"]?.stringValue }
                return ListItem(title: "\(c["title"]?.stringValue ?? "") · \(c["count"]?.stringValue ?? "0")",
                                detail: titles.joined(separator: ", "), path: nil)
            }
        default:
            return []
        }
    }
}
