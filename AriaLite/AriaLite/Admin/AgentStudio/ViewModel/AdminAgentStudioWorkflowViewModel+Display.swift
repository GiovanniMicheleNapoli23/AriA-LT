//
//  AdminAgentStudioWorkflowViewModel+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Valori già pronti per il dettaglio del workflow: riga di stato, tempi relativi, etichetta di Start,
//  passi del flusso, run recenti. Solo proprietà calcolate; lo stato resta nel view model.
//

import Foundation

extension AdminAgentStudioWorkflowViewModel {
    // MARK: Intestazione

    var statusLabel: String { isEnabled ? String(localized: "Enabled") : String(localized: "Paused") }

    /// "Enabled · 3 runs today · Last run 2 hours ago".
    var statusLine: String {
        var parts = [statusLabel]
        if let runsToday = workflow?.runsToday { parts.append(String(localized: "\(runsToday) runs today")) }
        if let lastRunAt = workflow?.lastRunAt {
            parts.append(String(localized: "Last run \(Self.relative(lastRunAt))"))
        }
        return parts.joined(separator: " · ")
    }

    private static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    // MARK: Run it

    var isRealRun: Bool { selectedMode == .run }

    var startLabel: String {
        switch selectedMode {
        case .check: String(localized: "Check now")
        case .simulate: String(localized: "Start simulation")
        case .run: String(localized: "Run for real…")
        }
    }

    // MARK: How it works

    /// Il trigger per primo, poi gli altri nell'ordine del grafo.
    var flowSteps: [AdminAgentStudioWorkflowStep] {
        let all = steps
        return all.filter(\.isTrigger) + all.filter { !$0.isTrigger }
    }

    // MARK: Recent runs

    private static let recentCount = 5

    var visibleRuns: [AdminAgentStudioRun] {
        showsAllRuns ? sortedRuns : Array(sortedRuns.prefix(Self.recentCount))
    }

    var showsShowAllRuns: Bool { !showsAllRuns && runs.count > Self.recentCount }

    func modeLabel(for run: AdminAgentStudioRun) -> String {
        guard let mode = run.mode else { return String(localized: "Run") }
        return AdminAgentStudioRunMode(rawValue: mode)?.label ?? mode
    }

    /// "2 of 3 ran · 1 blocked".
    func countsLine(for run: AdminAgentStudioRun) -> String? {
        var parts: [String] = []
        if let ran = run.ran, let total = run.total, total > 0 { parts.append(String(localized: "\(ran) of \(total) ran")) }
        if let blocked = run.blocked, blocked > 0 { parts.append(String(localized: "\(blocked) blocked")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func relativeStart(for run: AdminAgentStudioRun) -> String? {
        run.startedAt.map(Self.relative)
    }

    func statusTone(for run: AdminAgentStudioRun) -> AdminAgentStudioTone {
        run.status.map(AdminAgentStudioStatus.tone(for:)) ?? .neutral
    }

    func runStatusLabel(for run: AdminAgentStudioRun) -> String? {
        run.status.map(AdminAgentStudioStatus.label(for:))
    }

    func statusSymbol(for run: AdminAgentStudioRun) -> String {
        switch statusTone(for: run) {
        case .positive: "checkmark.circle.fill"
        case .negative: "xmark.octagon.fill"
        case .warning: "clock.fill"
        case .active: "bolt.circle.fill"
        case .neutral: "circle.dashed"
        }
    }
}
