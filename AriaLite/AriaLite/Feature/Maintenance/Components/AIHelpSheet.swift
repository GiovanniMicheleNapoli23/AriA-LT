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
    @Environment(\.dismiss) private var dismiss
    @State private var detent: PresentationDetent = .large
    @State private var source: AriaResponseSource = .none

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                // Header
                HStack(spacing: 12) {
                    Image("AriaBlob")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.liteAccent.opacity(0.4), radius: 5)

                    Text("AriA Engine")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.liteAccent)

                    // Fonte ultima risposta: blu = locale · viola = Apple Intelligence
                    AriaSourceDot(source: source)
                        .animation(.easeInOut(duration: 0.25), value: source)

                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                Divider()

                // Chat condivisa, contesto = step corrente, con messaggio iniziale di aiuto.
                AriaConversation(
                    workOrder: workOrder,
                    step: currentItem,
                    showsEmptyState: false,
                    seedsStepIntro: true,
                    source: $source
                )
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.light)
    }
}
