//
//  SettingsSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//
//  Il profilo, a gruppi: chi è entrato e con che ruolo; crediti e disponibilità (solo operatori); l'area di
//  lavoro (azienda, impianto, server Aria); l'aspetto (chiaro, scuro, come il telefono); le guide ("Primi passi
//  con AriA" e la presentazione dell'app); l'uscita.
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
        ZStack {
            Color.liteBackground.ignoresSafeArea()
            RadialGradient(colors: [Color.liteAccent.opacity(0.06), .clear], center: .top, startRadius: 0, endRadius: 280)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 22) {
                        AriaSettingsProfileCard(initials: viewModel.initials, name: viewModel.name,
                                                email: viewModel.email, roleLabel: viewModel.roleLabel,
                                                roleSymbol: viewModel.roleSymbol, isAdmin: viewModel.isAdmin)
                        if viewModel.credits.isVisible { creditsCard }
                        if viewModel.showsAvailability {
                            AriaAvailabilityRow(store: viewModel.app.ariaWorkOrders)
                        }
                        workspaceSection
                        AriaSettingsSection(title: "Appearance") {
                            AriaAppearancePicker(selection: $appearance)
                        }
                        guidesSection
                        logoutButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .ariaReadableWidth()
                    // Centrato quando ci sta; scorre su SE, in orizzontale e con testo grande.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(isPresented: $viewModel.showsConnection) {
            AriaConnectionSheet(backend: viewModel.app.backend)
        }
        .sheet(isPresented: $viewModel.showsCredits) {
            AriaCreditsSheet(model: viewModel.credits)
        }
        // Il saldo si rilegge ora e ogni 60 s finché il profilo è aperto, e quando l'app torna in primo piano.
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
        // Un admin non ha la disponibilità: il foglio parte più basso. Si può sempre allargare.
        .presentationDetents([.fraction(viewModel.detentFraction), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Area di lavoro

    private var workspaceSection: some View {
        AriaSettingsSection(title: "Workspace") {
            if let company = viewModel.companyName {
                AriaSettingsRow(title: "Company", systemImage: "building.2") { valueText(company) }
            }
            if let plant = viewModel.plantName {
                AriaSettingsRow(title: "Site", systemImage: "gearshape.2") { valueText(plant) }
            }
            Button {
                viewModel.showsConnection = true
            } label: {
                AriaSettingsRow(title: "Aria server", systemImage: "bolt.horizontal.circle", showsChevron: true) {
                    Label(viewModel.isOnline ? "Online" : "Not connected", systemImage: "circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .imageScale(.small)
                        .foregroundStyle(viewModel.isOnline ? Color.liteSuccess : .secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Guide

    private var guidesSection: some View {
        AriaSettingsSection(title: "Guides") {
            // "Primi passi con AriA" si rifà dalle sezioni: il foglio si chiude.
            if viewModel.showsSetupTour {
                Button {
                    viewModel.replaySetupTour()
                    dismiss()
                } label: {
                    AriaSettingsRow(title: "Get started with AriA", systemImage: "map", showsChevron: true) { EmptyView() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.setupTour")
            }
            Button {
                viewModel.showsOnboarding = true
            } label: {
                AriaSettingsRow(title: "App tour", systemImage: "sparkles.rectangle.stack", showsChevron: true) {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.tour")
        }
    }

    // MARK: Crediti

    private var creditsCard: some View {
        Button {
            viewModel.creditsTapped()
        } label: {
            AriaCreditsCard(model: viewModel.credits)
                .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func valueText(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    // MARK: Uscita

    private var logoutButton: some View {
        Button(role: .destructive) {
            viewModel.logoutTapped()
        } label: {
            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.liteDanger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.liteDanger.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}
