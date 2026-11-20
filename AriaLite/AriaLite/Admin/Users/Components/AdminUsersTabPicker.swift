//
//  AdminUsersTabPicker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La scelta tra Users e Roles in cima alla sezione Users, nella barra di navigazione delle due viste.
//

import SwiftUI

struct AdminUsersTabPicker: View {
    @Bindable var section: AdminUsersSectionViewModel

    var body: some View {
        Picker("View", selection: $section.selected) {
            ForEach(section.tabs) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .sensoryFeedback(.selection, trigger: section.selected)
        .accessibilityIdentifier("users.tabs")
    }
}
