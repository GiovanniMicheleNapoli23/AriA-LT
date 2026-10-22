//
//  AdminMemoryFactActionButtons.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le voci di un menu su un fatto: approva, rifiuta, modifica, elimina. Le usano il menu contestuale
//  della lista e il menu "···" del dettaglio; cosa fanno lo decide chi le mette.
//

import SwiftUI

struct AdminMemoryFactActionButtons: View {
    let canApprove: Bool
    let canReject: Bool
    let onApprove: () -> Void
    let onReject: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if canApprove {
            Button("Approve", systemImage: "checkmark.seal", action: onApprove)
        }
        if canReject {
            Button("Reject", systemImage: "xmark.octagon", action: onReject)
        }
        Button("Edit", systemImage: "pencil", action: onEdit)
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
    }
}
