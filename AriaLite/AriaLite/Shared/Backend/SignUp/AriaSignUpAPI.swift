//
//  AriaSignUpAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  L'onboarding di chi si iscrive dall'app (contratto "Onboarding in the app", 10/11/26): Profilo, Azienda, Piano,
//  con le stesse chiamate della web, più il primo stabilimento. Tutte senza il Company-Id del contesto: l'azienda
//  non c'è ancora, la creano questi passi.
//    GET   /v1/onboarding/status           → i quattro flag (AriaSignUpStatus)
//    PATCH /v1/me                          → nome, ruolo, telefono e lingua; risponde con tutto GET /v1/me
//    GET   /v1/companies/check-slug?slug=  → {"available", "slug"}; confronta lo slug così com'è
//    POST  /v1/companies                   → 201, l'azienda e la membership di owner. Solo per chi si è appena
//                                            iscritto: chi ha già un'azienda riceve 403 `operator_identity_forbidden`.
//                                            Uno slug preso nel frattempo risponde 500 generico, non 409.
//    GET   /v1/companies                   → per ritrovare l'azienda propria quando si riapre l'app a metà
//    GET   /v1/plants, POST /v1/plants     → il primo stabilimento (la chat senza non risponde), con il Company-Id
//                                            dell'azienda appena creata messo a mano.
//  La fine (piano e onboarding completo) è sulla web, con la sessione: AriaAuth.finishOnboarding.
//

import Foundation

/// GET /v1/onboarding/status. Chi è entrato in un'azienda altrui legge `companyCreated` e `planSelected` veri.
nonisolated struct AriaSignUpStatus: Decodable, Sendable, Equatable {
    let profileComplete: Bool
    let companyCreated: Bool
    let planSelected: Bool
    let onboardingComplete: Bool

    init(profileComplete: Bool, companyCreated: Bool, planSelected: Bool, onboardingComplete: Bool) {
        self.profileComplete = profileComplete
        self.companyCreated = companyCreated
        self.planSelected = planSelected
        self.onboardingComplete = onboardingComplete
    }

    private enum CodingKeys: String, CodingKey { case profileComplete, companyCreated, planSelected, onboardingComplete }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profileComplete = try c.decodeIfPresent(Bool.self, forKey: .profileComplete) ?? false
        companyCreated = try c.decodeIfPresent(Bool.self, forKey: .companyCreated) ?? false
        planSelected = try c.decodeIfPresent(Bool.self, forKey: .planSelected) ?? false
        onboardingComplete = try c.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? false
    }
}

/// Body di PATCH /v1/me al passo Profilo. Il backend non controlla i valori: le regole della web le applica l'app.
/// `phone` assente non si manda (un `null` lascerebbe il campo com'è).
nonisolated struct AriaProfileUpdate: Encodable, Sendable, Equatable {
    let name: String
    let jobRole: String
    let phone: String?
    let preferredLocale: String
}

/// Body di POST /v1/companies. Mai `plan`: lo sceglie la chiamata finale. `industry` e `size` assenti non si mandano.
nonisolated struct AriaNewCompany: Encodable, Sendable, Equatable {
    let name: String
    let slug: String
    let industry: String?
    let size: String?
}

/// GET /v1/companies/check-slug.
nonisolated struct AriaSlugCheck: Decodable, Sendable, Equatable {
    let available: Bool
    let slug: String?
}

/// Errori dell'onboarding che l'app tratta a parte.
nonisolated enum AriaSignUpError: LocalizedError, Sendable, Equatable {
    /// POST /api/auth/onboarding/finish 409 `no_company`: si torna al passo Azienda.
    case noCompany
    /// POST /api/auth/onboarding/finish 422 `plan_not_allowed`: dall'app parte solo `free_demo`.
    case planNotAllowed
    /// POST /api/auth/onboarding/finish 502 `backend_error`: il backend ha rifiutato o non risponde.
    case finishFailed

    var errorDescription: String? {
        switch self {
        case .noCompany: String(localized: "Create your company first.")
        case .planNotAllowed: String(localized: "This plan isn't available yet. Choose the free demo.")
        case .finishFailed: String(localized: "Could not finish onboarding. Try again in a moment.")
        }
    }
}

nonisolated struct AriaSignUpAPI: Sendable {
    let api: AriaAPIClient

    /// Il piano che l'app offre: gli altri sulla web sono tutti "in arrivo", e la chiamata finale li rifiuta.
    static let freeDemoPlan = "free_demo"

    func status() async throws -> AriaSignUpStatus {
        try await api.call(Self.endpoint("GET", "v1/onboarding/status"))
    }

    /// Risponde con GET /v1/me aggiornato.
    func updateProfile(_ profile: AriaProfileUpdate) async throws -> AriaMe {
        try await api.call(Self.endpoint("PATCH", "v1/me", body: profile))
    }

    /// `slug` va mandato già normalizzato (AriaSlug): il backend confronta il testo così com'è.
    func checkSlug(_ slug: String) async throws -> AriaSlugCheck {
        try await api.call(Self.endpoint("GET", "v1/companies/check-slug", query: [URLQueryItem(name: "slug", value: slug)]))
    }

    /// L'`id` della risposta è il Company-Id da qui in poi.
    func createCompany(_ company: AriaNewCompany) async throws -> AriaCompany {
        try await api.call(Self.endpoint("POST", "v1/companies", body: company))
    }

    func companies() async throws -> [AriaCompany] {
        try await api.call(Self.endpoint("GET", "v1/companies"))
    }

    func plants(companyId: String) async throws -> [AriaPlant] {
        try await api.call(Self.endpoint("GET", "v1/plants", companyId: companyId))
    }

    /// La risposta non serve: dopo si rilegge l'elenco.
    func createPlant(_ plant: AdminPlantCreate, companyId: String) async throws {
        let _: AriaNoContent = try await api.call(Self.endpoint("POST", "v1/plants", body: plant, companyId: companyId)
            .snakeCased())
    }

    /// Sempre senza Company-Id del contesto: un'azienda rimasta da un altro account farebbe rispondere 403 `not_a_member`.
    /// `companyId`: le rotte degli stabilimenti, con l'azienda appena creata (il contesto non la conosce ancora).
    private static func endpoint<Response>(_ method: String, _ path: String, query: [URLQueryItem] = [],
                                           body: (any Encodable & Sendable)? = nil,
                                           companyId: String? = nil) -> AriaEndpoint<Response> {
        AriaEndpoint(method: method, path: path, query: query, body: body,
                     headers: companyId.map { ["Company-Id": $0] } ?? [:], companyScoped: false)
    }
}
