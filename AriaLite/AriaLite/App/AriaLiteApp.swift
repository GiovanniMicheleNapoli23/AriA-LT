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
    @AppStorage(AriaAppearance.storageKey) private var appearance: AriaAppearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .toggleStyle(.ariaSwitch)
                // Chiaro, scuro o come il telefono (dal profilo): su tutte le finestre, anche quelle nuove su iPad.
                .onChange(of: appearance, initial: true) { _, appearance in appearance.apply() }
                #if DEBUG
                .task {
                    await viewModel.signInWithLaunchLink()
                    await viewModel.signInForUITests()
                }
                #endif
        }
    }
}
