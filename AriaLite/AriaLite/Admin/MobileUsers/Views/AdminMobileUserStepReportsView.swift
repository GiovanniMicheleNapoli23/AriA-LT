//
//  AdminMobileUserStepReportsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I passi di un ordine di lavoro dell'operatore, in sola lettura: risultato, nota, foto e chi li ha segnati.
//

import SwiftUI

struct AdminMobileUserStepReportsView: View {
    @State private var viewModel: AdminMobileUserStepReportsViewModel

    init(viewModel: AdminMobileUserStepReportsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.order.title)
                        .font(.title3.weight(.semibold))
                    Text(viewModel.order.statusLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let progress = viewModel.progressText {
                        Text(progress)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                AdminCard(title: "Steps", systemImage: "checklist") { stepsContent }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle("Step reports")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var stepsContent: some View {
        if let message = viewModel.errorMessage, viewModel.rows.isEmpty {
            AdminSectionNotice(text: message, isError: true)
        } else if !viewModel.hasLoaded {
            ProgressView().frame(maxWidth: .infinity)
        } else if viewModel.rows.isEmpty {
            AdminSectionNotice(text: String(localized: "This work order has no steps."), systemImage: "checklist")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.rows) { row in
                    AdminMobileUserStepRow(data: row)
                    if row != viewModel.rows.last { Divider() }
                }
            }
        }
    }
}
