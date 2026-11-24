//
//  SettingsSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//
//  Le impostazioni, in un foglio con la sua pila di navigazione: una lista a gruppi e ogni voce apre la sua pagina
//  con un push. In cima il profilo (pagina dell'account); poi Account (crediti, disponibilità degli operatori),
//  Workspace (azienda e sito, scelti da un menu sulla riga; server Aria), App (aspetto, anche lui da un menu),
//  Guides, l'uscita e la versione.
//

import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: AriaSettingsViewModel
    @AppStorage(AriaAppearance.storageKey) private var appearance: AriaAppearance = .system

    init(user: User, viewModel: AppViewModel) {
        _viewModel = State(initialValue: AriaSettingsViewModel(user: user, app: viewModel))
    }

    var body: some View {
        NavigationStack {
            list
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { closeButton }
                }
                .navigationDestination(for: AriaSettingsRoute.self) { destination($0) }
        }
        // Il saldo si rilegge ora e ogni 60 s finché le impostazioni sono aperte (anche su un'altra pagina),
        // e quando l'app torna in primo piano.
        .task { await viewModel.credits.poll() }
        .onChange(of: scenePhase) { _, phase in viewModel.credits.scenePhaseChanged(phase) }
        .fullScreenCover(isPresented: $viewModel.showsOnboarding) {
            AriaOnboardingView(origin: .profile) { viewModel.showsOnboarding = false }
        }
        .alert("Log out with unsynced changes?", isPresented: $viewModel.confirmingLogout) {
            Button("Log out anyway", role: .destructive) { viewModel.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(viewModel.unsyncedChanges) changes haven't reached the server yet. If you log out now, they will be lost.")
        }
    }

    private var list: some View {
        List {
            Section {
                NavigationLink(value: AriaSettingsRoute.account) {
                    AriaSettingsProfileRow(initials: viewModel.initials, name: viewModel.name, email: viewModel.email)
                }
            }
            accountSection
            workspaceSection
            Section {
                // Come azienda e sito: un menu sulla riga, sulla riga solo il nome (le icone stanno nel menu).
                // La scelta vale subito (AriaLiteApp la applica).
                AriaSettingsMenuRow(value: String(localized: appearance.title)) {
                    AriaSettingsLabel("Appearance", systemImage: "circle.lefthalf.filled")
                } choices: {
                    Picker(selection: $appearance) {
                        ForEach(AriaAppearance.allCases) { option in
                            Label { Text(option.title) } icon: { Image(systemName: option.systemImage) }
                                .tag(option)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.inline)
                }
                .sensoryFeedback(.selection, trigger: appearance)
                .accessibilityIdentifier("settings.appearance")
            } header: {
                Text("App")
            } footer: {
                Text("System matches your device's appearance.")
            }
            guidesSection
            logoutSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .ariaReadableWidth()
        .liteBackground()
    }

    // MARK: Account

    @ViewBuilder
    private var accountSection: some View {
        if viewModel.credits.isVisible || viewModel.showsAvailability {
            Section("Account") {
                if viewModel.credits.isVisible {
                    NavigationLink(value: AriaSettingsRoute.credits) {
                        AriaSettingsCreditsRow(model: viewModel.credits)
                    }
                }
                if viewModel.showsAvailability {
                    NavigationLink(value: AriaSettingsRoute.availability) {
                        LabeledContent {
                            HStack(spacing: 6) {
                                Circle().fill(viewModel.availability.color).frame(width: 8, height: 8)
                                Text(verbatim: viewModel.availability.localized)
                            }
                        } label: {
                            AriaSettingsLabel("Availability", systemImage: "person.crop.circle.badge.clock")
                        }
                    }
                }
            }
        }
    }

    // MARK: Area di lavoro

    private var workspaceSection: some View {
        Section {
            companyRow
            siteRow
            NavigationLink(value: AriaSettingsRoute.server) {
                LabeledContent {
                    Text(viewModel.isOnline ? "Online" : "Not connected")
                } label: {
                    AriaSettingsLabel("Aria server", systemImage: "bolt.horizontal.circle")
                }
            }
        } header: {
            Text("Workspace")
        } footer: {
            if !viewModel.plants.isEmpty {
                Text("Aria answers using the data of the selected site.")
            }
        }
    }

    /// Un menu con le aziende e la spunta su quella attiva; senza un elenco (in lettura) solo il nome.
    /// Il nome sta su una riga: se è troppo lungo si tronca.
    @ViewBuilder
    private var companyRow: some View {
        let label = AriaSettingsLabel("Company", systemImage: "building.2")
        if !viewModel.companies.isEmpty {
            AriaSettingsMenuRow(value: viewModel.companyName) {
                label
            } choices: {
                Picker(selection: $viewModel.companySelection) {
                    ForEach(viewModel.companies) { company in
                        Text(verbatim: company.name).tag(Optional(company.id))
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
            }
            .sensoryFeedback(.selection, trigger: viewModel.activeCompanyId)
            .accessibilityIdentifier("settings.company")
        } else if let company = viewModel.companyName {
            LabeledContent {
                Text(verbatim: company)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } label: {
                label
                    .layoutPriority(1)
            }
        }
    }

    /// Come l'azienda: un menu coi siti, o solo il nome finché l'elenco non c'è.
    @ViewBuilder
    private var siteRow: some View {
        let label = AriaSettingsLabel("Site", systemImage: "mappin.and.ellipse")
        if !viewModel.plants.isEmpty {
            AriaSettingsMenuRow(value: viewModel.plantName) {
                label
            } choices: {
                Picker(selection: $viewModel.plantSelection) {
                    ForEach(viewModel.plants) { plant in
                        Text(verbatim: plant.name).tag(Optional(plant.id))
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
            }
            .sensoryFeedback(.selection, trigger: viewModel.activePlantId)
            .accessibilityIdentifier("settings.site")
        } else if let plant = viewModel.plantName {
            LabeledContent {
                Text(verbatim: plant)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } label: {
                label
                    .layoutPriority(1)
            }
        }
    }

    // MARK: Guide

    private var guidesSection: some View {
        Section("Guides") {
            // "Primi passi con AriA" si rifà dalle sezioni: il foglio si chiude.
            if viewModel.showsSetupTour {
                Button {
                    viewModel.replaySetupTour()
                    dismiss()
                } label: {
                    AriaSettingsLabel("Get started with AriA", systemImage: "map")
                }
                .accessibilityIdentifier("settings.setupTour")
            }
            Button {
                viewModel.showsOnboarding = true
            } label: {
                AriaSettingsLabel("App tour", systemImage: "sparkles.rectangle.stack")
            }
            .accessibilityIdentifier("settings.tour")
        }
    }

    // MARK: Uscita

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.logoutTapped()
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(Color.liteDanger)
            }
        } footer: {
            Text(verbatim: viewModel.versionText)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }

    // MARK: Pagine

    @ViewBuilder
    private func destination(_ route: AriaSettingsRoute) -> some View {
        switch route {
        case .account: AriaSettingsAccountView(viewModel: viewModel)
        case .credits: AriaCreditsView(model: viewModel.credits)
        case .availability: AriaSettingsAvailabilityView(viewModel: viewModel)
        case .server: AriaConnectionForm(backend: viewModel.app.backend)
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) { dismiss() }
        } else {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .accessibilityLabel("Close")
        }
    }
}
