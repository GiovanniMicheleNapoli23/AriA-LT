//
//  AdminWorkOrderFormStepHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  In cima alla creazione a passi: una barra a segmenti (tocca un segmento per saltare a quel passo),
//  il numero del passo, il titolo e una riga che dice cosa chiede. In orizzontale con la tastiera aperta
//  resta solo la barra.
//

import SwiftUI

struct AdminWorkOrderFormStepHeader: View {
    let steps: [AdminWorkOrderFormStep]
    let current: AdminWorkOrderFormStep
    var isCompact = false
    let onSelect: (AdminWorkOrderFormStep) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(steps) { step in
                    Button { onSelect(step) } label: {
                        Capsule()
                            .fill(step.rawValue <= current.rawValue ? Color.liteAccent : Color.liteAccent.opacity(0.14))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(step.title))
                    .accessibilityAddTraits(step == current ? .isSelected : [])
                }
            }
            if !isCompact {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step \(current.rawValue + 1) of \(steps.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(current.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.liteText)
                    Text(current.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .contentTransition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, isCompact ? 0 : 4)
        .animation(.snappy, value: current)
    }
}
