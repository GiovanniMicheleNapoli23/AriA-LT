//
//  AdminUsageSpendCapSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Spending limit" del titolare (contratto 5.1): prova, nessun limite col campo, o un limite in vigore con
//  "Change" e "Remove limit". Disegna il modello già scritto dal view model e inoltra le azioni. È il bersaglio di
//  "Set a spending limit" dell'avviso (`AdminUsageAnchor.limitCard`), in ogni stato.
//

import SwiftUI

struct AdminUsageSpendCapSection: View {
    let billing: AdminUsageBillingViewModel
    var focus: FocusState<AdminUsageBillingField?>.Binding

    var body: some View {
        Group {
            if let card = billing.spendCapCard {
                AdminUsageCardFrame(title: Text(verbatim: card.title), description: Text(verbatim: card.description)) {
                    VStack(alignment: .leading, spacing: 14) {
                        if let toast = billing.toast { toastView(toast) }
                        content(card.content)
                    }
                }
            }
        }
        .id(AdminUsageAnchor.limitCard)
        .alert(
            billing.capConfirmation?.title ?? "",
            isPresented: Binding(get: { billing.capConfirmation != nil }, set: { if !$0 { billing.dismissConfirmation() } }),
            presenting: billing.capConfirmation
        ) { confirmation in
            Button(confirmation.button, role: .destructive) { billing.confirmLowering(confirmation) }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(verbatim: confirmation.body)
        }
    }

    @ViewBuilder
    private func content(_ content: AdminUsageSpendCapCard.Content) -> some View {
        switch content {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 80)
                .accessibilityLabel("Loading the spending limit")
        case .failed(let text):
            VStack(alignment: .leading, spacing: 10) {
                AdminUsageBillingAlertBox(text: text)
                Button("Retry") { Task { await billing.retrySpendCap() } }
                    .buttonStyle(.bordered)
                    .tint(Color.liteAccent)
            }
        case .trial(let trial):
            AdminUsageSpendCapTrialView(trial: trial)
        case .noLimit(let noLimit):
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    AdminUsageBillingChip(text: noLimit.chip, tone: .over)
                    if let body = noLimit.body {
                        Text(verbatim: body).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                }
                form
            }
        case .inForce(let inForce):
            if billing.isFormShown {
                form
            } else {
                AdminUsageSpendCapInForceView(inForce: inForce, billing: billing)
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        if let form = billing.spendCapForm {
            AdminUsageSpendCapFormView(form: form, billing: billing, focus: focus)
        }
    }

    /// "Spending limit saved" / "Spending limit removed": un messaggio passeggero, annunciato a VoiceOver.
    private func toastView(_ toast: AdminUsageBillingToast) -> some View {
        Label { Text(verbatim: toast.text).font(.footnote.weight(.semibold)) } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.liteSuccess)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.liteSuccess.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .transition(.opacity)
        .id(toast.id)
        .onAppear { AccessibilityNotification.Announcement(toast.text).post() }
    }
}
