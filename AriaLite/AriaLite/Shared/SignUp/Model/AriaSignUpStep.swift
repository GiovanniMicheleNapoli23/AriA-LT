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

    /// `nil`: l'onboarding è finito. `hasPlant` conta solo con l'azienda creata. `memberOnly`: si è entrati
    /// nell'azienda di qualcun altro (nessun `onboardingCompany` da owner o admin): si compila solo il profilo, e a
    /// profilo fatto si entra, come sulla web.
    init?(_ status: AriaSignUpStatus, hasPlant: Bool, memberOnly: Bool = false) {
        if status.onboardingComplete { return nil }
        if memberOnly {
            guard !status.profileComplete else { return nil }
            self = .profile
        } else if !status.profileComplete {
            self = .profile
        } else if !status.companyCreated {
            self = .company
        } else if !hasPlant {
            self = .plant
        } else {
            self = .plan
        }
    }

    /// I titoli della web (`onboarding.step.<passo>.title`).
    var title: LocalizedStringResource {
        switch self {
        case .profile: "Your profile"
        case .company: "Your company"
        case .plant: "Your first site"
        case .plan: "Choose your plan"
        }
    }

    /// I sottotitoli della web; il membro ha il suo, come la pagina unica.
    func subtitle(memberOnly: Bool) -> LocalizedStringResource {
        switch self {
        case .profile: memberOnly ? "Tell your team who you are." : "How your team will see you"
        case .company: "Set up your AriA workspace"
        case .plant: "Aria works site by site: add the first one to start chatting. You can add more later."
        case .plan: "Paid plans aren't available yet. You'll be able to move from the trial when they are."
        }
    }
}
