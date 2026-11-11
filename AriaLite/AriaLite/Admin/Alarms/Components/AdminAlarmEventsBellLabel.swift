//
//  AdminAlarmEventsBellLabel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Il pulsante nella barra della lista Alarms che apre l'inbox: una campanella e, se ci sono eventi non
//  letti, il loro numero accanto (dentro il pulsante, così non si taglia).
//

import SwiftUI

struct AdminAlarmEventsBellLabel: View {
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: unreadCount > 0 ? "bell.badge" : "bell")
            if unreadCount > 0 {
                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Alarm events"))
        .accessibilityValue(unreadCount > 0 ? Text("\(unreadCount) unread") : Text(""))
    }
}
