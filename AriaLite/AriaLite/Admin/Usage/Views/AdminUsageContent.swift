//
//  AdminUsageContent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il contenuto della pagina Usage secondo il suo stato (contratto 3 e 4): segnaposto per tutta la pagina mentre si legge la
//  config, intestazione e segnaposto mentre si legge il cruscotto, "unavailable" con "Retry", o le schede nell'ordine del
//  contratto. I controlli di fatturazione li disegna un'altra vista.
//

import SwiftUI

struct AdminUsageContent: View {
    let viewModel: AdminUsageViewModel
    let billing: AdminUsageBillingViewModel
    let onAlertAction: (AdminUsageAlertAction) -> Void

    var body: some View {
        // Una VStack e non una Lazy: `scrollTo` su una vista non ancora creata non fa nulla.
        VStack(alignment: .leading, spacing: 16) {
            let state = viewModel.pageState
            heading(isLoading: state == .loadingConfig || state == .loading)
            switch state {
            case .loadingConfig, .loading:
                loading
            case .unavailable:
                AdminUsageUnavailableView(
                    isOnPastCycle: viewModel.isOnPastCycle,
                    retry: { Task { await viewModel.retry() } },
                    back: { viewModel.backToCurrentCycle() })
            case .ready:
                ready
            }
        }
    }

    // MARK: Parti

    private func heading(isLoading: Bool) -> some View {
        AdminUsageHeadingSection(
            title: viewModel.heading?.title,
            facts: viewModel.headingFactsLine,
            isLoading: isLoading,
            options: viewModel.cycleOptions,
            selectedStart: viewModel.selectedCycleStart,
            select: { option in Task { await viewModel.selectCycle(option.cycle) } })
    }

    /// I segnaposto dicono "Loading usage" una volta sola, a VoiceOver.
    private var loading: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdminUsagePlaceholderCard(lines: 3)
            AdminUsagePlaceholderCard(lines: 4)
            AdminUsagePlaceholderCard(lines: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading usage")
    }

    @ViewBuilder
    private var ready: some View {
        if let alert = viewModel.alert {
            AdminUsageAlertBanner(alert: alert, perform: onAlertAction)
        }
        let kpis = viewModel.kpis
        if !kpis.isEmpty { AdminUsageKPIGrid(kpis: kpis) }
        AdminUsageMetersSection(
            state: viewModel.metersState,
            title: viewModel.metersTitle,
            description: viewModel.metersDescription,
            retry: { Task { await viewModel.retryAllowance() } })
        if let chart = viewModel.chart { AdminUsageChartSection(chart: chart) }
        if let breakdown = viewModel.breakdown { AdminUsageBreakdownSection(breakdown: breakdown) }
        if let storage = viewModel.storageState {
            AdminUsageStorageSection(
                state: storage,
                title: viewModel.storageTitle,
                retry: { Task { await viewModel.retryAllowance() } })
        }
        AdminUsageLiveTalkSection(state: viewModel.liveTalkState, title: viewModel.liveTalkTitle)
        limitArea
        if let note = viewModel.footerNote { AdminUsageFooterNote(text: note) }
    }

    /// Un titolare, sul ciclo corrente: i controlli di fatturazione (la scheda del tetto è la prima, l'ancora vale per
    /// "Set a spending limit"). Chiunque altro: la scheda del tetto del membro.
    @ViewBuilder
    private var limitArea: some View {
        if viewModel.showsBillingControls {
            // L'ancora sta sulla scheda del tetto, dentro i controlli (AdminUsageSpendCapSection).
            AdminUsageBillingControls(page: viewModel, billing: billing)
        } else if let limit = viewModel.memberLimit {
            AdminUsageMemberLimitSection(limit: limit)
        }
    }
}
