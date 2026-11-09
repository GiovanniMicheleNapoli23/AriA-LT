//
//  AdminWorkOrderFormOptionTiles.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una scelta fra poche voci (priorità, tipo) come tessere affiancate con icona: grandi da toccare e
//  colorate con il colore della voce quando sono scelte.
//

import SwiftUI

struct AdminWorkOrderFormOptionTiles<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    let systemImage: (Value) -> String
    let tint: (Value) -> Color

    /// Con i 6 pt di margine della riga, gli angoli restano concentrici con quelli della cella.
    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                tile(option, isOn: option == selection)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .animation(.snappy(duration: 0.2), value: selection)
    }

    private func tile(_ option: Value, isOn: Bool) -> some View {
        Button { selection = option } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage(option))
                    .font(.title3.weight(.semibold))
                Text(title(option))
                    .font(.subheadline.weight(isOn ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isOn ? tint(option) : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(shape.fill(isOn ? tint(option).opacity(0.12) : Color(.secondarySystemGroupedBackground)))
            .overlay(shape.strokeBorder(isOn ? tint(option) : Color.primary.opacity(0.06), lineWidth: isOn ? 1.5 : 0.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
