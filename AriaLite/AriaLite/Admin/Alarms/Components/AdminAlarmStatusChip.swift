//
//  AdminAlarmStatusChip.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Capsula di un filtro per stato: piena (accento) quando è attiva, di vetro quando no.
//

import SwiftUI

struct AdminAlarmStatusChip: View {
    let status: AdminAlarmStatus
    let isSelected: Bool

    var body: some View {
        Text(status.label)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isSelected ? Color.liteOnAccent : Color.liteAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected { Capsule().fill(Color.liteAccent) }
            }
            .ariaGlass(in: Capsule())
            .contentShape(Capsule())
    }
}
