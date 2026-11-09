//
//  AdminInspectionActionsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I cambi di stato dell'ispezione (avvia, completa, riapri, annulla) come pulsanti espliciti.
//  Il primo è in evidenza; mentre il server risponde sono tutti fermi.
//

import SwiftUI

struct AdminInspectionActionsCard: View {
    let viewModel: AdminInspectionDetailViewModel

    var body: some View {
        AdminCard(title: "Status", systemImage: "flag.checkered") {
            VStack(spacing: 10) {
                ForEach(Array(viewModel.transitions.enumerated()), id: \.element) { index, transition in
                    Button {
                        Task { await viewModel.requestTransition(transition) }
                    } label: {
                        Label(transition.title, systemImage: transition.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(AdminInspectionActionStyle(isPrimary: index == 0 && transition != .cancel,
                                                         isDestructive: transition == .cancel))
                }
                if viewModel.isWorking { ProgressView() }
            }
            .disabled(!viewModel.canEdit || viewModel.isWorking)
        }
    }
}

/// Il primo pulsante è pieno nel colore dell'app, gli altri di vetro; annulla è rosso.
private struct AdminInspectionActionStyle: ViewModifier {
    let isPrimary: Bool
    let isDestructive: Bool

    func body(content: Content) -> some View {
        if isPrimary {
            content.ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
        } else if isDestructive {
            content.ariaGlassButtonStyle().tint(.red)
        } else {
            content.ariaGlassButtonStyle()
        }
    }
}
