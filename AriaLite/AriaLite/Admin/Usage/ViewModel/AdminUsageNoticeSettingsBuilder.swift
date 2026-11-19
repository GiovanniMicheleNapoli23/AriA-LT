//
//  AdminUsageNoticeSettingsBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Notice settings" (contratto 5.4, `notice-settings.tsx` della web): per ogni avviso la soglia, i
//  destinatari, la ripetizione e i due canali. Si mostra `resolved`; un'impostazione con `company` diverso da `null` porta
//  "Custom" e "Use platform value: {platform}". Funzioni pure: lo stato di scrittura (testo della soglia, errori, persone
//  rifiutate) arriva in `AdminUsageNoticeSettingsInput`.
//

import Foundation

nonisolated struct AdminUsageNoticeSettingsInput: Sendable {
    /// Quello che si sta scrivendo nel campo della soglia (come testo), per avviso.
    var thresholdDrafts: [AriaNoticeKey: String] = [:]
    /// Le soglie che non si possono salvare.
    var thresholdErrors: [AriaNoticeKey: AdminUsageNoticeThresholdError] = [:]
    /// Le persone che l'ultimo salvataggio ha rifiutato (422 `recipient_not_active_member`).
    var inactiveIds: [String] = []
    var emailEnabled = false

    init(thresholdDrafts: [AriaNoticeKey: String] = [:], thresholdErrors: [AriaNoticeKey: AdminUsageNoticeThresholdError] = [:],
         inactiveIds: [String] = [], emailEnabled: Bool = false) {
        self.thresholdDrafts = thresholdDrafts
        self.thresholdErrors = thresholdErrors
        self.inactiveIds = inactiveIds
        self.emailEnabled = emailEnabled
    }
}

