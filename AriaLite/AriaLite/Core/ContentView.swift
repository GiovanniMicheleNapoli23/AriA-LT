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
            @Bindable var viewModel = viewModel

            TabView {
                Tab {
                    OverviewView()
                } label: {
                    Label("Overview", systemImage: "house.fill")
                }
                Tab {
                    WorkOrderListView(viewModel: viewModel, user: user)
                } label: {
                    Label("Orders", systemImage: "wrench.and.screwdriver")
                }
                Tab {
                    AIChatView()
                } label: {
                    Label {
                        Text("Assistant")
                    } icon: {
                        Image("AriaBlobIcon")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    }
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
