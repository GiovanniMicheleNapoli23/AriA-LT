//
//  AdminWorkOrderFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I chip dei filtri della lista: aperti, chiusi o tutti, e la priorità (si tocca di nuovo per toglierla).
//  Scorrono in orizzontale se non ci stanno (iPhone verticale, testo grande).
//

import SwiftUI

struct AdminWorkOrderFilterBar: View {
    let statusGroup: AdminWorkOrderStatusGroup
    let priority: AdminWorkOrderPriority?
    let onSelectGroup: (AdminWorkOrderStatusGroup) -> Void
    let onTogglePriority: (AdminWorkOrderPriority) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdminWorkOrderStatusGroup.allCases, id: \.self) { group in
                    chip(group.localized, isOn: group == statusGroup) { onSelectGroup(group) }
                }
                Divider().frame(height: 20).padding(.horizontal, 4)
                ForEach(AdminWorkOrderPriority.known, id: \.self) { level in
                    chip(level.localized, isOn: level == priority) { onTogglePriority(level) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Color.white : Color.liteAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if isOn {
                        Capsule().fill(Color.liteAccent)
                    } else {
                        Capsule().fill(Color.liteAccent.opacity(0.06))
                            .overlay(Capsule().strokeBorder(Color.liteBorder, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(.snappy(duration: 0.2), value: isOn)
    }
}
