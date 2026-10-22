//
//  AdminCompanySettingsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Settings, come la pagina /settings della web: l'azienda attiva e la Danger zone.
//  Lo sheet di conferma compare quando la VM ha una cancellazione in attesa.
//

import SwiftUI

struct AdminCompanySettingsView: View {
    @Bindable var viewModel: AdminCompanySettingsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AdminCompanySettingsInfoCard(viewModel: viewModel)
                    AdminCompanySettingsDangerZone(viewModel: viewModel)
                }
                .padding(16)
                .ariaReadableWidth()
            }
            .liteBackground()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
            .sheet(item: $viewModel.target, onDismiss: { viewModel.sheetDismissed() }) { target in
                AdminCompanySettingsDeletionSheet(viewModel: viewModel, target: target)
            }
        }
    }
}
