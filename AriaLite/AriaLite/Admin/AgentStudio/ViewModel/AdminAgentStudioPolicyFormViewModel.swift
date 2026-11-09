//
//  AdminAgentStudioPolicyFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La modifica semplice della policy (/agent-studio/policy della web): limiti di costo, durata, token e
//  frequenza, e i tre interruttori. PUT sostituisce tutto: si rimanda l'oggetto originale con questi campi
//  cambiati, così liste e matrice delle approvazioni restano come sono.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioPolicyFormViewModel: Identifiable {
    let backend: AriaBackend
    let original: AdminAgentStudioPolicy
    let id = UUID()

    var costCeilingEur: String
    var maxRunCostEur: String
    var maxRunSeconds: String
    var maxRunTokens: String
    var maxRunsPerHour: String
    var dataRegion: String
    var requireSafetyReview: Bool
    var classificationLlmFallback: Bool
    var requireValidatorPassForEnable: Bool

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(backend: AriaBackend, policy: AdminAgentStudioPolicy) {
        self.backend = backend
        original = policy
        costCeilingEur = Self.text(policy.costCeilingEur)
        maxRunCostEur = Self.text(policy.maxRunCostEur)
        maxRunSeconds = policy.maxRunSeconds.map(String.init) ?? ""
        maxRunTokens = policy.maxRunTokens.map(String.init) ?? ""
        maxRunsPerHour = policy.maxRunsPerHour.map(String.init) ?? ""
        dataRegion = policy.dataRegion ?? ""
        requireSafetyReview = policy.requireSafetyReview
        classificationLlmFallback = policy.classificationLlmFallback
        requireValidatorPassForEnable = policy.requireValidatorPassForEnable
    }

    // MARK: Validazione

    /// Il primo campo non valido, da mostrare sotto il form; `nil` se si può salvare.
    var validationMessage: String? {
        if Self.integer(maxRunSeconds) == nil || (Self.integer(maxRunSeconds) ?? 0) <= 0 {
            return String(localized: "Max run time must be a whole number of seconds above zero.")
        }
        let decimals = [costCeilingEur, maxRunCostEur]
        if decimals.contains(where: { !Self.isBlank($0) && (Self.decimal($0) ?? -1) < 0 }) {
            return String(localized: "Costs must be numbers of zero or more, or empty for no limit.")
        }
        let integers = [maxRunTokens, maxRunsPerHour]
        if integers.contains(where: { !Self.isBlank($0) && (Self.integer($0) ?? -1) < 0 }) {
            return String(localized: "Token and hourly limits must be whole numbers, or empty for no limit.")
        }
        return nil
    }

    var hasChanges: Bool { changedFields(of: original.raw) != original.raw }

    var canSave: Bool { validationMessage == nil && hasChanges && !isSaving }

    // MARK: Salvataggio

    /// La policy salvata, o `nil` se il server ha rifiutato (il motivo resta in `errorMessage`).
    func save() async -> AdminAgentStudioPolicy? {
        guard canSave else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await backend.api.call(AdminAgentStudioAPI.updatePolicy(changedFields(of: original.raw))).value
            errorMessage = nil
            return saved
        } catch {
            errorMessage = AdminAgentStudioFailure.message(for: error, backend: backend)
            return nil
        }
    }

    /// L'oggetto originale con i campi del form al posto dei vecchi (la variante snake_case, se c'era, si toglie).
    private func changedFields(of raw: [String: AriaJSON]) -> [String: AriaJSON] {
        var body = raw
        func set(_ key: String, _ value: AriaJSON, snake: String) {
            body[snake] = nil
            body[key] = value
        }
        func number(_ value: Double?) -> AriaJSON { value.map(AriaJSON.number) ?? .null }
        set("costCeilingEur", number(Self.decimal(costCeilingEur)), snake: "cost_ceiling_eur")
        set("maxRunCostEur", number(Self.decimal(maxRunCostEur)), snake: "max_run_cost_eur")
        if let seconds = Self.integer(maxRunSeconds) {
            set("maxRunSeconds", .number(Double(seconds)), snake: "max_run_seconds")
        }
        set("maxRunTokens", number(Self.integer(maxRunTokens).map(Double.init)), snake: "max_run_tokens")
        set("maxRunsPerHour", number(Self.integer(maxRunsPerHour).map(Double.init)), snake: "max_runs_per_hour")
        set("dataRegion", .string(dataRegion.trimmingCharacters(in: .whitespacesAndNewlines)), snake: "data_region")
        set("requireSafetyReview", .bool(requireSafetyReview), snake: "require_safety_review")
        set("classificationLlmFallback", .bool(classificationLlmFallback), snake: "classification_llm_fallback")
        set("requireValidatorPassForEnable", .bool(requireValidatorPassForEnable), snake: "require_validator_pass_for_enable")
        // Campi mancanti nell'originale e lasciati vuoti: non si aggiungono null nuovi.
        for key in ["costCeilingEur", "maxRunCostEur", "maxRunTokens", "maxRunsPerHour"]
        where body[key] == .null && raw[key] == nil && raw[Self.snake(key)] == nil {
            body[key] = nil
        }
        if raw["dataRegion"] == nil, raw["data_region"] == nil, body["dataRegion"] == .string("") { body["dataRegion"] = nil }
        return body
    }

    // MARK: Numeri

    /// "12,5" e "12.5" valgono uguale (tastiera italiana o inglese).
    private static func decimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite else { return nil }
        return value
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func integer(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }

    private static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        if let whole = Int(exactly: value) { return String(whole) }
        return value.formatted(.number.grouping(.never))
    }

    private static func snake(_ key: String) -> String {
        key.reduce(into: "") { out, character in
            if character.isUppercase { out.append("_") }
            out.append(contentsOf: character.lowercased())
        }
    }
}
