//
//  AriaLiteApp.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import SwiftUI

@main
struct WorkOrderApp: App {
    @UIApplicationDelegateAdaptor(AriaAppDelegate.self) private var appDelegate
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                #if DEBUG
                .task { await viewModel.signInWithLaunchLink() }
                #endif
        }
    }
}
