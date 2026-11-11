//
//  AdminMaintenanceImprove.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI": le azioni offerte e la proposta che torna. I valori di `action` sono quelli della web
//  (AIImproveAction in lib/api/cmms-types.ts di aria-web); un valore che il server non conosce torna come
//  {"status": "error"} (vedi AdminAIImproveStatus). La risposta è {"status", "action", "result": {steps,
//  improved_step, reasoning, safety_notes, estimated_duration_min, …}} e si legge con tolleranza.
//

import Foundation

nonisolated enum AdminMaintenanceImproveAction: String, CaseIterable, Identifiable, Sendable {
    case improveAll = "improve_all"
    /// Riscrive il passo `step_index`.
    case improveStep = "improve_step"
    case addSafety = "add_safety"
    case optimizeOrder = "optimize_order"
    case generateFromScratch = "generate_from_scratch"
    /// Traduce i passi nella lingua di `language`.
    case translate = "translate"
    /// Richiesta libera: il testo va in `custom_prompt`.
    case custom = "custom"

    var id: String { rawValue }

    /// Le scorciatoie senza testo né passo da scegliere: senza passi c'è solo da scriverli.
    static func shortcuts(hasSteps: Bool) -> [Self] {
        hasSteps ? [.improveAll, .addSafety, .optimizeOrder, .generateFromScratch] : [.generateFromScratch]
    }

    var title: String {
        switch self {
        case .improveAll: String(localized: "Improve procedure")
        case .improveStep: String(localized: "Improve one step")
        case .addSafety: String(localized: "Add safety checks")
        case .optimizeOrder: String(localized: "Reorder the steps")
        case .generateFromScratch: String(localized: "Write new steps")
        case .translate: String(localized: "Translate")
        case .custom: String(localized: "Custom request")
        }
    }

    var subtitle: String {
        switch self {
        case .improveAll: String(localized: "Clearer, more complete steps")
        case .improveStep: String(localized: "Rewrite the step you pick")
        case .addSafety: String(localized: "Risks and precautions")
        case .optimizeOrder: String(localized: "A more logical, efficient order")
        case .generateFromScratch: String(localized: "A whole new procedure, in place of the current one")
        case .translate: String(localized: "Rewrites the texts in the chosen language")
        case .custom: String(localized: "Ask for something specific")
        }
    }

    var systemImage: String {
        switch self {
        case .improveAll: "wand.and.stars"
        case .improveStep: "list.number"
        case .addSafety: "exclamationmark.shield"
        case .optimizeOrder: "arrow.up.arrow.down"
        case .generateFromScratch: "doc.badge.plus"
        case .translate: "character.bubble"
        case .custom: "text.bubble"
        }
    }
}

/// Quello che l'AI propone per il piano. Ogni parte vuota non si offre.
nonisolated struct AdminMaintenanceProposal: Equatable, Sendable {
    var tasks: [String] = []
    var spareParts: [String] = []
    var description: String?
    var estimatedDurationMin: Int?
    /// Il testo della risposta, se c'è.
    var text: String?
    /// Il JSON grezzo, solo se non si è riconosciuto nient'altro.
    var raw: String?

    var hasChanges: Bool { !tasks.isEmpty || !spareParts.isEmpty || description != nil || estimatedDurationMin != nil }
    var isEmpty: Bool { !hasChanges && text == nil && raw == nil }

    init(tasks: [String] = [], spareParts: [String] = [], description: String? = nil,
         estimatedDurationMin: Int? = nil, text: String? = nil, raw: String? = nil) {
        self.tasks = tasks
        self.spareParts = spareParts
        self.description = description
        self.estimatedDurationMin = estimatedDurationMin
        self.text = text
        self.raw = raw
    }

    /// Legge una risposta qualsiasi: per i campi comuni si appoggia al lettore degli ordini di lavoro
    /// (descrizione, durata, passi, ricambi) e aggiunge `tasks`, il nome che il piano dà ai suoi passi.
    init(json: AriaJSON) {
        let json = json.camelCased()
        let answer = AdminWorkOrderAIAnswer(json: json)
        // "improve_step" manda il solo passo riscritto, come testo: è un passo, anche se va a capo.
        let improvedStep = Self.string("improvedStep", in: json, depth: 0)
        let tasks = improvedStep.map { [$0] }
            ?? Self.list(["tasks", "improvedTasks", "improvedSteps", "newTasks"], in: json, depth: 0)
        // Il perché dei cambiamenti e le note di sicurezza (il piano non ha un campo per queste) si leggono e basta.
        let reasoning = Self.string("reasoning", in: json, depth: 0)
        let safety = answer.suggestion.safetyWarnings
        let safetyText = safety.isEmpty
            ? nil : String(localized: "Safety:") + "\n" + safety.map { "- \($0)" }.joined(separator: "\n")
        let notes = [reasoning ?? answer.text, safetyText].compactMap { $0 }
        self.init(
            tasks: tasks ?? answer.suggestion.steps,
            spareParts: Self.list(["spareParts", "improvedSpareParts"], in: json, depth: 0) ?? answer.suggestion.partsNeeded,
            description: answer.suggestion.description,
            estimatedDurationMin: answer.suggestion.estimatedMinutes,
            text: notes.isEmpty ? nil : notes.joined(separator: "\n\n"),
            raw: answer.raw
        )
        // Se si è trovato qualcosa, il JSON grezzo non serve.
        if hasChanges || text != nil { raw = nil }
    }

    /// Il testo sotto `name`, in cima o dentro un oggetto annidato.
    private static func string(_ name: String, in json: AriaJSON, depth: Int) -> String? {
        guard depth < 4, let object = json.objectValue else { return nil }
        if let text = object[name]?.nonEmptyString { return text }
        for value in object.values where value.objectValue != nil {
            if let found = string(name, in: value, depth: depth + 1) { return found }
        }
        return nil
    }

    /// Il primo elenco con uno dei nomi, in cima o dentro un oggetto annidato.
    private static func list(_ names: [String], in json: AriaJSON, depth: Int) -> [String]? {
        guard depth < 4, let object = json.objectValue else { return nil }
        for name in names {
            if let value = object[name] {
                let items = value.arrayValue.compactMap(itemText)
                if !items.isEmpty { return items }
                if let text = value.nonEmptyString {
                    let lines = text.split(whereSeparator: \.isNewline).map {
                        $0.trimmingCharacters(in: .whitespaces).replacing(/^(\d+[.)]\s*|[-•*]\s*)/, with: "")
                    }.filter { !$0.isEmpty }
                    if !lines.isEmpty { return lines }
                }
            }
        }
        for value in object.values where value.objectValue != nil {
            if let found = list(names, in: value, depth: depth + 1) { return found }
        }
        return nil
    }

    private static func itemText(_ item: AriaJSON) -> String? {
        if let text = item.nonEmptyString { return text }
        guard let object = item.objectValue else { return nil }
        return ["text", "description", "instruction", "title", "name", "step", "action", "content"]
            .lazy.compactMap { object[$0]?.nonEmptyString }.first
    }
}
