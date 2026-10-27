//
//  AdminAgentStudioAccuracyView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  L'accuratezza degli agenti sulle ultime risposte valutate, in una schermata a parte.
//

import SwiftUI

struct AdminAgentStudioAccuracyView: View {
    let viewModel: AdminAgentStudioViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.hasLoaded {
                    AdminAgentStudioAccuracyCard(agents: viewModel.accuracy, window: viewModel.accuracyWindow,
                                                 errorMessage: viewModel.accuracyError)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle("Agent accuracy")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
    }
}
