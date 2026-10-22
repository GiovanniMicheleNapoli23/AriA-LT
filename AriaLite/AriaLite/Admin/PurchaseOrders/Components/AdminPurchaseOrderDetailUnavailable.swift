//
//  AdminPurchaseOrderDetailUnavailable.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un ordine che non c'è sul server (senza id o cancellato da altri): spiega il motivo, senza azioni.
//

import SwiftUI

struct AdminPurchaseOrderDetailUnavailable: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Order unavailable", systemImage: "shippingbox.and.arrow.backward")
        } description: {
            Text(verbatim: message)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
