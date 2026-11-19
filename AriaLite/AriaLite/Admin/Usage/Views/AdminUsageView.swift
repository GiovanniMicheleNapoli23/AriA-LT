//
//  AdminUsageView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La schermata Usage dell'amministrazione: l'unica radice (NavigationStack, ScrollView) in ogni stato della pagina, così
//  il "pull to refresh" funziona anche quando i dati non ci sono. Disegna i modelli già pronti di `AdminUsageViewModel`;
//  l'azione "Set a spending limit" dell'avviso scorre alla scheda del tetto (`AdminUsageAnchor.limitCard`).
//

import SwiftUI

struct AdminUsageView: View {
    let viewModel: AdminUsageViewModel
    let billing: AdminUsageBillingViewModel

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    AdminUsageContent(
                        viewModel: viewModel,
                        billing: billing,
                        onAlertAction: { action in
                            viewModel.perform(
                                action,
                                scrollToLimit: {
                                    withAnimation { proxy.scrollTo(AdminUsageAnchor.limitCard, anchor: .top) }
                                },
                                open: { openURL($0) })
                        })
                    .padding(16)
                    .ariaReadableWidth()
                }
                .refreshable {
                    // Pull to refresh: la pagina e, per i titolari, tetto, storico e avvisi.
                    async let page: Void = viewModel.refresh()
                    async let controls: Void = billing.refresh()
                    _ = await (page, controls)
                }
                .task(id: viewModel.loadKey) { await viewModel.load() }
            }
            .liteBackground()
            .navigationTitle("LLM Usage")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
        }
    }
}
