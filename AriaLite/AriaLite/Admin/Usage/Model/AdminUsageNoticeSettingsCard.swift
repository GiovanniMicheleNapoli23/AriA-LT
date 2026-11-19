//
//  AdminUsageNoticeSettingsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Notice settings" (contratto 5.4) già scritta: tre avvisi, sei controlli ciascuno. Un'impostazione che
//  l'azienda ha cambiato porta il chip "Custom" e l'azione "Use platform value: {platform}".
//

import Foundation

nonisolated struct AdminUsageNoticeSettingsCard: Sendable, Equatable {
    /// "Notice settings".
    var title: String
    /// "How each usage notice reaches your company. A setting you leave alone follows the platform."
    var description: String
    var notices: [Notice]
    /// "Notices arrive in the app and by email." o "…Email delivery is coming soon."
    var delivery: String
    var deliveryIsEmail: Bool

    nonisolated struct Notice: Sendable, Equatable, Identifiable {
        var key: AriaNoticeKey
        var id: AriaNoticeKey { key }
        /// "Daily credits", "Spending limit approaching", "Extra credits".
        var title: String
        /// "Fires when": quando scatta e a chi arriva il banner.
        var firesWhen: String
        var threshold: Threshold
        var recipients: Recipients
        var repeatPolicy: Repeat
        var banner: Switch
        var email: Switch
        /// "Use platform settings": c'è almeno un valore dell'azienda.
        var showsUsePlatformSettings: Bool
        var usePlatformSettingsLabel: String
    }

    /// Una scelta di un'impostazione che l'azienda può riportare al valore della piattaforma.
    nonisolated struct Customization: Sendable, Equatable {
        /// Chip "Custom": l'azienda ha un valore suo.
        var isCustom: Bool
        /// "Use platform value: {platform}"; `nil` se l'impostazione segue la piattaforma.
        var resetLabel: String?
    }

    nonisolated struct Threshold: Sendable, Equatable {
        /// "Notify when the company uses" / "Notify when extra credits reach".
        var lead: String
        /// "of today's credits" / "of the limit" / "of included credits".
        var unit: String
        /// La percentuale scritta nel campo ("60", "62.5").
        var text: String
        /// "Enter a percentage from 1 to 100." / "Enter 100% or more."
        var error: String?
        var customization: Customization
    }

    nonisolated struct Recipients: Sendable, Equatable {
        /// "Sent to".
        var label: String
        /// "Owners", "Owners and members" o i nomi delle persone scelte.
        var text: String
        /// Le persone scelte per questo avviso (al posto dei ruoli).
        var userIds: [String]
        /// I ruoli avvisati (`owner`, `member`).
        var roles: [String]
        var customization: Customization
        /// Una persona scelta che non è più un membro attivo: "{name} is no longer an active member…".
        var inactiveNotes: [String]
    }

    nonisolated struct Repeat: Sendable, Equatable {
        /// "Repeat".
        var label: String
        /// `nil` è "Standard".
        var selection: AriaNoticeRepeat?
        /// "Standard" c'è solo dove il valore della piattaforma è `null`.
        var options: [Option]
        /// "Once a billing cycle. If extra credits are counted per day…": sotto "Standard".
        var hint: String?
        var customization: Customization

        nonisolated struct Option: Sendable, Equatable, Identifiable {
            var value: AriaNoticeRepeat?
            var title: String
            var id: String { value?.rawValue ?? "standard" }
        }
    }

    nonisolated struct Switch: Sendable, Equatable {
        var label: String
        var isOn: Bool
        /// L'interruttore dell'email resta spento finché `config.notifications.email_enabled` non è `true`.
        var isEnabled: Bool
        /// "Soon": accanto all'email disabilitata.
        var chip: String?
        var customization: Customization
    }
}
