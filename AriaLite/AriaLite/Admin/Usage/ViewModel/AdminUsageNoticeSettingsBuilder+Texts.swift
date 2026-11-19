//
//  AdminUsageNoticeSettingsBuilder+Texts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I testi fissi di "Notice settings": il titolo di ogni avviso, quando scatta, la frase della soglia, i nomi della ripetizione
//  e "On" / "Off" (`usage.noticeSettings` della web).
//

import Foundation

nonisolated extension AdminUsageNoticeSettingsBuilder {
    static func repeatName(_ value: AriaNoticeRepeat?) -> String {
        switch value {
        case nil: String(localized: "usage.noticeSettings.repeat.standard", defaultValue: "Standard")
        case .oncePerDay?: String(localized: "usage.noticeSettings.repeat.day", defaultValue: "Once a day")
        case .oncePerWeek?: String(localized: "usage.noticeSettings.repeat.week", defaultValue: "Once a week")
        case .oncePerCycle?: String(localized: "usage.noticeSettings.repeat.cycle", defaultValue: "Once a billing cycle")
        }
    }

    static func onOff(_ value: Bool?) -> String {
        value == true
            ? String(localized: "usage.noticeSettings.on", defaultValue: "On")
            : String(localized: "usage.noticeSettings.off", defaultValue: "Off")
    }

    static func title(_ key: AriaNoticeKey) -> String {
        switch key {
        case .dailyAllowance: String(localized: "usage.noticeSettings.daily.title", defaultValue: "Daily credits")
        case .capApproaching: String(localized: "usage.noticeSettings.cap.title", defaultValue: "Spending limit approaching")
        case .overage: String(localized: "usage.noticeSettings.overage.title", defaultValue: "Extra credits")
        }
    }

    static func firesWhen(_ key: AriaNoticeKey) -> String {
        switch key {
        case .dailyAllowance:
            String(localized: "When the company reaches this share of today's included credits. The banner shows to everyone, in credits only.")
        case .capApproaching:
            String(localized: "When extra credits this cycle reach this share of the spending limit. The banner shows to owners.")
        case .overage:
            String(localized: "When the company starts using extra credits, past its included credits. The banner shows to owners.")
        }
    }

    static func lead(_ key: AriaNoticeKey) -> String {
        switch key {
        case .dailyAllowance, .overage: String(localized: "Notify when the company uses")
        case .capApproaching: String(localized: "Notify when extra credits reach")
        }
    }

    static func unit(_ key: AriaNoticeKey) -> String {
        switch key {
        case .dailyAllowance: String(localized: "of today's credits")
        case .capApproaching: String(localized: "of the limit")
        case .overage: String(localized: "of included credits")
        }
    }
}
