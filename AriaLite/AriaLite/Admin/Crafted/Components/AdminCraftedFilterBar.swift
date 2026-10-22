//
//  AdminCraftedFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le chip di filtro di Crafted: tipo di card per i widget, verdetto per le sessioni.
//

import SwiftUI

struct AdminCraftedFilterBar: View {
    @Bindable var viewModel: AdminCraftedViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                switch viewModel.tab {
                case .widgets: kindMenu
                case .sessions: verdictMenu
                }
                if viewModel.hasLocalFilters {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        withAnimation(.snappy) { viewModel.clearFilters() }
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Clear filters"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private var kindMenu: some View {
        Menu {
            Picker("Type", selection: $viewModel.kindFilter) {
                Text("All types").tag(String?.none)
                ForEach(viewModel.kinds, id: \.self) { kind in
                    Label(AdminCraftedKind.label(kind), systemImage: AdminCraftedKind.systemImage(kind)).tag(Optional(kind))
                }
            }
        } label: {
            AdminFilterChip(title: "Type", value: viewModel.kindFilterLabel, isActive: viewModel.kindFilter != nil)
        }
        .disabled(viewModel.kinds.isEmpty)
    }

    private var verdictMenu: some View {
        Menu {
            Picker("Verdict", selection: $viewModel.verdictFilter) {
                Text("All verdicts").tag(String?.none)
                ForEach(viewModel.verdicts, id: \.self) { verdict in
                    Text(viewModel.verdictLabel(verdict)).tag(Optional(verdict))
                }
            }
        } label: {
            AdminFilterChip(title: "Verdict", value: viewModel.verdictFilterLabel, isActive: viewModel.verdictFilter != nil)
        }
        .disabled(viewModel.verdicts.isEmpty)
    }
}
