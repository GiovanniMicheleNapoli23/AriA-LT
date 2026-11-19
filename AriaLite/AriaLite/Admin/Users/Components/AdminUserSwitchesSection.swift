//
//  AdminUserSwitchesSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Gli interruttori "App access" e "Field worker" (§5.3), solo per i titolari. Leggono la riga dell'elenco: se la
//  conferma di spegnimento si annulla, tornano com'erano. Mentre una scrittura è in corso sono spenti.
//

import SwiftUI

struct AdminUserSwitchesSection: View {
    let viewModel: AdminUserDetailViewModel

    var body: some View {
        let controls = viewModel.controls
        if controls.appSwitch {
            Section {
                Toggle("App access", isOn: Binding(get: { viewModel.appAccessIsOn },
                                                   set: { viewModel.setAppAccess($0) }))
                    .disabled(controls.appSwitchLockedOnSelf || viewModel.isWorking)
            } footer: {
                Text(verbatim: viewModel.appSwitchFooter)
            }
        }
        if controls.fieldSwitch {
            Section {
                Toggle("Field worker", isOn: Binding(get: { viewModel.fieldWorkerIsOn },
                                                     set: { viewModel.setFieldWorker($0) }))
                    .disabled(viewModel.isWorking)
            } footer: {
                Text("Can be sent work and appears in the assignee lists.")
            }
        }
    }
}
