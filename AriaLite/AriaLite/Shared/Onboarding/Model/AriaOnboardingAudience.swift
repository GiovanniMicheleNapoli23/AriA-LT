//
//  AriaOnboardingAudience.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Per chi è la presentazione: la si sceglie nella prima schermata. Vale solo per la presentazione:
//  quello che l'app mostra davvero lo decide l'account dopo l'accesso (/v1/me).
//

import Foundation

nonisolated enum AriaOnboardingAudience: String, CaseIterable, Identifiable, Sendable {
    case technician
    case admin

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .technician: "Technician"
        case .admin: "Admin"
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .technician: "Field work: chat with Aria, your jobs and guided procedures."
        case .admin: "The whole platform: documents, agents, assets, reports and team."
        }
    }

    var symbol: String {
        switch self {
        case .technician: "wrench.adjustable"
        case .admin: "person.badge.shield.checkmark"
        }
    }

    var pages: [AriaOnboardingPage] {
        switch self {
        case .technician: AriaOnboardingPage.technician
        case .admin: AriaOnboardingPage.admin
        }
    }
}
