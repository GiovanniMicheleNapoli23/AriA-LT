//
//  AdminComingSoonView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sezione che la web non ha ancora: stesso segnaposto "coming soon".
//

import SwiftUI

struct AdminComingSoonView: View {
    let page: AdminComingSoonPage

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label { Text(page.title) } icon: { Image(systemName: page.systemImage) }
            } description: {
                Text("Coming soon. \(Text(page.message))")
            }
            .liteBackground()
            .navigationTitle(Text(page.title))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
        }
    }
}
