//
//  AdminMemberDevicesList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  I dispositivi su cui la persona è entrata nell'app (solo con l'app attiva o sospesa): uscire da uno o da tutti,
//  sempre dopo conferma. Nessun dispositivo non è un errore; se usa l'app anche per un'altra azienda lo dice.
//

import SwiftUI

struct AdminMemberDevicesList: View {
    let viewModel: AdminMemberDetailViewModel

    var body: some View {
        AdminCard(title: "Devices", systemImage: "iphone.gen3") {
            if viewModel.sessions.count > 1 {
                Button("Log out all", systemImage: "rectangle.portrait.and.arrow.right") {
                    viewModel.askToLogOutAll()
                }
                .font(.footnote.weight(.semibold))
                .tint(Color.liteAccent)
                .disabled(viewModel.isWorking)
            }
        } content: {
            if let message = viewModel.sessionsMessage, viewModel.sessions.isEmpty {
                AdminSectionNotice(text: message, systemImage: "iphone.slash")
            } else if !viewModel.hasLoadedSessions {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.sessions.isEmpty {
                AdminSectionNotice(text: String(localized: "Not signed in on any device."), systemImage: "iphone.slash")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.sessions) { session in
                        AdminMobileUserSessionRow(title: viewModel.sessionTitle(session),
                                                  line: viewModel.sessionLine(session)) {
                            viewModel.askToLogOut(session)
                        }
                        .disabled(viewModel.isWorking)
                        if session != viewModel.sessions.last { Divider() }
                    }
                }
            }
        }
    }
}
