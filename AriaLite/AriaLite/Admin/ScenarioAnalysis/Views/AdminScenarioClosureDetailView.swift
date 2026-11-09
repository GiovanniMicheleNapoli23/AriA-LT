//
//  AdminScenarioClosureDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di una procedura chiusa senza riparazione: dove si è fermata e perché, cosa era stato fatto
//  e trovato, la decisione dell'admin e il report .docx. Sola lettura: la decisione si prende dalla web.
//

import SwiftUI

struct AdminScenarioClosureDetailView: View {
    @State private var viewModel: AdminScenarioClosureDetailViewModel

    init(viewModel: AdminScenarioClosureDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                fieldsCard(title: "Closure", systemImage: "stop.circle", fields: viewModel.closureFields)
                if let details = viewModel.closure.closureDetails, !details.isEmpty {
                    AdminCard(title: "Operator's explanation", systemImage: "text.quote") {
                        Text(details).font(.subheadline).textSelection(.enabled)
                    }
                }
                if !viewModel.completedSteps.isEmpty {
                    AdminCard(title: "Completed steps", systemImage: "list.number") {
                        AdminScenarioBulletList(items: viewModel.completedSteps, numbered: true)
                    }
                }
                if !viewModel.findings.isEmpty {
                    AdminCard(title: "Findings", systemImage: "magnifyingglass") {
                        AdminScenarioBulletList(items: viewModel.findings)
                    }
                }
                fieldsCard(title: "Decision", systemImage: "person.badge.shield.checkmark", fields: viewModel.decisionFields)
                if let note = viewModel.closure.decisionNote, !note.isEmpty {
                    AdminCard(title: "Decision note", systemImage: "note.text") {
                        Text(note).font(.subheadline).textSelection(.enabled)
                    }
                }
                AdminCard(title: "Report", systemImage: "doc.text") {
                    AdminScenarioReportButton(viewModel: viewModel.report)
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.closure.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let code = viewModel.closure.alarmCode {
                    Text(code)
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(Color.liteAccent)
                }
                if let label = viewModel.statusLabel {
                    AdminScenarioBadge(text: label, tone: AdminScenarioLabel.closureTone(viewModel.closure.status))
                }
            }
            Text(viewModel.closure.displayTitle)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func fieldsCard(title: LocalizedStringKey, systemImage: String, fields: [AdminAssetField]) -> some View {
        if !fields.isEmpty {
            AdminCard(title: title, systemImage: systemImage) {
                VStack(spacing: 0) {
                    ForEach(fields) { field in
                        AdminFieldRow(field: field, showsDivider: field.id != fields.last?.id)
                    }
                }
            }
        }
    }
}
