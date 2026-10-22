//
//  AdminAssetsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli asset dello stabilimento, come la pagina /assets della web.
//

import SwiftUI

struct AdminAssetsView: View {
    let viewModel: AdminAssetsViewModel

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Assets", systemImage: "gearshape.2")
                .liteBackground()
                .navigationTitle("Assets")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                }
        }
    }
}
