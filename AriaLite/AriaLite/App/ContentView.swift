//
//  ContentView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import SwiftUI


struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var lockWindow = AriaLockWindow()
    @State private var privacyWindow = AriaPrivacyWindow()

    var body: some View {
        Group {
            if let user = viewModel.loggedInUser {
                if viewModel.lock == .launch {
                    // La sessione è ancora nel Keychain: l'app si costruisce dopo Face ID.
                    AriaLockView(viewModel: viewModel)
                } else if viewModel.backend.isSigningUp {
                    // Appena iscritto: Profilo, Azienda, Stabilimento e Piano prima dell'app.
                    AriaSignUpView(app: viewModel)
                        .transition(.opacity)
                } else {
                    // Navigazione come Claude mobile: chat al centro, sezioni nella sidebar.
                    AriaShellView(user: user)
                }
            } else if viewModel.showsOnboarding {
                // Primo avvio: cosa si può fare con l'app, poi il login.
                AriaOnboardingView(origin: .firstLaunch) {
                    withAnimation(.smooth) { viewModel.finishOnboarding() }
                }
                .transition(.opacity)
            } else {
                LoginView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        // Link di accesso toccato nell'email (Universal Link) o dal pulsante della pagina web (aria://).
        .onOpenURL { viewModel.open($0) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            AriaAuthTrace.step("scene.phase", "\(phase)")
            // Il selettore delle app mostra (e salva) l'app già da `.inactive`: da lì in poi è coperta.
            // Non durante il nostro Face ID: copre già la schermata di blocco, e il sistema torna `.active`
            // secondi dopo l'esito, quando ha chiuso il suo foglio.
            if phase == .active || viewModel.loggedInUser == nil || viewModel.isUnlocking {
                privacyWindow.hide()
            } else {
                privacyWindow.show()
            }
            switch phase {
            case .background: viewModel.lockForBackground()
            // Face ID si può chiedere solo con l'app in primo piano; con l'app aperta non c'è nulla da chiedere
            // (Control Center, fogli di sistema e Face ID stesso fanno tornare `.active` più volte).
            case .active where viewModel.lock != .none:
                // Una finestra che torna attiva con l'app ancora chiusa è coperta prima di chiedere Face ID.
                if viewModel.lock == .resume { lockWindow.show(viewModel) }
                Task { await viewModel.unlockAutomatically() }
            default: break
            }
        }
        // Al ritorno dal background l'app resta sotto com'era, coperta da una finestra.
        // `initial`: una finestra aperta mentre l'app è chiusa (iPad, più finestre) nasce già coperta.
        .onChange(of: viewModel.lock, initial: true) { _, lock in
            if lock == .resume { lockWindow.show(viewModel) } else { lockWindow.hide() }
        }
        // Account Aria disattivato o sessione scaduta: si torna al login.
        .onChange(of: viewModel.backend.isSignedIn) { _, signedIn in
            if !signedIn { viewModel.ariaSessionEnded() }
        }
    }
}


#Preview {
    ContentView()
        .environment(AppViewModel())
}
