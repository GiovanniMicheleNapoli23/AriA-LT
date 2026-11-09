//
//  AdminAgentStudioNodeOptions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Le opzioni di un nodo, per il pannello del canvas: quelle del suo tipo (dagli schemi di
//  StoredWorkflow in openapi.json), quelle comuni a ogni passo (retry, errori, timeout, output),
//  i collegamenti, e in fondo ogni altro campo che il nodo porta, così niente resta nascosto.
//

import Foundation

nonisolated enum AdminAgentStudioNodeOptions {
    struct Section: Identifiable, Hashable {
        let title: String
        let systemImage: String
        let rows: [AdminAssetField]

        var id: String { title }
    }

    static func sections(for node: AdminAgentStudioGraphNode, in graph: AdminAgentStudioGraph) -> [Section] {
        let fields = node.fields
        var sections: [Section] = []
        var shown: Set<String> = ["id", "kind", "type", "position", "label", "data"]

        var main = [AdminAssetField(title: String(localized: "Type"), value: node.meta.label)]
        if let label = fields.string("label") { main.append(AdminAssetField(title: String(localized: "Name"), value: label)) }
        if node.kind == "trigger" {
            main += triggerRows(fields.object("trigger", "data"))
            shown.insert("trigger")
        } else {
            for option in kindOptions(node.kind) {
                shown.insert(option.key)
                main += rows(option, value: fields.value(option.key))
            }
        }
        sections.append(Section(title: String(localized: "Settings"), systemImage: "slider.horizontal.3", rows: main))

        if node.kind != "trigger" && node.meta.isKnown {
            var behaviour: [AdminAssetField] = []
            for option in stepOptions {
                shown.insert(option.key)
                behaviour += rows(option, value: fields.value(option.key))
            }
            if !behaviour.isEmpty {
                sections.append(Section(title: String(localized: "Behaviour"), systemImage: "gearshape.2", rows: behaviour))
            }
        }

        let connections = connectionRows(for: node, in: graph)
        if !connections.isEmpty {
            sections.append(Section(title: String(localized: "Connections"), systemImage: "arrow.triangle.branch", rows: connections))
        }

        // Ogni altro campo, così come arriva: un'opzione nuova della web resta visibile.
        let other = fields.raw.keys.sorted()
            .filter { !shown.contains($0) && !shown.contains(camelCase($0)) }
            .compactMap { key -> AdminAssetField? in
                guard let value = fields.raw[key], let text = format(value) else { return nil }
                return AdminAssetField(title: key, value: text)
            }
        if !other.isEmpty {
            sections.append(Section(title: String(localized: "Other settings"), systemImage: "ellipsis.curlybraces", rows: other))
        }
        return sections
    }

    // MARK: Trigger

    /// "Every day at 07:00", come `describeTrigger` della web.
    static func triggerDescription(_ trigger: AdminAgentStudioFields) -> String? {
        switch trigger.string("type") {
        case "manual":
            return String(localized: "Manual — on demand")
        case "event":
            let event = trigger.string("event").map(eventLabel) ?? String(localized: "an event")
            return String(localized: "When: \(event)")
        case "schedule":
            let time = trigger.string("time") ?? "07:00"
            switch trigger.string("cadence") {
            case "interval": return String(localized: "Every \(trigger.int("intervalMinutes") ?? 60) min")
            case "hourly": return String(localized: "Every hour")
            case "weekly": return String(localized: "Every \(weekday(trigger.int("weekday") ?? 1)) at \(time)")
            default: return String(localized: "Every day at \(time)")
            }
        default:
            return nil
        }
    }

    private static func triggerRows(_ trigger: AdminAgentStudioFields) -> [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Starts"), triggerDescription(trigger))
        if trigger.string("type") == "schedule" { add(String(localized: "Timezone"), trigger.string("timezone")) }
        if trigger.string("type") == "event" { add(String(localized: "Condition"), trigger.string("condition")) }
        return rows
    }

    private static func eventLabel(_ event: String) -> String {
        switch event {
        case "alarm_raised": String(localized: "Alarm raised")
        case "stock_below_threshold": String(localized: "Spare part below reorder point")
        case "work_order_completed": String(localized: "Work order completed")
        case "work_order_created": String(localized: "Work order created")
        case "meter_threshold": String(localized: "Meter crosses threshold")
        case "document_uploaded": String(localized: "Document uploaded")
        default: event.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// 0 = domenica, come `Date.getDay()` della web.
    private static func weekday(_ index: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        return symbols.indices.contains(index) ? symbols[index] : String(index)
    }

    // MARK: Opzioni per tipo

    private struct Option: Sendable {
        let key: String
        let title: String
        /// Come si legge un valore particolare (le azioni, le regole di un router…); `nil` = formato generico.
        var format: (@Sendable (AriaJSON) -> [AdminAssetField])?
    }

    private static func option(_ key: String, _ title: String) -> Option { Option(key: key, title: title) }

    private static func kindOptions(_ kind: String) -> [Option] {
        switch kind {
        case "connector":
            [option("connectorId", String(localized: "Connector")), option("capability", String(localized: "Operation")),
             option("args", String(localized: "Arguments"))]
        case "agent":
            [option("agentName", String(localized: "Agent")), option("task", String(localized: "Task")),
             option("mode", String(localized: "Mode")), option("until", String(localized: "Until")),
             option("maxIterations", String(localized: "Max passes")), option("delegates", String(localized: "Can delegate to")),
             option("tools", String(localized: "Tools")), option("maxTokens", String(localized: "Token budget")),
             option("repeatGuard", String(localized: "Repeat guard")), option("verify", String(localized: "Verify answer"))]
        case "action":
            [Option(key: "actionType", title: String(localized: "Action")) { value in
                [AdminAssetField(title: String(localized: "Action"), value: actionLabel(value.stringValue ?? ""))]
            },
             Option(key: "config", title: String(localized: "Configuration")) { value in
                actionConfigRows(value)
            }]
        case "loop":
            [option("until", String(localized: "Until")), option("maxIterations", String(localized: "Max passes")),
             option("stopWhen", String(localized: "Stop rule")), option("judge", String(localized: "Judge")),
             option("noProgress", String(localized: "Stop on no progress")), option("maxTokens", String(localized: "Token budget")),
             option("maxCostEur", String(localized: "Cost cap (€)")), option("maxSeconds", String(localized: "Time cap (s)"))]
        case "router":
            [option("mode", String(localized: "Mode")), option("match", String(localized: "Match")),
             Option(key: "rules", title: String(localized: "Rules")) { value in routerRuleRows(value) }]
        case "join":
            [option("policy", String(localized: "Wait for")), option("n", String(localized: "Branches")),
             option("merge", String(localized: "Merge"))]
        case "transform":
            [option("op", String(localized: "Operation")), option("spec", String(localized: "Specification"))]
        case "subworkflow":
            [option("workflowId", String(localized: "Workflow")), option("inputMap", String(localized: "Inputs"))]
        case "approval":
            [option("title", String(localized: "Title")), option("instructions", String(localized: "Instructions")),
             option("requiredRole", String(localized: "Required role")), option("approvers", String(localized: "Approvers")),
             option("timeoutMinutes", String(localized: "Timeout (min)")), option("onTimeout", String(localized: "On timeout"))]
        case "orchestrator":
            [option("goal", String(localized: "Goal")), option("allowedAgents", String(localized: "Agents")),
             option("maxSubtasks", String(localized: "Max sub-tasks")), option("mode", String(localized: "Mode")),
             option("maxTokens", String(localized: "Token budget"))]
        case "output":
            [option("title", String(localized: "Title")), option("format", String(localized: "Format")),
             option("sources", String(localized: "Sources")), option("file", String(localized: "File")),
             option("chart", String(localized: "Chart"))]
        default:
            []
        }
    }

    /// Le opzioni che ogni passo ha (StepOptions della web).
    private static let stepOptions: [Option] = [
        option("onError", String(localized: "On error")),
        Option(key: "retry", title: String(localized: "Retry")) { value in
            let retry = AdminAgentStudioFields(value)
            guard let attempts = retry.int("maxAttempts") else { return [] }
            var text = String(localized: "\(attempts) attempts")
            if let backoff = retry.string("backoff") { text += " · \(backoff)" }
            let on = retry.strings("retryOn")
            if !on.isEmpty { text += " · " + on.joined(separator: ", ") }
            return [AdminAssetField(title: String(localized: "Retry"), value: text)]
        },
        option("timeoutSeconds", String(localized: "Timeout (s)")),
        Option(key: "outputSpec", title: String(localized: "Output format")) { value in
            let spec = AdminAgentStudioFields(value)
            guard let format = spec.string("format") else { return [] }
            return [AdminAssetField(title: String(localized: "Output format"), value: format)]
        },
        option("stateKey", String(localized: "Saved as")),
    ]

    private static func rows(_ option: Option, value: AriaJSON?) -> [AdminAssetField] {
        guard let value, value != .null else { return [] }
        if let format = option.format { return format(value) }
        guard let text = format(value) else { return [] }
        return [AdminAssetField(title: option.title, value: text)]
    }

    // MARK: Azioni

    private static func actionLabel(_ type: String) -> String {
        switch type {
        case "notify": String(localized: "Send notification")
        case "email": String(localized: "Send email")
        case "create_work_order": String(localized: "Create work order")
        case "draft_purchase_order": String(localized: "Draft purchase order")
        case "generate_report": String(localized: "Generate report")
        case "post_chat": String(localized: "Post to chat")
        case "webhook": String(localized: "Call webhook")
        default: type.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// `config` è un oggetto con la forma dell'azione (message / to+subject+body / url / description);
    /// le build vecchie lo salvavano come testo.
    private static func actionConfigRows(_ value: AriaJSON) -> [AdminAssetField] {
        if let text = value.nonEmptyString { return [AdminAssetField(title: String(localized: "Configuration"), value: text)] }
        let config = AdminAgentStudioFields(value)
        let labelled: [(String, String)] = [
            ("message", String(localized: "Message")), ("to", String(localized: "To")), ("subject", String(localized: "Subject")),
            ("body", String(localized: "Body")), ("url", String(localized: "URL")), ("description", String(localized: "Description")),
        ]
        return labelled.compactMap { key, title in
            config.string(key).map { AdminAssetField(title: title, value: $0) }
        }
    }

    // MARK: Router

    /// Una riga per regola: il suo nome e la condizione.
    private static func routerRuleRows(_ value: AriaJSON) -> [AdminAssetField] {
        value.arrayValue.enumerated().compactMap { index, rule in
            let fields = AdminAgentStudioFields(rule)
            let title = fields.string("label") ?? String(localized: "rule \(index + 1)")
            let condition = fields.value("when", "rule", "condition").flatMap(format) ?? "—"
            return AdminAssetField(title: title, value: condition)
        }
    }

    // MARK: Collegamenti

    private static func connectionRows(for node: AdminAgentStudioGraphNode, in graph: AdminAgentStudioGraph) -> [AdminAssetField] {
        var rows: [AdminAssetField] = []
        let incoming = graph.edges.filter { $0.target == node.id && $0.style != .loopReturn }
            .compactMap { graph.node(id: $0.source)?.step.title }
        if !incoming.isEmpty {
            rows.append(AdminAssetField(title: String(localized: "After"), value: incoming.joined(separator: ", ")))
        }
        let outgoing = graph.edges.filter { $0.source == node.id && $0.style != .loopReturn }
        // Una riga per uscita: "otherwise → Notify", "on error → Escalate".
        var byCaption: [(caption: String, targets: [String])] = []
        for edge in outgoing {
            guard let target = graph.node(id: edge.target)?.step.title else { continue }
            let caption = edge.caption ?? String(localized: "Then")
            if let index = byCaption.firstIndex(where: { $0.caption == caption }) {
                byCaption[index].targets.append(target)
            } else {
                byCaption.append((caption, [target]))
            }
        }
        for group in byCaption {
            rows.append(AdminAssetField(title: group.caption.prefix(1).uppercased() + group.caption.dropFirst(),
                                        value: group.targets.joined(separator: ", ")))
        }
        return rows
    }

    // MARK: Valori

    /// Un valore in parole: testi così come sono, numeri senza decimali inutili, liste di testi separate da
    /// virgole, oggetti come JSON compatto. `nil` per i valori vuoti.
    static func format(_ value: AriaJSON) -> String? {
        switch value {
        case .null:
            return nil
        case .string:
            return value.nonEmptyString
        case .number(let number):
            return Int(exactly: number).map(String.init) ?? number.formatted()
        case .bool(let flag):
            return flag ? String(localized: "Yes") : String(localized: "No")
        case .array(let items):
            if items.isEmpty { return nil }
            let texts = items.compactMap(\.nonEmptyString)
            if texts.count == items.count { return texts.joined(separator: ", ") }
            return value.compactDescription
        case .object(let object):
            return object.isEmpty ? nil : value.compactDescription
        }
    }

    private static func camelCase(_ key: String) -> String {
        let parts = key.split(separator: "_")
        guard let first = parts.first, parts.count > 1 else { return key }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
}
