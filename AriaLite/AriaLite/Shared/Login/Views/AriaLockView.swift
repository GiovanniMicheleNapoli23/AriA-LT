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
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone in orizzontale: sfera e logo più piccoli, così i pulsanti restano in vista.
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: isCompactHeight ? 16 : 40)
                    VStack(spacing: isCompactHeight ? 12 : 22) {
                        AriaOrb(mood: viewModel.isUnlocking ? .thinking : .idle, radius: 0.8)
                            .frame(width: isCompactHeight ? 64 : 104, height: isCompactHeight ? 64 : 104)
                            .shadow(color: Color.liteAccent.opacity(0.18), radius: 18, x: 0, y: 10)
                        AriaWordmark(size: isCompactHeight ? 28 : 40, stacked: true)
                    }
                    Spacer(minLength: isCompactHeight ? 16 : 40)
                    account
                    Spacer(minLength: 24)
                    actions
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 480)
                // Centrato come prima quando ci sta; se lo schermo è basso scorre.
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { LoginBackdrop() }
        .alert("Use a different account?", isPresented: $confirmSignOut) {
            Button("Logout", role: .destructive) { viewModel.logout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To sign in again you will need a new link from your email.")
        }
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
                        ProgressView().tint(Color.liteOnAccent)
                    } else {
                        Label(Self.unlockTitle, systemImage: Self.unlockIcon)
                            .font(.headline)
                    }
                }
                .foregroundStyle(Color.liteOnAccent)
                // 54pt a testo "Large"; coi testi grandi cresce quanto il titolo, non di più.
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
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
/// Una finestra per ogni scena (più finestre dell'app su iPad), condivise tra le ContentView:
/// la prima che chiude a chiave le copre tutte, le altre non ne aggiungono.
@MainActor
final class AriaLockWindow {
    private struct Lock {
        let window: UIWindow
        weak var previousKeyWindow: UIWindow?
    }

    private static var locks: [ObjectIdentifier: Lock] = [:]

    func show(_ viewModel: AppViewModel) {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { Self.locks[ObjectIdentifier($0)] == nil }
        guard !scenes.isEmpty else { return }
        // La tastiera starebbe sopra la finestra.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        for scene in scenes {
            let previousKeyWindow = scene.keyWindow
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.overrideUserInterfaceStyle = .light
            window.rootViewController = UIHostingController(rootView: AriaLockView(viewModel: viewModel))
            window.makeKeyAndVisible()
            Self.locks[ObjectIdentifier(scene)] = Lock(window: window, previousKeyWindow: previousKeyWindow)
        }
    }

    func hide() {
        let locks = Self.locks.values
        Self.locks = [:]
        for lock in locks {
            let window = lock.window
            lock.previousKeyWindow?.makeKey()
            UIView.animate(withDuration: 0.25) {
                window.alpha = 0
            } completion: { _ in
                window.isHidden = true
            }
        }
    }
}

#Preview {
    AriaLockView(viewModel: AppViewModel())
}
