//
//  AdminUsageNoticeSettingsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Notice settings" (contratto 5.4): tre avvisi, ognuno con le sue regole (`AdminUsageNoticeBlock`). Non c'è
//  "Save": un interruttore, una scelta o un ritorno alla piattaforma salva subito, la soglia quando il campo si lascia. L'intestazione
//  dice "Saving…", "Saved" o "Not saved" (con "Retry" solo se riprovare serve).
//

import SwiftUI

struct AdminUsageNoticeSettingsSection: View {
    let billing: AdminUsageBillingViewModel
    var focus: FocusState<AdminUsageBillingField?>.Binding

    var body: some View {
        let card = billing.noticeSettingsCard
        AdminUsageCardFrame(
            title: Text(verbatim: card?.title ?? String(localized: "usage.noticeSettings.title", defaultValue: "Notice settings")),
            description: card.map { Text(verbatim: $0.description) }
        ) {
            if let card {
                loaded(card)
            } else if billing.settingsPhase == .failed {
                VStack(alignment: .leading, spacing: 10) {
                    AdminUsageBillingAlertBox(text: String(localized: "Notice settings could not be loaded. Notices keep following the last saved settings."))
                    Button("Retry") { Task { await billing.retrySettings() } }
                        .buttonStyle(.bordered)
                        .tint(Color.liteAccent)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .accessibilityLabel("Loading notice settings")
            }
        }
    }

    private func loaded(_ card: AdminUsageNoticeSettingsCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AdminUsageBillingSaveStatus(state: billing.settingsSaver.state, canRetry: billing.settingsCanRetry) {
                billing.retrySettingsSave()
            }
            ForEach(card.notices) { notice in
                Divider().padding(.vertical, 14)
                AdminUsageNoticeBlock(notice: notice, billing: billing, focus: focus)
            }
            if billing.settingsSaveFailed {
                AdminUsageBillingAlertBox(text: String(localized: "The settings were not saved. Try again."))
                    .padding(.top, 14)
            }
            Divider().padding(.vertical, 14)
            AdminUsageBillingDeliveryLine(text: card.delivery, isEmail: card.deliveryIsEmail)
        }
    }
}
