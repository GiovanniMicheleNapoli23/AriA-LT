//
//  AdminMarketplaceCapsule.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un chip di testo (connettore richiesto, standard, conteggio, badge). Si dispone dentro AdminMarketplaceSectionFlow.
//

import SwiftUI

struct AdminMarketplaceCapsule: View {
    private let text: Text
    var systemImage: String?

    /// Testo del catalogo o già localizzato: passa così com'è.
    init(verbatim text: String, systemImage: String? = nil) {
        self.text = Text(verbatim: text)
        self.systemImage = systemImage
    }

    /// Etichetta dell'interfaccia, localizzata dal catalogo delle stringhe.
    init(_ key: LocalizedStringKey, systemImage: String? = nil) {
        self.text = Text(key)
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).accessibilityHidden(true)
            }
            text.multilineTextAlignment(.leading)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.primary.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.liteAccent.opacity(0.08), in: Capsule())
    }
}
