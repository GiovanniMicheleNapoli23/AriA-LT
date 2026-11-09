//
//  AdminReportWidgetsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I widget salvati: l'elenco, un tocco per aprirne uno con i dati di oggi (schermata di Crafted) e il menu
//  per eliminarlo.
//

import SwiftUI

struct AdminReportWidgetsSection: View {
    let viewModel: AdminReportsViewModel

    var body: some View {
        AdminReportSection(title: "Saved widgets", load: viewModel.widgets,
                           emptyText: String(
                               localized: "No saved widgets yet. Pin a card from an Aria session to see it here."),
                           isEmpty: \.isEmpty,
                           retry: { await viewModel.load() }) { _ in
            VStack(alignment: .leading, spacing: 0) {
                let widgets = viewModel.visibleWidgets
                ForEach(Array(widgets.enumerated()), id: \.element.id) { index, widget in
                    AdminReportWidgetRow(widget: widget, canDelete: viewModel.canDelete(widget)) {
                        viewModel.askDelete(widget)
                    }
                    if index < widgets.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
