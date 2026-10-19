//
//  AIHelpSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/03/26.
//

import SwiftUI

// Assistente Aria dentro un passo: la chat del backend, col contesto del passo corrente.
struct AIHelpSheet: View {
    /// Contesto del lavoro (ordine + passo).
    var contextText: String? = nil
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

                // Chat condivisa, contesto = passo corrente: la sfera al centro con il saluto, come la chat principale.
                AriaConversation(contextText: contextText)
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
