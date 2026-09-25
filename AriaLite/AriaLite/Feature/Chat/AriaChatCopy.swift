//
//  AriaChatCopy.swift
//  AriaLite
//
//  Testi della chat presi dalla web app (messages/en.json, it.json):
//  etichette dei tool, suggerimenti, saluti, chip di follow-up.
//  I prompt dei chip vengono mandati ad Aria nella lingua dell'app, come fa la web.
//

import Foundation

enum AriaChatCopy {

    // MARK: Suggerimenti generici (chatSuggestions)

    static var genericSuggestions: [String] {
        [
            String(localized: "Help me clean the belt dryer"),
            String(localized: "Walk me through the belt dryer start-up procedure"),
            String(localized: "What maintenance is due this week?"),
            String(localized: "Show open work orders by priority"),
            String(localized: "Summarise today's downtime and its main causes"),
            String(localized: "What's the next scheduled inspection?"),
            String(localized: "Which spare parts are running low?"),
            String(localized: "How do I safely isolate the fan before access?"),
        ]
    }

    // MARK: Etichette dei tool (agent.toolLabels)

    static func toolLabel(_ name: String) -> String {
        switch name {
        case "kpi_overview": String(localized: "Plant overview")
        case "work_orders_by_status": String(localized: "Work orders by status")
        case "alarm_diagnostic": String(localized: "Alarm diagnostic")
        case "list_work_orders": String(localized: "Searching work orders")
        case "list_alarms": String(localized: "Searching alarms")
        case "list_assets": String(localized: "Searching assets")
        case "list_spare_parts": String(localized: "Searching spare parts")
        case "create_work_order": String(localized: "Creating work order")
        case "create_maintenance_plan": String(localized: "Creating maintenance plan")
        case "diagnose_alarm": String(localized: "Running diagnostic")
        case "get_work_order": String(localized: "Loading work order")
        case "get_asset": String(localized: "Loading asset")
        case "get_alarm": String(localized: "Loading alarm")
        case "search_kb": String(localized: "Searching knowledge base")
        case "search_documentation": String(localized: "Searching documentation")
        case "switch_specialty": String(localized: "Switching specialist")
        case "build_chart": String(localized: "Building chart")
        case "list_overdue_work_orders": String(localized: "Loading overdue WOs")
        case "list_low_stock_parts": String(localized: "Loading low-stock parts")
        case "list_urgent_open_alarms": String(localized: "Loading urgent alarms")
        case "build_kpi_grid": String(localized: "Computing KPIs")
        case "briefing", "daily_briefing": String(localized: "Preparing briefing")
        case "build_dashboard": String(localized: "Building dashboard")
        case "analytics_query": String(localized: "Computing analytics")
        case "suggest_reassignments": String(localized: "Analyzing team load")
        case "suggest_wo_assignment": String(localized: "Suggesting assignment")
        case "find_similar_wo": String(localized: "Finding similar WOs")
        case "recommend_spare_parts": String(localized: "Recommending spare parts")
        case "triage_alarms": String(localized: "Triaging alarms and creating WOs")
        case "reassign_member_workload": String(localized: "Redistributing member workload")
        case "show_team_kanban": String(localized: "Loading team board")
        default: name.replacingOccurrences(of: "_", with: " ").capitalizedFirst
        }
    }

    // MARK: Saluto (chatGreeting, varianti senza nome)

