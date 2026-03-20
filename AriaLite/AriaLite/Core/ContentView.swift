//
//  ContentView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import SwiftUI

import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        if let user = viewModel.loggedInUser {
            @Bindable var viewModel = viewModel

            TabView {
                Tab {
                    WorkOrderListView(viewModel: viewModel, user: user)
                } label: {
                    Label("Lavori", systemImage: "wrench.and.screwdriver")
                }

                Tab {
                    ReportView()
                } label: {
                    Label("Report", systemImage: "chart.bar.doc.horizontal")
                }

                Tab(role: .search) {
                    WorkOrderSearchView(viewModel: viewModel, user: user)
                }
            }
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
