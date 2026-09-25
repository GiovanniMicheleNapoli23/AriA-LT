//
//  LoginView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//
//  Accesso in stile iOS: la sfera di Aria su un alone morbido (pensa mentre verifica
//  le credenziali), il logo con "Mobile" sotto, una card a gruppo unico come nelle
//  Impostazioni di sistema, un pulsante. Entra con una breve animazione.
//  Tocca fuori per chiudere la tastiera.
//

import SwiftUI

struct LoginView: View {
    let viewModel: AppViewModel

    private enum Field { case username, password }

    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showError = false
    @State private var isLoading = false
    @State private var shakes = 0
    /// Entrata in tre tempi: la sfera sale dal basso, poi il logo, poi il modulo.
    @State private var orbIn = false
    @State private var titleIn = false
    @State private var formIn = false
    @FocusState private var focus: Field?

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            hero
            Spacer(minLength: 40)
            form
                .opacity(formIn ? 1 : 0)
                .offset(y: formIn ? 0 : 40)
            Spacer(minLength: 24)
            footer
                .opacity(formIn ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .background { backdrop }
        .contentShape(Rectangle())
        .onTapGesture { focus = nil }
        .sensoryFeedback(.error, trigger: shakes)
        .preferredColorScheme(.light)
        .onAppear(perform: enter)
    }

    private func enter() {
        withAnimation(.spring(duration: 1.0, bounce: 0.28)) { orbIn = true }
        withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.55)) { titleIn = true }
        withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.85)) { formIn = true }
    }

    // MARK: - Sfondo

    /// Bianco quasi puro con due aloni appena percettibili: lilla dietro la sfera, navy in basso.
    private var backdrop: some View {
        ZStack {
            Color.liteBackground
            RadialGradient(colors: [Color(red: 0.62, green: 0.52, blue: 0.78).opacity(0.16), .clear],
                           center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Color.liteAccent.opacity(0.06), .clear],
                           center: .bottom, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }

    // MARK: - Sfera + logo

    private var hero: some View {
        VStack(spacing: 22) {
            AriaOrb(mood: isLoading ? .thinking : .idle, radius: 0.8)
                .frame(width: 104, height: 104)
                .shadow(color: Color.liteAccent.opacity(0.18), radius: 18, x: 0, y: 10)
                // Sale dal fondo dello schermo e si assesta al suo posto.
                .scaleEffect(orbIn ? 1 : 0.55)
                .offset(y: orbIn ? 0 : 520)
                .opacity(orbIn ? 1 : 0)

            AriaWordmark(size: 40, stacked: true)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 16)
                .blur(radius: titleIn ? 0 : 6)
        }
    }

    // MARK: - Campi

    /// Una sola card come nelle Impostazioni di sistema: righe unite da un filo, non pannelli separati.
    private var form: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                row(icon: "person") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .username)
                        .onSubmit { focus = .password }
                }

                Divider()
                    .padding(.leading, 50)

                row(icon: "lock") {
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focus, equals: .password)
                    .onSubmit(signIn)

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPassword ? Text("Hide password") : Text("Show password"))
                }
            }
            .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.liteBorder, lineWidth: 1)
            }
            .shadow(color: Color.liteAccent.opacity(0.06), radius: 20, x: 0, y: 8)
            .modifier(Shake(amount: CGFloat(shakes)))

            if showError {
                Label("Invalid credentials", systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: signIn) {
                ZStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign in")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.liteAccent.opacity(canSubmit || isLoading ? 1 : 0.3),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.liteAccent.opacity(canSubmit ? 0.25 : 0), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .animation(.easeInOut(duration: 0.2), value: canSubmit)
        }
        .animation(.snappy(duration: 0.25), value: showError)
    }

    private func row<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            content()
                .font(.system(size: 17))
                .foregroundStyle(Color.liteText)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    // MARK: - Piè di pagina

    private var footer: some View {
        HStack(spacing: 8) {
            Image("AriaLite")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(verbatim: "Sinaura · v\(version)")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Accesso

    private func signIn() {
        guard canSubmit else { return }
        focus = nil
        isLoading = true
        showError = false
        // FAKE: login locale sui dati mock; il breve attesa lascia vedere la sfera che "pensa".
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let ok = viewModel.login(username: username.trimmingCharacters(in: .whitespaces), password: password)
            isLoading = false
            if !ok {
                showError = true
                withAnimation(.linear(duration: 0.4)) { shakes += 1 }
                focus = .password
            }
        }
    }
}

/// Scuote orizzontalmente la card quando le credenziali sono sbagliate.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}

#Preview {
    LoginView(viewModel: AppViewModel())
}
