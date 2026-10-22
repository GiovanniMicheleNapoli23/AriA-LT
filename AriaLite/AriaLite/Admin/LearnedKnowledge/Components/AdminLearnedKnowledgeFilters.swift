//
//  AdminLearnedKnowledgeFilters.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La fila di filtri sopra la lista dei fatti: stato (chiesto al server), stabilimento e autore
//  (sui fatti scaricati). La "x" toglie i filtri locali.
//

import SwiftUI

struct AdminLearnedKnowledgeFilters: View {
    @Bindable var viewModel: AdminLearnedKnowledgeViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Status", selection: $viewModel.statusFilter) {
                        Text("All").tag(AdminMemoryFactStatus?.none)
                        ForEach(AdminMemoryFactStatus.allCases) {
                            Label($0.label, systemImage: $0.systemImage).tag(Optional($0))
                        }
                    }
                } label: {
                    AdminFilterChip(title: "Status", value: viewModel.statusFilterLabel,
                                    isActive: viewModel.statusFilter != nil)
                }
                if viewModel.plants.count > 1 {
                    Menu {
                        Picker("Plant", selection: $viewModel.plantFilter) {
                            Text("All plants").tag(String?.none)
                            ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                        }
                    } label: {
                        AdminFilterChip(title: "Plant", value: viewModel.plantFilterLabel,
                                        isActive: viewModel.plantFilter != nil)
                    }
                }
                if !viewModel.authors.isEmpty {
                    Menu {
                        Picker("Author", selection: $viewModel.authorFilter) {
                            Text("Anyone").tag(String?.none)
                            ForEach(viewModel.authors, id: \.key) { Text($0.name).tag(Optional($0.key)) }
                        }
                    } label: {
                        AdminFilterChip(title: "Author", value: viewModel.authorFilterLabel,
                                        isActive: viewModel.authorFilter != nil)
                    }
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
}
