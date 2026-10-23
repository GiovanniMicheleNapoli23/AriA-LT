//
//  SettingsSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//
import SwiftUI

struct SettingsSheet: View {
    let user: User
    let viewModel: AppViewModel
    @State private var showConnection = false
    @State private var confirmingLogout = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var avatarSide: CGFloat = 72

    var body: some View {
        ZStack {
            Color.liteBackground.ignoresSafeArea()
            RadialGradient(
                colors: [Color.liteAccent.opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: – Avatar + info
                        VStack(spacing: 10) {
                            ZStack {
                                Text(user.name.prefix(1))
                                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color.liteAccent)
                            }
                            .frame(width: avatarSide, height: avatarSide)
                            .ariaGlass(in: Circle())

                            VStack(spacing: 3) {
                                Text(user.name)
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Text("Operator")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // MARK: – Disponibilità
                        AriaAvailabilityRow(store: viewModel.ariaWorkOrders)
                            .padding(.horizontal, 20)

                        // MARK: – Server Aria (chat)
                        Button {
                            showConnection = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bolt.horizontal.circle")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.liteAccent)
                                Text("Aria server")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(viewModel.backend.isReady ? "Online" : "Not connected")
                                    .font(.subheadline)
                                    .foregroundStyle(viewModel.backend.isReady ? .green : .secondary)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        // MARK: – Logout
                        let logoutRed = Color(red: 0.82, green: 0.18, blue: 0.18)

                        Button(role: .destructive) {
                            // Lavoro fatto offline non ancora partito: uscendo si perde, quindi si chiede prima.
                            if viewModel.unsyncedChanges > 0 { confirmingLogout = true } else { viewModel.logout() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.body.weight(.medium))
                                Text("Logout")
                                    .font(.body.weight(.medium))
                            }
                            .foregroundStyle(logoutRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(logoutRed.opacity(0.55), lineWidth: 1.5)
                            )
                        }
                        .padding(.horizontal, 20)
                        .alert("Log out with unsynced changes?", isPresented: $confirmingLogout) {
                            Button("Log out anyway", role: .destructive) { viewModel.logout() }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("\(viewModel.unsyncedChanges) changes haven't reached the server yet. If you log out now, they will be lost.")
                        }
                    }
                    .padding(.top, 32)
                    // Centrato come prima quando ci sta; scorre su SE, in orizzontale e con testo grande.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(isPresented: $showConnection) {
            AriaConnectionSheet(backend: viewModel.backend)
        }
        // Con il testo molto grande il foglio si può anche allargare.
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.fraction(0.6), .large] : [.fraction(0.6)])
        .presentationDragIndicator(.visible)
    }
}
