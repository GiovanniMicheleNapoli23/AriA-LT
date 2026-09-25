//
//  ContentView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import SwiftUI


struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        if let user = viewModel.loggedInUser {
            // Navigazione come Claude mobile: chat al centro, sezioni nella sidebar.
            AriaShellView(user: user)
                .preferredColorScheme(.light)
        } else {
            LoginView(viewModel: viewModel)
        }
    }
}


#Preview {
    ContentView()
        .environment(AppViewModel())
}
