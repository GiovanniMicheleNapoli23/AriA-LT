//
//  AdminWorkOrderAIAnswer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La risposta di ai-assist e ai-draft letta senza schema: l'OpenAPI non la descrive. Si cerca un testo
//  da mostrare e i valori dei campi proposti (titolo, descrizione, priorità, durata, passi…) sotto i nomi
//  più probabili, in cima o dentro `suggestions`/`draft`/`data`/`result`. Se non si riconosce nulla resta
//  il JSON grezzo, così l'utente vede comunque cosa ha risposto il server.
//

import Foundation

/// I valori dei campi che l'AI propone. Vuoto = solo testo.
nonisolated struct AdminWorkOrderAISuggestion: Equatable, Sendable {
    var title: String?
    var description: String?
    var category: String?
    var notes: String?
    var priority: AdminWorkOrderPriority?
    var type: AdminWorkOrderType?
    var estimatedMinutes: Int?
    var steps: [String] = []
    var safetyWarnings: [String] = []
    var toolsNeeded: [String] = []
    var partsNeeded: [String] = []

    /// Campi che si possono scrivere sull'ordine o nel form.
    var hasFieldValues: Bool {
        title != nil || description != nil || category != nil || notes != nil
            || priority != nil || type != nil || estimatedMinutes != nil
    }

    /// Elenchi che non hanno un campo proprio (passi, sicurezza, attrezzi, ricambi).
    var hasLists: Bool {
        !steps.isEmpty || !safetyWarnings.isEmpty || !toolsNeeded.isEmpty || !partsNeeded.isEmpty
    }

    var isEmpty: Bool { !hasFieldValues && !hasLists }

    /// Gli elenchi come testo semplice, a blocchi con titolo: va in fondo a una descrizione o nelle note.
    var listsText: String? {
        var blocks: [String] = []
        if !steps.isEmpty {
            blocks.append(String(localized: "Steps:") + "\n"
                          + steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        }
        func bullets(_ title: String, _ items: [String]) {
            guard !items.isEmpty else { return }
            blocks.append(title + "\n" + items.map { "- \($0)" }.joined(separator: "\n"))
        }
        bullets(String(localized: "Safety:"), safetyWarnings)
        bullets(String(localized: "Tools:"), toolsNeeded)
        bullets(String(localized: "Parts:"), partsNeeded)
        return blocks.isEmpty ? nil : blocks.joined(separator: "\n\n")
    }
}

nonisolated struct AdminWorkOrderAIAnswer: Equatable, Sendable {
    /// Il testo della risposta (markdown leggero), se c'è.
    var text: String?
    var suggestion: AdminWorkOrderAISuggestion
    /// Il JSON grezzo, solo quando non si è riconosciuto nient'altro.
    var raw: String?

    var isEmpty: Bool { text == nil && suggestion.isEmpty && raw == nil }

    init(text: String?, suggestion: AdminWorkOrderAISuggestion = .init(), raw: String? = nil) {
        self.text = text
        self.suggestion = suggestion
        self.raw = raw
    }

    /// Legge una risposta qualsiasi. Le chiavi si portano in camelCase prima di cercarle: il decoder
    /// `.snakeCased()` può averle già convertite oppure no.
    init(json: AriaJSON) {
        let json = json.camelCased()
        var parser = AdminWorkOrderAIAnswerParser()
        parser.read(json, depth: 0)
        var text = parser.text
        // Un testo identico alla descrizione proposta si mostra una volta sola.
        if text != nil, text == parser.suggestion.description { text = nil }
        self.text = text
        suggestion = parser.suggestion
        raw = (text == nil && parser.suggestion.isEmpty) ? Self.pretty(json) : nil
    }

    private static func pretty(_ json: AriaJSON) -> String? {
        if case .null = json { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(json) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        return text.isEmpty ? nil : text
    }
}

// MARK: - Lettura

private nonisolated struct AdminWorkOrderAIAnswerParser {
    var text: String?
    var suggestion = AdminWorkOrderAISuggestion()

    private static let textKeys = ["answer", "text", "content", "message", "result", "response", "output", "summary",
                                   "analysis", "explanation", "reply", "markdown", "improved", "improvedText",
                                   "suggestion", "recommendation", "recommendations"]
    private static let nestedKeys = ["suggestions", "suggestion", "fields", "draft", "workOrder", "data", "result",
                                     "proposal", "proposed", "improved", "output", "response", "changes"]

    mutating func read(_ json: AriaJSON, depth: Int) {
        guard depth < 3 else { return }
        switch json {
        case .string(let string):
            readText(string, depth: depth)
        case .array(let items):
            // Un elenco di righe è una risposta a punti.
            let lines = items.compactMap(Self.itemText)
            if text == nil, !lines.isEmpty { text = lines.map { "- \($0)" }.joined(separator: "\n") }
        case .object(let object):
            readFields(object)
            if text == nil {
                text = Self.textKeys.lazy.compactMap { object[$0]?.nonEmptyString }.first
                    .flatMap { Self.embeddedJSON($0) == nil ? $0 : nil }
            }
            // Una stringa che contiene a sua volta JSON (anche fra ``` ```) si legge come oggetto.
            for key in Self.textKeys {
                if let string = object[key]?.nonEmptyString, let inner = Self.embeddedJSON(string) {
                    read(inner, depth: depth + 1)
                }
            }
            for key in Self.nestedKeys {
                if let inner = object[key], inner.objectValue != nil { read(inner, depth: depth + 1) }
            }
        default:
            break
        }
    }

    private mutating func readText(_ string: String, depth: Int) {
        if let inner = Self.embeddedJSON(string) {
            read(inner, depth: depth + 1)
        } else if text == nil {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { text = trimmed }
        }
    }

    /// I campi noti di un oggetto; quelli già trovati più in alto restano.
    private mutating func readFields(_ o: [String: AriaJSON]) {
        func string(_ keys: [String]) -> String? { keys.lazy.compactMap { o[$0]?.nonEmptyString }.first }
        func list(_ keys: [String]) -> [String] {
            for key in keys {
                guard let value = o[key] else { continue }
                let items: [String]
                switch value {
                case .array(let array): items = array.compactMap(Self.itemText)
                case .object(let object): items = (object["steps"] ?? object["items"])?.arrayValue.compactMap(Self.itemText) ?? []
                case .string(let s): items = Self.lines(s)
                default: items = []
                }
                if !items.isEmpty { return items }
            }
            return []
        }

        var s = suggestion
        s.title = s.title ?? string(["title", "improvedTitle", "suggestedTitle", "newTitle"])
        s.description = s.description ?? string(["description", "improvedDescription", "suggestedDescription",
                                                 "newDescription", "descriptionImproved"])
        s.category = s.category ?? string(["category", "suggestedCategory"])
        s.notes = s.notes ?? string(["notes", "suggestedNotes"])
        s.priority = s.priority ?? string(["priority", "suggestedPriority"]).flatMap(Self.priority)
        s.type = s.type ?? string(["type", "workOrderType", "suggestedType"]).flatMap(Self.type)
        s.estimatedMinutes = s.estimatedMinutes ?? minutes(o)
        if s.steps.isEmpty { s.steps = list(["steps", "procedureSteps", "procedure", "checklist", "checklistItems"]) }
        if s.safetyWarnings.isEmpty {
            s.safetyWarnings = list(["safetyWarnings", "safety", "safetyNotes", "warnings", "hazards", "precautions"])
        }
        if s.toolsNeeded.isEmpty { s.toolsNeeded = list(["toolsNeeded", "tools", "requiredTools"]) }
        if s.partsNeeded.isEmpty { s.partsNeeded = list(["partsNeeded", "parts", "spareParts", "suggestedParts", "requiredParts"]) }
        suggestion = s
    }

    private func minutes(_ o: [String: AriaJSON]) -> Int? {
        for key in ["estimatedDurationMin", "estimatedDurationMinutes", "estimatedMinutes", "durationMin",
                    "durationMinutes", "estimatedDuration", "duration", "minutes"] {
            if let value = o[key], let minutes = Self.minutes(value, unitMinutes: 1) { return minutes }
        }
        for key in ["estimatedHours", "estimatedDurationHours", "durationHours", "hours"] {
            if let value = o[key], let minutes = Self.minutes(value, unitMinutes: 60) { return minutes }
        }
        return nil
    }

    // MARK: Valori

    /// Un numero, o un testo come "90", "90 min", "1.5 h", "1h 30m", "2 ore".
    static func minutes(_ value: AriaJSON, unitMinutes: Double) -> Int? {
        if case .number(let number) = value {
            let total = Int((number * unitMinutes).rounded())
            return total > 0 ? total : nil
        }
        guard let text = value.nonEmptyString?.lowercased() else { return nil }
        if let number = Double(text.replacingOccurrences(of: ",", with: ".")) {
            return minutes(.number(number), unitMinutes: unitMinutes)
        }
        var total = 0.0
        var found = false
        for match in text.matches(of: /(\d+(?:[.,]\d+)?)\s*([a-z]*)/) {
            guard let number = Double(String(match.output.1).replacingOccurrences(of: ",", with: ".")) else { continue }
            let unit = String(match.output.2)
            let factor: Double = if unit.hasPrefix("h") || unit.hasPrefix("or") { 60 }
                else if unit.isEmpty { unitMinutes }
                else if unit.hasPrefix("m") { 1 }
                else { 0 }
            guard factor > 0 else { continue }
            total += number * factor
            found = true
        }
        let rounded = Int(total.rounded())
        return found && rounded > 0 ? rounded : nil
    }

    static func priority(_ text: String) -> AdminWorkOrderPriority? {
        switch text.lowercased() {
        case "high", "critical", "urgent", "alta", "critica", "urgente": .high
        case "medium", "normal", "media": .medium
        case "low", "bassa": .low
        default: nil
        }
    }

    static func type(_ text: String) -> AdminWorkOrderType? {
        switch text.lowercased() {
        case "reactive", "corrective", "correttiva", "reattiva": .reactive
        case "preventive", "preventiva": .preventive
        default: nil
        }
    }

    /// Una voce di elenco: testo, numero, o un oggetto con un campo di testo.
    static func itemText(_ item: AriaJSON) -> String? {
        if let text = item.nonEmptyString { return text }
        guard let object = item.objectValue else { return nil }
        let text = ["text", "description", "instruction", "title", "name", "step", "action", "content", "warning"]
            .lazy.compactMap { object[$0]?.nonEmptyString }.first
        guard let text else { return nil }
        if let quantity = object["quantity"]?.stringValue ?? object["qty"]?.stringValue { return "\(text) ×\(quantity)" }
        return text
    }

    /// Righe di un testo, senza numeri o trattini in testa.
    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespaces)
                .replacing(/^(\d+[.)]\s*|[-•*]\s*)/, with: "")
        }
        .filter { !$0.isEmpty }
    }

    /// Il JSON dentro un testo (anche in un blocco ```json```), se il testo è solo quello.
    static func embeddedJSON(_ text: String) -> AriaJSON? {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("```") {
            body = body.replacing(/^```[a-zA-Z]*\s*/, with: "").replacing(/\s*```$/, with: "")
        }
        guard body.hasPrefix("{"), body.hasSuffix("}"),
              let json = try? JSONDecoder().decode(AriaJSON.self, from: Data(body.utf8)) else { return nil }
        return json.camelCased()
    }
}
