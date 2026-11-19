//
//  AdminUsageNoticeBlock.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Un avviso di "Notice settings": il titolo e quando scatta, poi i sei controlli (soglia, destinatari, ripetizione, banner
//  nell'app, email). Un'impostazione dell'azienda porta "Custom" e "Use platform value: …"; "Use platform settings" riporta
//  tutto l'avviso alla piattaforma. La soglia si salva quando il campo si lascia.
//

import SwiftUI

struct AdminUsageNoticeBlock: View {
    let notice: AdminUsageNoticeSettingsCard.Notice
    let billing: AdminUsageBillingViewModel
    var focus: FocusState<AdminUsageBillingField?>.Binding

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var choosingPeople = false
    @ScaledMetric(relativeTo: .body) private var fieldWidth: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: notice.title).font(.headline).accessibilityAddTraits(.isHeader)
                Text(verbatim: notice.firesWhen).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            threshold
            recipients
            repeatPolicy
            banner
            email
            if notice.showsUsePlatformSettings {
                Button { billing.usePlatformSettings(notice.key) } label: {
                    Label { Text(verbatim: notice.usePlatformSettingsLabel) } icon: { Image(systemName: "arrow.counterclockwise") }
                }
                .buttonStyle(.bordered)
                .tint(Color.liteAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear { billing.thresholdSettled(notice.key) }
        .sheet(isPresented: $choosingPeople) { AdminUsageNoticePeopleSheet(billing: billing, notice: notice.key) }
    }

    // MARK: Soglia

    private var threshold: some View {
        let t = notice.threshold
        return AdminUsageNoticeSettingRow(customization: t.customization, onReset: { billing.usePlatform(notice.key, .threshold) }) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: t.lead).font(.subheadline)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField(text: Binding(get: { t.text }, set: { billing.thresholdChanged(notice.key, $0) })) {
                        Text(verbatim: t.lead)
                    }
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospacedDigit())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: fieldWidth)
                    .focused(focus, equals: .threshold(notice.key))
                    .accessibilityLabel(Text(verbatim: "\(notice.title) · \(t.lead)"))
                    Text(verbatim: "%").font(.body).foregroundStyle(.secondary)
                    Text(verbatim: t.unit).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                if let error = t.error {
                    Text(verbatim: error).font(.footnote).foregroundStyle(Color.liteDanger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Destinatari

    private var recipients: some View {
        let r = notice.recipients
        return AdminUsageNoticeSettingRow(customization: r.customization, onReset: { billing.usePlatformRecipients(notice.key) }) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: r.label).font(.subheadline)
                Button { choosingPeople = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2").accessibilityHidden(true)
                        Text(verbatim: r.text).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(Color.liteAccent)
                .accessibilityLabel(Text(verbatim: "\(r.label): \(r.text)"))
                ForEach(r.inactiveNotes, id: \.self) { AdminUsageBillingAlertBox(text: $0) }
            }
        }
    }

    // MARK: Ripetizione

    private var repeatPolicy: some View {
        let r = notice.repeatPolicy
        return AdminUsageNoticeSettingRow(customization: r.customization, onReset: { billing.usePlatform(notice.key, .repeatPolicy) }) {
            VStack(alignment: .leading, spacing: 6) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
                layout {
                    Text(verbatim: r.label).font(.subheadline)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Picker(selection: Binding(get: { r.selection }, set: { billing.setRepeat(notice.key, $0) })) {
                        ForEach(r.options) { option in Text(verbatim: option.title).tag(option.value) }
                    } label: {
                        Text(verbatim: r.label)
                    }
                    .pickerStyle(.menu)
                    .tint(Color.liteAccent)
                }
                if let hint = r.hint {
                    Text(verbatim: hint).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Canali

    private var banner: some View {
        AdminUsageNoticeSettingRow(customization: notice.banner.customization, onReset: { billing.usePlatform(notice.key, .banner) }) {
            Toggle(isOn: Binding(get: { notice.banner.isOn }, set: { billing.setBanner(notice.key, $0) })) {
                Text(verbatim: notice.banner.label).font(.subheadline)
            }
            .tint(Color.liteAccent)
        }
    }

    private var email: some View {
        AdminUsageNoticeSettingRow(customization: notice.email.customization, onReset: { billing.usePlatform(notice.key, .email) }) {
            Toggle(isOn: Binding(get: { notice.email.isOn }, set: { billing.setEmail(notice.key, $0) })) {
                HStack(spacing: 8) {
                    Text(verbatim: notice.email.label).font(.subheadline)
                    if let chip = notice.email.chip { AdminUsageBillingChip(text: chip, tone: .over) }
                }
            }
            .tint(Color.liteAccent)
            .disabled(!notice.email.isEnabled)
        }
    }
}

/// Un controllo con, sotto, "Custom" e "Use platform value: …" se l'azienda ha un valore suo.
struct AdminUsageNoticeSettingRow<Content: View>: View {
    let customization: AdminUsageNoticeSettingsCard.Customization
    let onReset: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            if customization.isCustom {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    AdminUsageBillingChip(text: String(localized: "usage.noticeSettings.custom", defaultValue: "Custom"))
                    if let reset = customization.resetLabel {
                        Button(action: onReset) { Text(verbatim: reset).font(.footnote).multilineTextAlignment(.leading) }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.liteAccent)
                    }
                }
            }
        }
    }
}
