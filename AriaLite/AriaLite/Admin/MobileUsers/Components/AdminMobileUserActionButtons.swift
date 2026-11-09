//
//  AdminMobileUserActionButtons.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I pulsanti di un operatore (rimanda l'invito, sospendi, riattiva, rimuovi): stesso contenuto per il menu
//  contestuale della lista e per il menu del dettaglio. Quali compaiono lo decide il view model.
//

import SwiftUI

struct AdminMobileUserActionButtons: View {
    let user: AdminMobileUser
    let viewModel: AdminMobileUsersViewModel

    var body: some View {
        if viewModel.canResend(user) {
            Button("Resend invitation", systemImage: "paperplane") { Task { await viewModel.resend(user) } }
        }
        if viewModel.canSuspend(user) {
            Button("Suspend", systemImage: "pause.circle") { viewModel.askToSuspend(user) }
        }
        if viewModel.canReactivate(user) {
            Button("Reactivate", systemImage: "play.circle") { Task { await viewModel.reactivate(user) } }
        }
        if viewModel.canRemove(user) {
            Button("Remove", systemImage: "trash", role: .destructive) { viewModel.askToRemove(user) }
        }
    }
}
