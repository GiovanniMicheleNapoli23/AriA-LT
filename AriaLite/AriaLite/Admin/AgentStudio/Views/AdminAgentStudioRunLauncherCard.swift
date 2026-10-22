//
//  AdminAgentStudioRunLauncherCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'avvio di un workflow dal telefono: controllo (connettori e policy, niente esecuzione), simulazione
//  (agenti veri, effetti simulati) o run reale (con conferma). Sotto, l'esito dell'ultimo avvio riga per riga.
//

import SwiftUI

struct AdminAgentStudioRunLauncherCard: View {
    let viewModel: AdminAgentStudioWorkflowViewModel

    @State private var showsAllEvents = false
    @ScaledMetric(relativeTo: .body) private var buttonWidth: CGFloat = 120

    var body: some View {
        AdminCard(title: "Run", systemImage: "play.circle") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: buttonWidth), spacing: 8)], spacing: 8) {
                    ForEach(AdminAgentStudioRunMode.allCases) { mode in
                        Button {
                            Task { await viewModel.choose(mode) }
                        } label: {
                            HStack(spacing: 6) {
                                if viewModel.runningMode == mode {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: mode.systemImage)
                                }
                                Text(mode.label).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(mode == .run ? Color.orange : Color.liteAccent)
                        .disabled(!viewModel.canStart)
                    }
                }
                if viewModel.runningMode != nil {
                    Text("Waiting for every step's verdict. You can leave this screen: the run goes on.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let result = viewModel.lastResult { resultView(result) }
            }
        }
    }

    @ViewBuilder
    private func resultView(_ result: AdminAgentStudioRunResult) -> some View {
        Divider()
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.mode.label).font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(result.finishedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let summary = viewModel.lastResultSummary {
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            if result.events.isEmpty {
                AdminSectionNotice(text: String(localized: "The server sent no step verdicts."))
            } else {
                let shown = showsAllEvents ? result.events : Array(result.events.prefix(8))
                VStack(spacing: 0) {
                    ForEach(shown) { event in
                        AdminAgentStudioEventRow(event: event, showsDivider: event.id != shown.last?.id)
                    }
                }
                if result.events.count > shown.count {
                    Button("Show all \(result.events.count)") { showsAllEvents = true }
                        .font(.footnote.weight(.semibold))
                        .tint(Color.liteAccent)
                }
            }
            if let run = viewModel.lastResultRun {
                NavigationLink(value: AdminAgentStudioRoute.run(workflowId: viewModel.workflowId, runId: run.id)) {
                    Label("Open run", systemImage: "arrow.right.circle")
                        .font(.footnote.weight(.semibold))
                }
                .tint(Color.liteAccent)
            }
        }
    }
}
