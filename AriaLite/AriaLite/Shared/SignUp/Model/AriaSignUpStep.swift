//
//  AriaSignUpStep.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  I passi dell'iscrizione, nell'ordine della web più lo stabilimento. Quale tocca lo dice GET /v1/onboarding/status:
//  onboarding finito → l'app; senza nome → Profilo; senza azienda → Azienda; azienda senza stabilimenti (lo stato non
//  lo dice: si legge GET /v1/plants) → Stabilimento; altrimenti Piano, qualunque cosa dica `planSelected` (solo
//  `onboardingComplete` chiude l'onboarding).
//

import Foundation

nonisolated enum AriaSignUpStep: Int, CaseIterable, Sendable, Identifiable {
    case profile
    case company
    case plant
    case plan

    var id: Int { rawValue }

    /// `nil`: l'onboarding è finito. `hasPlant` conta solo con l'azienda creata.
    init?(_ status: AriaSignUpStatus, hasPlant: Bool) {
        if status.onboardingComplete { return nil }
        if !status.profileComplete {
            self = .profile
        } else if !status.companyCreated {
            self = .company
        } else if !hasPlant {
            self = .plant
        } else {
            self = .plan
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .profile: "About you"
        case .company: "Your company"
        case .plant: "Your first site"
        case .plan: "Your plan"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .profile: "Tell us who you are, so Aria can help you the right way."
        case .company: "Create the company your team will work in."
        case .plant: "Aria works site by site: add the first one to start chatting. You can add more later."
        case .plan: "Start with the free demo. You can change plan later."
        }
    }
}
