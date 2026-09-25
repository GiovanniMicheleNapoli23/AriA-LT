//
//  AriaLiteApp.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import SwiftUI

@main
struct WorkOrderApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                #if DEBUG
                .task { await viewModel.backend.signInWithLaunchLink() }
                #endif
        }
    }
}
