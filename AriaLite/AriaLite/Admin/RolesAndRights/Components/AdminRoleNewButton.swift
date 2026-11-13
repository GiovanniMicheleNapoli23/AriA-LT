//
//  AdminRoleNewButton.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il pulsante "Nuovo ruolo" ("Nuovo ruolo base" per un ruolo alto), nella barra e nello stato vuoto.
//

import SwiftUI

struct AdminRoleNewButton: View {
    let viewModel: AdminRolesViewModel

    var body: some View {
        Button { viewModel.startCreating() } label: {
            if viewModel.isHighHolder {
                Label("New Low role", systemImage: "plus")
            } else {
                Label("New role", systemImage: "plus")
            }
        }
    }
}
