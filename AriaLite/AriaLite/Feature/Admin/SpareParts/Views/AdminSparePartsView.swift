//
//  AdminSparePartsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I ricambi, come la pagina /spare-parts della web.
//

import SwiftUI

struct AdminSparePartsView: View {
    let viewModel: AdminSparePartsViewModel

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Spare Parts", systemImage: "shippingbox")
                .liteBackground()
                .navigationTitle("Spare Parts")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                }
        }
    }
}
