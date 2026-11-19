//
//  AriaSetupTourAnchor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Segna un controllo vero come bersaglio di un passo del giro guidato: ne riporta il frame globale al view
//  model del giro, che lo usa per ritagliare il velo. Segna anche i fogli: finché ne è aperto uno, il giro si fa
//  da parte. Senza giro nell'ambiente (anteprime, test) non fa niente.
//

import SwiftUI

extension EnvironmentValues {
    /// Il giro guidato: lo inietta la shell; le viste lo leggono per segnare i pulsanti.
    @Entry var ariaSetupTour: AriaSetupTourViewModel?
}

private struct AriaSetupTourAnchorModifier: ViewModifier {
    let step: AriaSetupTourStep?
    @Environment(\.ariaSetupTour) private var tour
    /// L'ultimo frame visto: se la vista torna (dopo un push) senza muoversi, si riporta lo stesso.
    @State private var frame: CGRect?

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newFrame in
                frame = newFrame
                if let step { tour?.setFrame(newFrame, for: step) }
            }
            .onAppear { if let step { tour?.setFrame(frame, for: step) } }
            .onDisappear { if let step { tour?.setFrame(nil, for: step) } }
    }
}

private struct AriaSetupTourAsideModifier: ViewModifier {
    let isPresented: Bool
    let source: String
    @Environment(\.ariaSetupTour) private var tour

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented, initial: true) { _, presented in
                tour?.setAside(presented, source: source)
            }
            // La sezione sparisce con il foglio ancora aperto: il giro non resta nascosto.
            .onDisappear { tour?.setAside(false, source: source) }
    }
}

extension View {
    /// Questo controllo è il bersaglio del passo: il giro guidato lo indica quando il passo è quello corrente.
    /// Con `nil` (una riga di un elenco che non è il bersaglio di nessun passo) non fa niente.
    func ariaSetupTourAnchor(_ step: AriaSetupTourStep?) -> some View {
        modifier(AriaSetupTourAnchorModifier(step: step))
    }

    /// Questa vista ha un foglio (o una schermata) aperto sopra la sezione: il giro guidato si fa da parte
    /// finché `isPresented` è vero. `source` distingue chi lo chiede.
    func ariaSetupTourAside(_ isPresented: Bool, source: String) -> some View {
        modifier(AriaSetupTourAsideModifier(isPresented: isPresented, source: source))
    }
}
