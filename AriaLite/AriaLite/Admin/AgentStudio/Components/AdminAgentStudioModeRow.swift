//
//  AdminAgentStudioModeRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Una modalità di avvio come riga selezionabile: icona, nome, spiegazione che va a capo e il segno
//  di spunta sulla riga scelta.
//

import SwiftUI

struct AdminAgentStudioModeRow: View {
    let mode: AdminAgentStudioRunMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                AdminAgentStudioIcon(systemImage: mode.systemImage, tint: mode == .run ? .orange : .liteAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(mode.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.liteAccent) : AnyShapeStyle(.tertiary))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
