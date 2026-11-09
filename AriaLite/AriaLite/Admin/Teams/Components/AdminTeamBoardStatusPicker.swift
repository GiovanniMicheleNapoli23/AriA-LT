//
//  AdminTeamBoardStatusPicker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il selettore di colonna su telefono: una chip per stato con il conteggio, nel colore dello stato. Le chip
//  stanno a capo in una griglia adattiva (niente scroll orizzontale).
//

import SwiftUI

struct AdminTeamBoardStatusPicker: View {
    let columns: [AdminTeamWorkOrderStatus]
    @Binding var selection: AdminTeamWorkOrderStatus
    let count: (AdminTeamWorkOrderStatus) -> Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(columns, id: \.self) { status in
                chip(status)
            }
        }
    }

    private func chip(_ status: AdminTeamWorkOrderStatus) -> some View {
        let isOn = selection == status
        return Button {
            withAnimation(.snappy) { selection = status }
        } label: {
            HStack(spacing: 6) {
                Text(status.label).fontWeight(.semibold)
                Text(count(status), format: .number)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(status.tint.opacity(isOn ? 0.25 : 0.14), in: Capsule())
            }
            .font(.footnote)
            .foregroundStyle(isOn ? status.tint : Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule(), tint: isOn ? status.tint.opacity(0.14) : nil)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
