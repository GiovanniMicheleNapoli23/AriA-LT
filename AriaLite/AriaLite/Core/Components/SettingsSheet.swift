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

            VStack(spacing: 24) {

                // MARK: – Avatar + info
                VStack(spacing: 10) {
                    ZStack {
                        Text(user.name.prefix(1))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.liteAccent)
                    }
                    .frame(width: 72, height: 72)
                    .glassEffect(.regular, in: Circle())

                    VStack(spacing: 3) {
                        Text(user.name)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Operatore")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: – Logout
                let logoutRed = Color(red: 0.82, green: 0.18, blue: 0.18)

                Button(role: .destructive) {
                    viewModel.logout()
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
            }
            .padding(.top, 32)
        }
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.visible)
    }
}
