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
            WorkOrderListView(viewModel: viewModel, user: user)
        } else {
            LoginView(viewModel: viewModel)
        }
    }
}
#Preview {
    ContentView()
        .environment(AppViewModel())
}
