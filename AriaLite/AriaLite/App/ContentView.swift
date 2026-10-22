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

    var body: some View {
        Group {
            if let user = viewModel.loggedInUser {
                if viewModel.lock == .launch {
                    // La sessione è ancora nel Keychain: l'app si costruisce dopo Face ID.
                    AriaLockView(viewModel: viewModel)
                } else {
                    // Navigazione come Claude mobile: chat al centro, sezioni nella sidebar.
                    AriaShellView(user: user)
                }
            } else {
                LoginView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.lock == .launch)
        // Link di accesso toccato nell'email (Universal Link) o dal pulsante della pagina web (aria://).
        .onOpenURL { viewModel.open($0) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background: viewModel.lockForBackground()
            // Face ID si può chiedere solo con l'app in primo piano.
            case .active: Task { await viewModel.unlockAutomatically() }
            default: break
            }
        }
        // Al ritorno dal background l'app resta sotto com'era, coperta da una finestra.
        .onChange(of: viewModel.lock) { _, lock in
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
