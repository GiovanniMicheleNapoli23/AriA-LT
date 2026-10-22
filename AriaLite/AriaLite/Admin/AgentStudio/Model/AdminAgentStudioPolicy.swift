//
//  AdminAgentStudioPolicy.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le regole dell'azienda per i workflow (CompanyPolicy). PUT sostituisce tutta la policy:
//  si tiene l'oggetto originale (`raw`) e si rimanda con i soli campi modificati cambiati,
//  così le parti che l'app non modifica (matrice delle approvazioni, liste) restano intatte.
//

import Foundation

nonisolated struct AdminAgentStudioPolicy: AdminAgentStudioJSONModel {
    static let listKeys: [String] = []

    let raw: [String: AriaJSON]
    let costCeilingEur: Double?
    let maxRunSeconds: Int?
    let maxRunTokens: Int?
    let maxRunCostEur: Double?
    let maxRunsPerHour: Int?
    let defaultLoopMaxTokens: Int?
    let requireSafetyReview: Bool
    let classificationLlmFallback: Bool
    let requireValidatorPassForEnable: Bool
    let dataRegion: String?
    let allowedConnectors: [String]
    let forbiddenCapabilities: [String]
    let webhookAllowlist: [String]
    let tiers: [AdminAgentStudioPolicyTier]
    let version: Int?
    let updatedAt: Date?
    let updatedBy: String?

    init?(json: AriaJSON) {
        let outer = AdminAgentStudioFields(json)
        let fields = outer.object("policy").isEmpty ? outer : outer.object("policy")
        guard !fields.isEmpty else { return nil }
        raw = fields.raw
        costCeilingEur = fields.double("costCeilingEur")
        maxRunSeconds = fields.int("maxRunSeconds")
        maxRunTokens = fields.int("maxRunTokens")
        maxRunCostEur = fields.double("maxRunCostEur")
        maxRunsPerHour = fields.int("maxRunsPerHour")
        defaultLoopMaxTokens = fields.int("defaultLoopMaxTokens")
        requireSafetyReview = fields.bool("requireSafetyReview") ?? false
        classificationLlmFallback = fields.bool("classificationLlmFallback") ?? true
        requireValidatorPassForEnable = fields.bool("requireValidatorPassForEnable") ?? true
        dataRegion = fields.string("dataRegion")
        allowedConnectors = fields.strings("allowedConnectors")
        forbiddenCapabilities = fields.strings("forbiddenCapabilities")
        webhookAllowlist = fields.strings("webhookAllowlist")
        let matrix = fields.object("approvalMatrix")
        tiers = matrix.raw.keys.sorted().compactMap { AdminAgentStudioPolicyTier(name: $0, json: matrix.raw[$0]) }
        version = fields.int("version")
        updatedAt = fields.date("updatedAt")
        updatedBy = fields.string("updatedBy")
    }
}

/// Chi approva un livello di rischio (R1–R3) prima che un run reale lo esegua. In sola lettura.
nonisolated struct AdminAgentStudioPolicyTier: Sendable, Identifiable, Hashable {
    let name: String
    let auto: Bool
    let minRole: String?
    let approvers: Int?
    let timeoutMinutes: Int?
    let onTimeout: String?

    var id: String { name }

    init?(name: String, json: AriaJSON?) {
        let fields = AdminAgentStudioFields(json)
        guard !fields.isEmpty else { return nil }
        self.name = name
        auto = fields.bool("auto") ?? false
        minRole = fields.string("minRole")
        approvers = fields.int("approvers")
        timeoutMinutes = fields.int("timeoutMinutes")
        onTimeout = fields.string("onTimeout")
    }
}