nonisolated enum AdminUsageNoticeSettingsBuilder {
    /// I ruoli che un avviso può avvisare, nell'ordine in cui si scrivono.
    static let roles = ["owner", "member"]

    /// - `names`: il nome di una persona per id (`AdminUsageViewModel.personName`).
    static func card(_ settings: AriaNoticeSettings, input: AdminUsageNoticeSettingsInput, locale: Locale,
                     names: (String) -> AdminUsagePersonName) -> AdminUsageNoticeSettingsCard {
        AdminUsageNoticeSettingsCard(
            title: String(localized: "usage.noticeSettings.title", defaultValue: "Notice settings"),
            description: String(localized: "How each usage notice reaches your company. A setting you leave alone follows the platform."),
            notices: AriaNoticeKey.allCases.map { notice(settings[$0], key: $0, input: input, locale: locale, names: names) },
            delivery: input.emailEnabled
                ? String(localized: "Notices arrive in the app and by email.")
                : String(localized: "Notices arrive in the app. Email delivery is coming soon."),
            deliveryIsEmail: input.emailEnabled)
    }

    static func notice(_ rule: AriaNoticeRule, key: AriaNoticeKey, input: AdminUsageNoticeSettingsInput, locale: Locale,
                       names: (String) -> AdminUsagePersonName) -> AdminUsageNoticeSettingsCard.Notice {
        let thresholdCard = threshold(rule, key: key, input: input, locale: locale)
        let recipientsCard = recipients(rule, input: input, locale: locale, names: names)
        let repeatCard = repeatPolicy(rule)
        let banner = AdminUsageNoticeSettingsCard.Switch(
            label: String(localized: "usage.noticeSettings.inApp", defaultValue: "In app"),
            isOn: rule.banner.resolved ?? rule.banner.platform ?? false, isEnabled: true, chip: nil,
            customization: customization(rule.banner, value: onOff))
        let email = AdminUsageNoticeSettingsCard.Switch(
            label: String(localized: "usage.noticeSettings.email", defaultValue: "Email"),
            isOn: rule.email.resolved ?? rule.email.platform ?? false,
            // Il canale email non funziona finché la piattaforma non lo manda: l'interruttore resta spento.
            isEnabled: input.emailEnabled,
            chip: input.emailEnabled ? nil : String(localized: "usage.noticeSettings.soon", defaultValue: "Soon"),
            customization: customization(rule.email, value: onOff))
        let anyCustom = [thresholdCard.customization, recipientsCard.customization, repeatCard.customization,
                         banner.customization, email.customization].contains { $0.isCustom }
        return AdminUsageNoticeSettingsCard.Notice(
            key: key, title: title(key), firesWhen: firesWhen(key),
            threshold: thresholdCard, recipients: recipientsCard, repeatPolicy: repeatCard, banner: banner, email: email,
            showsUsePlatformSettings: anyCustom,
            usePlatformSettingsLabel: String(localized: "Use platform settings"))
    }

    // MARK: Soglia

    private static func threshold(_ rule: AriaNoticeRule, key: AriaNoticeKey, input: AdminUsageNoticeSettingsInput,
                                  locale: Locale) -> AdminUsageNoticeSettingsCard.Threshold {
        let resolved = rule.threshold.resolved ?? rule.threshold.platform
        let text = input.thresholdDrafts[key] ?? resolved.map { AdminUsageFormat.thresholdPercent($0, locale: locale) } ?? ""
        let platform = rule.threshold.platform.map { AdminUsageFormat.thresholdPercent($0, locale: locale) + "%" } ?? "—"
        return AdminUsageNoticeSettingsCard.Threshold(
            lead: lead(key), unit: unit(key), text: text, error: input.thresholdErrors[key]?.text,
            customization: customization(rule.threshold, value: { _ in platform }))
    }

    // MARK: Destinatari

    private static func recipients(_ rule: AriaNoticeRule, input: AdminUsageNoticeSettingsInput, locale: Locale,
                                   names: (String) -> AdminUsagePersonName) -> AdminUsageNoticeSettingsCard.Recipients {
        let roles = orderedRoles(rule.tenantRecipients.resolved ?? rule.tenantRecipients.platform ?? ["owner"])
        // Le persone scelte per questo avviso soltanto: prendono il posto dei ruoli.
        let people = rule.userIds.resolved ?? []
        let text = people.isEmpty
            ? rolesText(roles, locale: locale)
            : people.map { names($0).text ?? "…" }.joined(separator: ", ")
        let platformRoles = orderedRoles(rule.tenantRecipients.platform ?? ["owner"])
        let isCustom = rule.tenantRecipients.isCustom || !(rule.userIds.company ?? []).isEmpty
        let reset = isCustom ? String(localized: "Use platform value: \(rolesText(platformRoles, locale: locale))") : nil
        let notes = people.filter { input.inactiveIds.contains($0) }.map { id -> String in
            let name = names(id).text ?? AdminUsagePersonName.formerMember.text ?? ""
            return String(localized: "\(name) is no longer an active member and can't receive notices. Remove them to save again.")
        }
        return AdminUsageNoticeSettingsCard.Recipients(
            label: String(localized: "usage.noticeSettings.sentTo", defaultValue: "Sent to"), text: text,
            userIds: people, roles: roles,
            customization: AdminUsageNoticeSettingsCard.Customization(isCustom: isCustom, resetLabel: reset),
            inactiveNotes: notes)
    }

    /// "Owners", "Members" o "Owners and members": i ruoli a parole, la prima lettera maiuscola.
    static func rolesText(_ roles: [String], locale: Locale) -> String {
        let words = orderedRoles(roles).map { role in
            role == "owner"
                ? String(localized: "usage.noticeSettings.role.owner", defaultValue: "owners")
                : String(localized: "usage.noticeSettings.role.member", defaultValue: "members")
        }
        return AdminUsageFormat.capitalized(AdminUsageFormat.list(words, locale: locale), locale: locale)
    }

    /// I ruoli noti nell'ordine `owner`, `member`, senza doppioni.
    static func orderedRoles(_ roles: [String]) -> [String] {
        self.roles.filter { roles.contains($0) }
    }

    // MARK: Ripetizione

    private static func repeatPolicy(_ rule: AriaNoticeRule) -> AdminUsageNoticeSettingsCard.Repeat {
        let selection = rule.repeatPolicy.resolved ?? rule.repeatPolicy.platform
        // "Standard" (`null`) lo offre solo chi ha `null` come valore della piattaforma: l'azienda non lo può fissare.
        var options: [AdminUsageNoticeSettingsCard.Repeat.Option] = []
        if rule.repeatPolicy.platform == nil {
            options.append(.init(value: nil, title: repeatName(nil)))
        }
        options += AriaNoticeRepeat.allCases.map { .init(value: $0, title: repeatName($0)) }
        return AdminUsageNoticeSettingsCard.Repeat(
            label: String(localized: "usage.noticeSettings.repeat", defaultValue: "Repeat"),
            selection: selection, options: options,
            hint: selection == nil
                ? String(localized: "Once a billing cycle. If extra credits are counted per day, the notice shows in the app each day and is emailed once a billing cycle.")
                : nil,
            customization: customization(rule.repeatPolicy, value: { repeatName($0) }))
    }

    // MARK: Pezzi

    /// "Custom" e "Use platform value: {platform}" per un'impostazione che l'azienda ha cambiato.
    private static func customization<Value>(_ field: AriaNoticeField<Value>, value: (Value?) -> String) -> AdminUsageNoticeSettingsCard.Customization {
        guard field.isCustom else { return .init(isCustom: false, resetLabel: nil) }
        let platform = value(field.platform)
        return .init(isCustom: true, resetLabel: String(localized: "Use platform value: \(platform)"))
    }
}
