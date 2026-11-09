//
//  AdminCraftedReportHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  L'intestazione del rapporto: titolo, data e verdetto (con chi l'ha deciso), e "Open the chat" che
//  porta nella conversazione da cui nasce.
//

import SwiftUI

struct AdminCraftedReportHeader: View {
    let viewModel: AdminCraftedReportReaderViewModel
    @Environment(\.openChatSession) private var openChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if let date = viewModel.dateText {
                    Text(date).foregroundStyle(.secondary)
                }
                if let verdict = viewModel.verdictText {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.verdictImage)
                        Text(verdict)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AdminCraftedVerdict.tint(viewModel.review.verdict))
                }
            }
            .font(.subheadline)
            if let source = viewModel.verdictSourceText {
                Text(source)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let openChatSession {
                Button {
                    openChatSession(viewModel.sessionId)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                        Text("Open the chat")
                    }
                }
                .ariaGlassButtonStyle()
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
