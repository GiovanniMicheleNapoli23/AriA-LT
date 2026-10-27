//
//  AdminAgentStudioConfigurationSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  "Configuration" in fondo alla schermata principale: approvazioni, policy, prompt e accuratezza degli agenti,
//  come righe di navigazione in un'unica scheda. Sempre visibile.
//

import SwiftUI

struct AdminAgentStudioConfigurationSection: View {
    private let items = AdminAgentStudioConfigurationItem.allCases

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdminAgentStudioSectionHeader(title: "Configuration")
            VStack(spacing: 0) {
                ForEach(items) { item in
                    NavigationLink(value: item.route) { row(item) }
                        .buttonStyle(.plain)
                    if item != items.last { Divider().padding(.leading, 14) }
                }
            }
            .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func row(_ item: AdminAgentStudioConfigurationItem) -> some View {
        HStack(spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                AdminAgentStudioIcon(systemImage: item.systemImage)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
