//
//  AdminAgentStudioDisclosureCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Una scheda di vetro che si apre e si chiude: lo stato iniziale lo decide chi la usa, poi vale il tocco.
//

import SwiftUI

struct AdminAgentStudioDisclosureCard<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    /// Aperta o chiusa finché la persona non la tocca.
    let startsExpanded: Bool
    @ViewBuilder var content: Content

    @State private var userChoice: Bool?

    var body: some View {
        DisclosureGroup(isExpanded: Binding(get: { userChoice ?? startsExpanded }, set: { userChoice = $0 })) {
            content
                .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                Text(title).font(.headline)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
