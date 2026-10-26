//
//  SettingsSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//
//  Il profilo: chi è entrato e con che ruolo, azienda e impianto, disponibilità (solo operatori),
//  server Aria e uscita.
//

import SwiftUI

struct SettingsSheet: View {
    @State private var viewModel: AriaSettingsViewModel
    @ScaledMetric(relativeTo: .largeTitle) private var avatarSide: CGFloat = 76

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
                    VStack(spacing: 20) {
                        header
                        if viewModel.showsWorkspace { workspaceCard }
                        if viewModel.showsAvailability {
                            AriaAvailabilityRow(store: viewModel.app.ariaWorkOrders)
                        }
                        serverCard
                        logoutButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
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
        .alert("Log out with unsynced changes?", isPresented: $viewModel.confirmingLogout) {
            Button("Log out anyway", role: .destructive) { viewModel.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(viewModel.unsyncedChanges) changes haven't reached the server yet. If you log out now, they will be lost.")
        }
        // Un admin non ha la disponibilità: il foglio parte più basso. Si può sempre allargare.
        .presentationDetents([.fraction(viewModel.showsAvailability ? 0.65 : 0.6), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Chi

    private var header: some View {
        VStack(spacing: 12) {
            Text(verbatim: viewModel.initials)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(width: avatarSide, height: avatarSide)
                .ariaGlass(in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(verbatim: viewModel.name)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)
                if let email = viewModel.email {
                    Text(verbatim: email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Label(viewModel.roleLabel, systemImage: viewModel.roleSymbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(viewModel.isAdmin ? Color.liteOnAccent : Color.liteAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(viewModel.isAdmin ? Color.liteAccent : Color.liteAccent.opacity(0.1), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Dove

    private var workspaceCard: some View {
        VStack(spacing: 0) {
            if let company = viewModel.companyName {
                AriaSettingsRow(title: "Company", systemImage: "building.2") {
                    valueText(company)
                }
            }
            if viewModel.companyName != nil, viewModel.plantName != nil {
                Divider().padding(.leading, 54)
            }
            if let plant = viewModel.plantName {
                AriaSettingsRow(title: "Plant", systemImage: "gearshape.2") {
                    valueText(plant)
                }
            }
        }
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func valueText(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    // MARK: Server

    private var serverCard: some View {
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
            .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
