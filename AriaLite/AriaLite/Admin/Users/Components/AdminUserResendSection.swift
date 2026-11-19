//
//  AdminUserResendSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Resend email" (§5.6): per chi è stato aggiunto e non ha ancora effettuato l'accesso, solo per i titolari.
//

import SwiftUI

struct AdminUserResendSection: View {
    let viewModel: AdminUserDetailViewModel

    var body: some View {
        if viewModel.controls.resendEmail {
            Section {
                Button {
                    viewModel.resendEmail()
                } label: {
                    Label("Resend email", systemImage: "envelope")
                }
                .disabled(viewModel.isSendingEmail)
            }
        }
    }
}