    static func greeting(at date: Date = .now) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)  // 1 = domenica
        var pool: [String]
        switch hour {
        case 0..<5, 22...23:
            pool = [String(localized: "Still on the line at this hour?"), String(localized: "Quiet hours, anything to check?")]
        case 5..<12:
            pool = [String(localized: "First coffee of the day?"), String(localized: "How does the plant look this morning?"),
                    String(localized: "What's on the plan today?")]
        case 12..<18:
            pool = [String(localized: "How's the shift going?"), String(localized: "What are we working on?"),
                    String(localized: "Anything open you want to close?")]
        default:
            pool = [String(localized: "How did the day go?"), String(localized: "Wrapping up the shift?"),
                    String(localized: "Anything left before handover?")]
        }
        switch weekday {
        case 2: pool += [String(localized: "New week — where do we start?"), String(localized: "How did the weekend leave the line?")]
        case 6: pool.append(String(localized: "Closing out the week?"))
        case 1, 7: pool += [String(localized: "Weekend shift?"), String(localized: "Quiet weekend on the plant?")]
        default: break
        }
        pool += [String(localized: "How can I help you today?"), String(localized: "Where would you like to start?"),
                 String(localized: "What's happening on the plant?"), String(localized: "Which machine do we start from?")]

        // Mai la stessa frase due volte di fila.
        let last = UserDefaults.standard.string(forKey: "aria.chat.last_greeting")
        let pick = pool.filter { $0 != last }.randomElement() ?? pool[0]
        UserDefaults.standard.set(pick, forKey: "aria.chat.last_greeting")
        return pick
    }

    // MARK: Pulsanti delle azioni (ctaLabelKey della web)

    static func actionLabel(for action: AriaUIAction) -> String {
        if action.action == "open-external" { return String(localized: "Open in MaintainX") }
        let path = action.to ?? ""
        let segments = path.split(separator: "/").map(String.init)
        let isDetail = segments.count > 1
        switch segments.first ?? "" {
        case "work-orders": return isDetail ? String(localized: "Open work order") : String(localized: "All work orders")
        case "assets": return String(localized: "Open asset")
        case "alarms", "alarms-inbox": return String(localized: "Open alarms")
        case "maintenance": return String(localized: "Open maintenance")
        case "purchases", "purchase-orders": return String(localized: "Open purchases")
        case "spare-parts": return String(localized: "Open spare parts")
        case "inspections": return String(localized: "Open inspections")
        case "taskboard", "board": return String(localized: "Open board")
        case "reports": return String(localized: "Open reports")
        case "plants": return String(localized: "Open plants")
        default: return String(localized: "Open")
        }
    }

    // MARK: Chip di follow-up (suggestion-chips.tsx)

    struct FollowUp: Hashable {
        let label: String
        let prompt: String
    }

    static func followUps(for message: AriaAgentMessage) -> [FollowUp] {
        var chips: [FollowUp] = []
        for artifact in message.artifacts {
            let d = artifact.data
            switch artifact.kind {
            case "wo-card":
                guard let id = d["id"]?.stringValue else { continue }
                let status = d["status"]?.stringValue ?? ""
                guard status != "completed", status != "verified" else { continue }
                chips.append(FollowUp(label: String(localized: "Who and when"),
                                      prompt: String(localized: "Suggest who to assign WO \(id) to and when")))
                chips.append(FollowUp(label: String(localized: "Parts needed?"),
                                      prompt: String(localized: "Which spare parts are needed for WO \(id)?")))
                chips.append(FollowUp(label: String(localized: "Similar cases"),
                                      prompt: String(localized: "Show me historical WOs similar to \(id)")))
                if status != "in_progress" {
                    chips.append(FollowUp(label: String(localized: "Start work"),
                                          prompt: String(localized: "Update WO \(id) to in_progress")))
                }
                if let asset = d["asset_tag"]?.stringValue {
                    chips.append(FollowUp(label: String(localized: "More WOs on \(asset)"),
                                          prompt: String(localized: "List work orders on asset \(asset)")))
                }
            case "chart":
                let title = d["title"]?.stringValue ?? ""
                let range = artifact.source?.toolArgs?["range"]?.stringValue
                if range == "30d" {
                    chips.append(FollowUp(label: String(localized: "Last 7 days"),
                                          prompt: String(localized: "\(title) but in the last 7 days")))
                } else {
                    chips.append(FollowUp(label: String(localized: "Widen to 30 days"),
                                          prompt: String(localized: "\(title) but in the last 30 days")))
                }
            case "table":
                if d["row_link_template"]?.stringValue?.contains("/work-orders/") == true,
                   case .array(let rows)? = d["rows"], let id = rows.first?["id"]?.stringValue {
                    chips.append(FollowUp(label: String(localized: "Details of the first WO"),
                                          prompt: String(localized: "Give me the details of WO \(id)")))
                }
            case "asset-card":
                guard let tag = d["tag"]?.stringValue else { continue }
                if tag.range(of: #"^[A-Z]{1,3}\d{3,}"#, options: [.regularExpression, .caseInsensitive]) != nil {
                    chips.append(FollowUp(label: String(localized: "Full diagnostic"),
                                          prompt: String(localized: "Full diagnostic for alarm \(tag)")))
                }
                chips.append(FollowUp(label: String(localized: "WOs on this asset"),
                                      prompt: String(localized: "List work orders on asset \(tag)")))
                chips.append(FollowUp(label: String(localized: "Create WO"),
                                      prompt: String(localized: "Create a work order for asset \(tag)")))
            case "alarm-toast":
                guard let code = d["alarm_code"]?.stringValue else { continue }
                chips.append(FollowUp(label: String(localized: "Diagnose now"),
                                      prompt: String(localized: "Full diagnostic for alarm \(code)")))
                chips.append(FollowUp(label: String(localized: "Open alarm"),
                                      prompt: String(localized: "Open details of alarm \(code)")))
            case "diagnostic-card":
                if let suggested = d["suggested_work_order"], let title = suggested["title"]?.stringValue {
                    let description = suggested["description"]?.stringValue.map { ": \($0)" } ?? ""
                    chips.append(FollowUp(label: String(localized: "Create the suggested WO"),
                                          prompt: String(localized: "Create a work order titled \"\(title)\"\(description)")))
                }
                if let code = d["alarm_code"]?.stringValue {
                    chips.append(FollowUp(label: String(localized: "History of \(code)"),
                                          prompt: String(localized: "List work orders with alarm code \(code)")))
                }
            case "kpi-grid":
                chips.append(FollowUp(label: String(localized: "Overdue WOs in detail"),
                                      prompt: String(localized: "List overdue work orders")))
                chips.append(FollowUp(label: String(localized: "Low-stock parts"),
                                      prompt: String(localized: "Show low-stock parts")))
            default:
                break
            }
        }
        if chips.isEmpty, message.artifacts.isEmpty, !message.displayText.isEmpty {
            chips.append(FollowUp(label: String(localized: "Dive deeper"),
                                  prompt: String(localized: "Dive deeper on the previous point")))
        }
        var seen = Set<String>()
        return Array(chips.filter { seen.insert($0.prompt).inserted }.prefix(4))
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
