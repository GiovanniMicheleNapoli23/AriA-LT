//
//  LoginView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//


import SwiftUI

struct LoginView: View {
    let viewModel: AppViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // Sfondo bianco pulito — coerente con il logo navy su bianco
            Color.liteBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: Logo Area
                VStack(spacing: 14) {
                    Image("AriaLite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .padding(4)
                        .background(Color.liteSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.liteAccent.opacity(0.35),
                                            Color.liteAccent.opacity(0.08),
                                            Color.liteAccent.opacity(0.20)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.liteAccent.opacity(0.12), radius: 24, x: 0, y: 8)



                    VStack(spacing: 4) {
                        Text("AriA LT")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.liteText)
                            .tracking(6)

                        Text("SINAURA")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.liteAccent.opacity(0.45))
                            .tracking(6)
                    }
                }
                .padding(.bottom, 52)

                // MARK: Form Card
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "person")
                            .foregroundStyle(Color.liteAccent.opacity(0.4))
                            .frame(width: 20)
                        TextField("", text: $username, prompt:
                            Text("Username")
                                .foregroundStyle(Color.liteText.opacity(0.30))
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Color.liteText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    Rectangle()
                        .fill(Color.liteBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundStyle(Color.liteAccent.opacity(0.4))
                            .frame(width: 20)
                        SecureField("", text: $password, prompt:
                            Text("Password")
                                .foregroundStyle(Color.liteText.opacity(0.30))
                        )
                        .foregroundStyle(Color.liteText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color.liteSurface)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.liteBorder, lineWidth: 1.5)
                )
                .shadow(color: Color.liteAccent.opacity(0.06), radius: 16, x: 0, y: 6)
                .padding(.horizontal, 28)

                // MARK: Error
                if showError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("Credenziali non valide")
                    }
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.85, green: 0.25, blue: 0.25))
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // MARK: CTA Button
                Button {
                    isLoading = true
                    showError = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let ok = viewModel.login(username: username, password: password)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showError = !ok
                            isLoading = false
                        }
                    }
                } label: {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Accedi")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .tracking(2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        // Navy solido quando attivo — rispecchia il logo
                        username.isEmpty || password.isEmpty
                            ? Color.liteAccent.opacity(0.15)
                            : Color.liteAccent
                    )
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                username.isEmpty || password.isEmpty
                                    ? Color.liteBorder
                                    : Color.liteAccent,
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: username.isEmpty || password.isEmpty
                            ? .clear
                            : Color.liteAccent.opacity(0.25),
                        radius: 10, x: 0, y: 5
                    )
                }
                .disabled(username.isEmpty || password.isEmpty || isLoading)
                .animation(.easeInOut(duration: 0.2), value: username.isEmpty || password.isEmpty)
                .padding(.horizontal, 28)
                .padding(.top, 20)

                Spacer()
                Spacer()

                // MARK: Footer
                Text("V 1.0")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(Color.liteAccent.opacity(0.25))
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.light)
    }
}


#Preview {
    LoginView(viewModel: AppViewModel())
}
