//
//  AdminKnowledgeGraphKindIcon.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'icona di un tipo di entità nel suo colore, su un quadratino tenue. Cresce con il testo.
//

import SwiftUI

struct AdminKnowledgeGraphKindIcon: View {
    let kind: AdminKnowledgeGraphKind
    @ScaledMetric private var size: CGFloat

    init(kind: AdminKnowledgeGraphKind, size: CGFloat = 36) {
        self.kind = kind
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(kind.tint)
            .frame(width: size, height: size)
            .background(kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension AdminKnowledgeGraphKind {
    /// Un colore per tipo: nelle liste miste (ricerca, relazioni) si riconosce il tipo a colpo d'occhio.
    var tint: Color {
        switch self {
        case .asset: .indigo
        case .alarm: .orange
        case .maintenancePlan: .teal
        case .sparePart: .brown
        case .workOrder: .blue
        case .document: .purple
        case .plant: .green
        }
    }
}
