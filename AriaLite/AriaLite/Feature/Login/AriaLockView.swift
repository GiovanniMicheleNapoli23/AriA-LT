//
//  AriaLockView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 08/10/26.
//
//  L'app chiusa a chiave: con una sessione Aria salvata, a ogni apertura serve Face ID
//  (o il codice del telefono) per rientrare, senza un nuovo link via email.
//  Stesso aspetto del login: la sfera, il logo, chi è collegato e un pulsante.
//  Il prompt di Face ID parte da solo (AppViewModel.unlockAutomatically); dopo un annullamento
//  resta il pulsante. "Usa un altro account" esce e torna al login.
//

import LocalAuthentication
import SwiftUI
import UIKit

struct AriaLockView: View {
    let viewModel: AppViewModel

    @State private var confirmSignOut = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            VStack(spacing: 22) {
                AriaOrb(mood: viewModel.isUnlocking ? .thinking : .idle, radius: 0.8)
                    .frame(width: 104, height: 104)
                    .shadow(color: Color.liteAccent.opacity(0.18), radius: 18, x: 0, y: 10)
                AriaWordmark(size: 40, stacked: true)
            }
            Spacer(minLength: 40)
            account
            Spacer(minLength: 24)
            actions
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .background { backdrop }
        .preferredColorScheme(.light)
        .confirmationDialog("Use a different account?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Logout", role: .destructive) { viewModel.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To sign in again you will need a new link from your email.")
        }
    }

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

    @ViewBuilder
    private var account: some View {
        if let user = viewModel.loggedInUser {
            VStack(spacing: 4) {
                Text(verbatim: user.name)
                    .font(.headline)
                    .foregroundStyle(Color.liteText)
                if user.username != user.name {
                    Text(verbatim: user.username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
        }
    }

    private var actions: some View {
        VStack(spacing: 16) {
            if let error = viewModel.unlockError {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                Task { await viewModel.unlock() }
            } label: {
                ZStack {
                    if viewModel.isUnlocking {
                        ProgressView().tint(.white)
                    } else {
                        Label(Self.unlockTitle, systemImage: Self.unlockIcon)
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.liteAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.liteAccent.opacity(0.25), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isUnlocking)

            Button("Use a different account") { confirmSignOut = true }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.liteAccent)
                .disabled(viewModel.isUnlocking)
        }
        .padding(.bottom, 24)
        .animation(.snappy(duration: 0.25), value: viewModel.unlockError)
    }

    private static var unlockTitle: LocalizedStringKey {
        switch AriaBiometrics.biometryType {
        case .faceID: "Unlock with Face ID"
        case .touchID: "Unlock with Touch ID"
        case .opticID: "Unlock with Optic ID"
        default: "Unlock"
        }
    }

    private static var unlockIcon: String {
        switch AriaBiometrics.biometryType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock.fill"
        }
    }
}

/// La schermata di sblocco al ritorno dal background, in una finestra sopra tutte le altre:
/// copre anche fogli e avvisi aperti, che una vista sovrapposta lascerebbe scoperti.
@MainActor
final class AriaLockWindow {
    private var window: UIWindow?
    private weak var previousKeyWindow: UIWindow?

    func show(_ viewModel: AppViewModel) {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        // La tastiera starebbe sopra la finestra.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        previousKeyWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = UIHostingController(rootView: AriaLockView(viewModel: viewModel))
        window.makeKeyAndVisible()
        self.window = window
    }

    func hide() {
        guard let window else { return }
        self.window = nil
        previousKeyWindow?.makeKey()
        UIView.animate(withDuration: 0.25) {
            window.alpha = 0
        } completion: { _ in
            window.isHidden = true
        }
    }
}

#Preview {
    AriaLockView(viewModel: AppViewModel())
}
