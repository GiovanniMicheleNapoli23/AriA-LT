//
//  AriaBackend.swift
//  AriaLite
//
//  Stato della connessione al backend Aria: login, azienda e stabilimento attivi.
//  È separato dal login locale (mock) dell'app: la chat usa il backend solo
//  quando `isReady`, altrimenti ricade sul motore locale.
//

import Foundation
import Observation

@Observable
final class AriaBackend {
    private(set) var api: AriaAPIClient
    private(set) var isSignedIn: Bool
    private(set) var companies: [AriaCompany] = []
    private(set) var plants: [AriaPlant] = []
    private(set) var activeCompanyId: String?
    private(set) var activePlantId: String?
    private(set) var isLoading = false
    var lastError: String?

    @ObservationIgnored private var didBootstrap = false

    init() {
        let api = Self.makeClient(.current)
        self.api = api
        isSignedIn = api.auth.hasStoredSession
        activeCompanyId = UserDefaults.standard.string(forKey: "aria.company_id")
        activePlantId = UserDefaults.standard.string(forKey: "aria.plant_id")
    }

    /// La chat può parlare col backend: serve una sessione e uno stabilimento (`plant_id` è obbligatorio).
    var isReady: Bool { isSignedIn && activePlantId != nil }

    var serverURL: URL { api.config.apiBaseURL }
    var webURL: URL { api.config.authBaseURL }

    var activePlantName: String? { plants.first { $0.id == activePlantId }?.name }

    private static func makeClient(_ config: AriaConfig) -> AriaAPIClient {
        AriaAPIClient(config: config, auth: AriaAuth(config: config), context: AriaContext())
    }

    // MARK: Login

    func startLogin(email: String) async throws {
        try await api.auth.startLogin(email: Self.normalized(email))
    }

    func verify(email: String, code: String) async throws {
        try await api.auth.verify(email: Self.normalized(email), code: code.trimmingCharacters(in: .whitespaces))
        isSignedIn = true
        await bootstrap()
    }

    /// Solo sviluppo: token copiato dalla web (GET /api/aria/token).
    func useDeveloperToken(_ token: String) async throws {
        try await api.auth.useDeveloperToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
        isSignedIn = true
        await bootstrap()
    }

    func signOut() async {
        await api.auth.signOut()
        await api.context.setCompany(nil)
        await api.context.setPlant(nil)
        isSignedIn = false
        didBootstrap = false
        companies = []
        plants = []
        activeCompanyId = nil
        activePlantId = nil
        lastError = nil
    }

    /// Cambia server (DEBUG). Da scollegati: i token di un server non valgono sull'altro.
    func setServers(api apiURL: URL?, web webURL: URL?) {
        guard !isSignedIn else { return }
        AriaConfig.saveServers(api: apiURL, web: webURL)
        api = Self.makeClient(.current)
    }

    // MARK: Azienda / stabilimento

    func bootstrapIfNeeded() async {
        guard isSignedIn, !didBootstrap, !isLoading else { return }
        await bootstrap()
    }

    /// Come la web: azienda salvata se l'utente ne fa ancora parte,
    /// altrimenti la prima di cui è owner, altrimenti la prima.
    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            companies = try await api.get("v1/companies")
            let pick = companies.first { $0.id == activeCompanyId }
                ?? companies.first { $0.myRole == "owner" }
                ?? companies.first
            try await loadPlants(for: pick?.id)
            didBootstrap = true
            lastError = nil
        } catch {
            handle(error)
        }
    }

    func selectCompany(_ id: String?) async {
        do { try await loadPlants(for: id) } catch { handle(error) }
    }

    func selectPlant(_ id: String?) async {
        await api.context.setPlant(id)
        activePlantId = id
    }

    private func loadPlants(for companyId: String?) async throws {
        await api.context.setCompany(companyId)
        activeCompanyId = companyId
        plants = companyId == nil ? [] : try await api.get("v1/plants")
        await selectPlant(plants.first { $0.id == activePlantId }?.id ?? plants.first?.id)
    }

    // MARK: Chat

    /// Suggerimenti iniziali della chat per lo stabilimento attivo (vuoto se non disponibili).
    func suggestions() async -> [String] {
        guard let plantId = activePlantId else { return [] }
        let response: AriaSuggestionsResponse? = try? await api.get("v1/chat/suggestions", query: [
            URLQueryItem(name: "plant_id", value: plantId),
            URLQueryItem(name: "locale", value: api.context.locale),
        ])
        return response?.suggestions ?? []
    }

    func handle(_ error: any Error) {
        if case .signedOut? = error as? AriaError {
            isSignedIn = false
            didBootstrap = false
        }
        lastError = error.localizedDescription
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
