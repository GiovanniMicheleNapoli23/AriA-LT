//
//  AdminAgentStudioViewModel+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I testi derivati che le schermate di Agent Studio mostrano: la riga di numeri e "Needs attention" della
//  principale, righe secondarie delle liste (workflow, approvazioni, run attivi) e la policy in sola lettura.
//

import Foundation

extension AdminAgentStudioViewModel {
    // MARK: Schermata principale

    /// "5 workflows · 3 enabled · 12 runs today"; niente se non ci sono workflow.
    var statsLine: String? {
        guard !workflows.isEmpty else { return nil }
        let total = workflows.count
        let enabled = enabledCount
        let today = runsTodayCount
        return [
            String(localized: "\(total) workflows"),
            String(localized: "\(enabled) enabled"),
            String(localized: "\(today) runs today"),
        ].joined(separator: " · ")
    }

    /// Né approvazioni in attesa né run attivi: la schermata dice che è tutto tranquillo.
    var needsAttentionIsEmpty: Bool { pendingApprovals.isEmpty && activeRuns.isEmpty }

    /// Perché "Needs attention" può essere incompleta (approvazioni o run non arrivati).
    var attentionErrors: [String] {
        [pendingApprovalsError, activeRunsError].compactMap { $0 }
    }

    /// Le approvazioni in attesa, dalla più recente.
    var attentionApprovals: [AdminAgentStudioApproval] {
        pendingApprovals.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    // MARK: Righe delle liste

    func subtitle(for workflow: AdminAgentStudioWorkflow) -> String {
        let steps = workflow.nodes.count
        var parts = [String(localized: "\(steps) steps")]
        if let today = workflow.runsToday, today > 0 { parts.append(String(localized: "\(today) runs today")) }
        return parts.joined(separator: " · ")
    }

    func footnote(for workflow: AdminAgentStudioWorkflow) -> String? {
        guard let last = workflow.lastRunAt else { return nil }
        let when = last.formatted(.relative(presentation: .named))
        return String(localized: "Last run \(when)")
    }

    func subtitle(for approval: AdminAgentStudioApproval) -> String? {
        let parts = [approval.workflowName, approval.agentName ?? approval.connectorId].compactMap { $0 }
        return parts.isEmpty ? approval.instructions : parts.joined(separator: " · ")
    }

    func footnote(for approval: AdminAgentStudioApproval) -> String? {
        approval.createdAt.map { $0.formatted(.relative(presentation: .named)) }
    }

    func subtitle(for run: AdminAgentStudioActiveRun) -> String? {
        let mode = run.mode.map { AdminAgentStudioRunMode(rawValue: $0)?.label ?? $0 }
        let waiting = run.waitingFor.map { String(localized: "Waiting for \($0)") }
        let parts = [mode, waiting].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func footnote(for run: AdminAgentStudioActiveRun) -> String? {
        guard let started = run.startedAt else { return nil }
        let when = started.formatted(.relative(presentation: .named))
        return String(localized: "Started \(when)")
    }

    // MARK: Policy in sola lettura

    /// Le righe della policy in sola lettura; i limiti assenti si leggono "nessun limite".
    var policyFields: [AdminAssetField] {
        guard let policy else { return [] }
        let none = String(localized: "No limit")
        func euros(_ value: Double?) -> String { value.map { $0.formatted(.currency(code: "EUR")) } ?? none }
        func count(_ value: Int?) -> String { value.map { $0.formatted() } ?? none }
        func required(_ value: Bool) -> String { value ? String(localized: "Required") : String(localized: "Not required") }
        var rows = [
            AdminAssetField(title: String(localized: "Cost ceiling"), value: euros(policy.costCeilingEur)),
            AdminAssetField(title: String(localized: "Max cost per run"), value: euros(policy.maxRunCostEur)),
            AdminAssetField(title: String(localized: "Max run time"), value: policy.maxRunSeconds.map {
                Duration.seconds($0).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
            } ?? none),
            AdminAssetField(title: String(localized: "Max tokens per run"), value: count(policy.maxRunTokens)),
            AdminAssetField(title: String(localized: "Max runs per hour"), value: count(policy.maxRunsPerHour)),
            AdminAssetField(title: String(localized: "Safety review"), value: required(policy.requireSafetyReview)),
            AdminAssetField(title: String(localized: "Validator pass to enable"), value: required(policy.requireValidatorPassForEnable)),
            AdminAssetField(title: String(localized: "AI classification fallback"),
                            value: policy.classificationLlmFallback ? String(localized: "On") : String(localized: "Off")),
        ]
        if let region = policy.dataRegion { rows.append(AdminAssetField(title: String(localized: "Data region"), value: region)) }
        if let version = policy.version { rows.append(AdminAssetField(title: String(localized: "Version"), value: String(version))) }
        if let updated = policy.updatedAt {
            let when = updated.formatted(date: .abbreviated, time: .shortened)
            let value = policy.updatedBy.map { String(localized: "\(when) by \($0)") } ?? when
            rows.append(AdminAssetField(title: String(localized: "Updated"), value: value))
        }
        return rows
    }

    /// Le liste della policy (connettori ammessi, capacità vietate, webhook), solo quelle non vuote.
    var policyLists: [AdminAssetField] {
        guard let policy else { return [] }
        let lists = [
            (String(localized: "Allowed connectors"), policy.allowedConnectors),
            (String(localized: "Forbidden capabilities"), policy.forbiddenCapabilities),
            (String(localized: "Webhook allowlist"), policy.webhookAllowlist),
        ]
        return lists.filter { !$0.1.isEmpty }.map { AdminAssetField(title: $0.0, value: $0.1.joined(separator: ", ")) }
    }

    /// Chi approva un livello di rischio: "Automatic" o approvatori, ruolo minimo e scadenza.
    func summary(for tier: AdminAgentStudioPolicyTier) -> String {
        if tier.auto { return String(localized: "Automatic") }
        var parts: [String] = []
        if let approvers = tier.approvers { parts.append(String(localized: "\(approvers) approvers")) }
        if let role = tier.minRole { parts.append(String(localized: "min. \(role)")) }
        if let minutes = tier.timeoutMinutes {
            let timeout = tier.onTimeout.map { String(localized: "after \(minutes) min: \($0)") }
                ?? String(localized: "expires after \(minutes) min")
            parts.append(timeout)
        }
        return parts.isEmpty ? String(localized: "Needs approval") : parts.joined(separator: " · ")
    }
}
