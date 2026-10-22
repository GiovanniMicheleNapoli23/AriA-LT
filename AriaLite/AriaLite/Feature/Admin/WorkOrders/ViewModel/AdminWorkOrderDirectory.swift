//
//  AdminWorkOrderDirectory.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Persone, squadre e asset dell'azienda, scaricati una volta e condivisi fra lista, dettaglio e form:
//  danno un nome agli id di assegnazione e le scelte del form. Ogni elenco è facoltativo: se il ruolo
//  non lo può leggere (403) o la rete manca, resta vuoto e il form mostra solo quello che ha.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderDirectory {
    private let backend: AriaBackend

    private(set) var users: [AdminWorkOrderUser] = [] {
        didSet { usersById = Dictionary(users.map { ($0.id, $0) }) { first, _ in first } }
    }
    private(set) var teams: [AdminWorkOrderTeam] = [] {
        didSet { teamsById = Dictionary(teams.map { ($0.id, $0) }) { first, _ in first } }
    }
    private(set) var assets: [AdminWorkOrderAsset] = [] {
        didSet { assetsByTag = Dictionary(assets.map { ($0.tag, $0) }) { first, _ in first } }
    }
    /// Per dare un nome agli id di ogni riga della lista senza scorrere gli elenchi.
    private var usersById: [String: AdminWorkOrderUser] = [:]
    private var teamsById: [String: AdminWorkOrderTeam] = [:]
    private var assetsByTag: [String: AdminWorkOrderAsset] = [:]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// Elenchi che il ruolo non può leggere: il form lo dice invece di mostrare una scelta vuota.
    private(set) var unavailable: Set<Kind> = []

    enum Kind: Hashable { case users, teams, assets }

    init(backend: AriaBackend) {
        self.backend = backend
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    func reset() {
        users = []
        teams = []
        assets = []
        hasLoaded = false
        unavailable = []
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await load()
    }

    /// I tre elenchi in parallelo; uno che fallisce non ferma gli altri.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        let api = api
        async let users = Self.fetch { try await api.users() }
        async let teams = Self.fetch { try await api.teams(plantId: nil) }
        async let assets = Self.fetch { try await api.assets() }
        let (userResult, teamResult, assetResult) = await (users, teams, assets)
        apply(userResult, to: \.users, kind: .users)
        apply(teamResult, to: \.teams, kind: .teams)
        apply(assetResult, to: \.assets, kind: .assets)
        hasLoaded = true
    }

    private nonisolated static func fetch<T: Sendable>(_ call: @Sendable () async throws -> [T]) async -> Result<[T], any Error> {
        do { return .success(try await call()) } catch { return .failure(error) }
    }

    private func apply<T>(_ result: Result<[T], any Error>, to keyPath: ReferenceWritableKeyPath<AdminWorkOrderDirectory, [T]>, kind: Kind) {
        switch result {
        case .success(let items):
            self[keyPath: keyPath] = items
            unavailable.remove(kind)
        case .failure(let error):
            if case .signedOut? = error as? AriaError { backend.handle(error) }
            if AdminWorkOrderFailure.isForbidden(error) { unavailable.insert(kind) }
        }
    }

    // MARK: Nomi

    func user(_ id: String?) -> AdminWorkOrderUser? {
        guard let id else { return nil }
        return usersById[id]
    }

    func team(_ id: String?) -> AdminWorkOrderTeam? {
        guard let id else { return nil }
        return teamsById[id]
    }

    func asset(_ tag: String?) -> AdminWorkOrderAsset? {
        guard let tag else { return nil }
        return assetsByTag[tag]
    }

    func plantName(_ id: String?) -> String? {
        guard let id else { return nil }
        return backend.plants.first { $0.id == id }?.name
    }

    /// Chi esegue l'ordine: la persona assegnata, poi il nome libero, poi la squadra.
    func assigneeName(for order: AdminWorkOrder) -> String? {
        user(order.assignedToUserId)?.displayName ?? order.assignedTo ?? team(order.assignedToTeamId)?.name
    }

    // MARK: Scelte del form

    /// Squadre dello stabilimento (e quelle senza stabilimento).
    func teams(in plantId: String?) -> [AdminWorkOrderTeam] {
        teams.filter { $0.plantId == nil || plantId == nil || $0.plantId == plantId }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Asset dello stabilimento (e quelli senza stabilimento).
    func assets(in plantId: String?) -> [AdminWorkOrderAsset] {
        assets.filter { $0.plantId == nil || plantId == nil || $0.plantId == plantId }
            .sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
    }

    var activeUsers: [AdminWorkOrderUser] {
        users.filter(\.isActive).sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
