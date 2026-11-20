//
//  AriaAppearancePicker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La scelta dell'aspetto nel profilo: chiaro, scuro o come il telefono, come tre tasselli con icona e nome.
//  Con il testo molto grande diventano tre righe.
//

import SwiftUI

struct AriaAppearancePicker: View {
    @Binding var selection: AriaAppearance

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(AriaAppearance.allCases) { option(for: $0, stacked: true) }
            }
            VStack(spacing: 8) {
                ForEach(AriaAppearance.allCases) { option(for: $0, stacked: false) }
            }
        }
        .padding(8)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Appearance"))
    }

    private func option(for appearance: AriaAppearance, stacked: Bool) -> some View {
        let isOn = appearance == selection
        return Button {
            selection = appearance
        } label: {
            Group {
                if stacked {
                    VStack(spacing: 6) {
                        Image(systemName: appearance.systemImage).font(.title3.weight(.medium))
                        Text(appearance.title).font(.subheadline.weight(isOn ? .semibold : .medium)).lineLimit(1)
                    }
                    .padding(.vertical, 12)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: appearance.systemImage).font(.body.weight(.medium))
                        Text(appearance.title).font(.body.weight(isOn ? .semibold : .medium))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isOn ? Color.liteOnAccent : Color.primary)
            .background(isOn ? Color.liteAccent : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
