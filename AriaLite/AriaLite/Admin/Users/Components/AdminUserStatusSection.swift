//
//  AdminUserStatusSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Stato (§5.7), in fondo alla scheda: sospendere o riattivare, e rimuovere dall'azienda. Mai su se stessi.
//  Mentre una scrittura della persona è in corso i pulsanti sono spenti.
//

import SwiftUI

struct AdminUserStatusSection: View {
    let viewModel: AdminUserDetailViewModel

    var body: some View {
        let controls = viewModel.controls
        if controls.suspend || controls.reactivate || controls.remove {
            Section {
                if controls.suspend {
                    Button {
                        viewModel.askSuspend()
                    } label: {
                        Label("Suspend", systemImage: "pause.circle")
                    }
                }
                if controls.reactivate {
                    Button {
                        viewModel.reactivate()
                    } label: {
                        Label("Reactivate", systemImage: "play.circle")
                    }
                }
                if controls.remove {
                    Button(role: .destructive) {
                        viewModel.askRemove()
                    } label: {
                        Label("Remove from workspace", systemImage: "person.crop.circle.badge.minus")
                    }
                }
            } header: {
                Text("Status")
            }
            .disabled(viewModel.isWorking)
        }
    }
}
