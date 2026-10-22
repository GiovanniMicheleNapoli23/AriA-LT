//
//  AdminTaskboardMoveMenu.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le voci "Move to …" del menu contestuale di una card: una per colonna di destinazione, più "Open".
//

import SwiftUI

struct AdminTaskboardMoveMenu: View {
    let choices: [AdminWorkOrderStatus]
    let onSelect: (AdminWorkOrderStatus) -> Void

    var body: some View {
        Menu {
            ForEach(choices, id: \.self) { status in
                Button(role: status == .cancelled ? .destructive : nil) {
                    onSelect(status)
                } label: {
                    Label(status.localized, systemImage: status.systemImage)
                }
            }
        } label: {
            Label("Move to…", systemImage: "arrow.left.arrow.right")
        }
    }
}
