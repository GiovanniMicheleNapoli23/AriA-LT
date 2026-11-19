//
//  AdminUsageBillingControls.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I controlli di fatturazione dei titolari (contratto 5), sotto "Billing controls" · "Only owners see this section.": il
//  limite di spesa e il suo storico (solo con un piano assegnato), i destinatari degli avvisi e le regole degli avvisi. La
//  pagina lo mette come `AdminUsageBillingControls(page:billing:)` solo a un titolare sul ciclo corrente. Si legge da sé
//  all'apertura, al cambio di azienda e al ritorno in primo piano; il pull to refresh della pagina deve chiamare anche
//  `billing.refresh()`.
//

import SwiftUI

struct AdminUsageBillingControls: View {
    let page: AdminUsageViewModel
    let billing: AdminUsageBillingViewModel

    @Environment(\.scenePhase) private var scenePhase
    /// Il campo di testo che ha il fuoco: uno solo per tutta la sezione.
    @FocusState private var focus: AdminUsageBillingField?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Billing controls")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Only owners see this section.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if page.hasPlan {
                AdminUsageSpendCapSection(billing: billing, focus: $focus)
                AdminUsageSpendCapHistorySection(billing: billing)
            }
            AdminUsageNoticeRecipientsSection(billing: billing)
            AdminUsageNoticeSettingsSection(billing: billing, focus: $focus)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Le letture sono silenziose se i dati ci sono già e sono freschi: la vista torna a comparire spesso.
        .task(id: billing.loadKey) { await billing.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await billing.refresh() } }
        }
        // La soglia di un avviso si salva quando il campo si lascia.
        .onChange(of: focus) { old, new in
            if case .threshold(let notice)? = old, old != new { billing.thresholdSettled(notice) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
    }
}
