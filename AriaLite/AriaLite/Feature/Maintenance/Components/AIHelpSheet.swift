//
//  AIHelpSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/03/26.
//

import SwiftUI

// Assistente AriA dentro la manutenzione: chat (FAKE) seminata sullo step corrente.
struct AIHelpSheet: View {
    let currentItem: ChecklistItem
    var workOrder: WorkOrder? = nil
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                // Chat condivisa, contesto = step corrente. Con il backend: la sfera al centro con il saluto,
                // come la chat principale; in locale il messaggio iniziale di aiuto sullo step.
                AriaConversation(
                    workOrder: workOrder,
                    step: currentItem,
                    showsEmptyState: viewModel.backend.isReady,
                    seedsStepIntro: true
                )
            }
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
                .padding(.top, 14)
                .padding(.trailing, 20)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.light)
    }
}
