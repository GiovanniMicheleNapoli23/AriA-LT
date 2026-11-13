//
//  AdminMemberSpecialtiesCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le specialità del membro come capsule, in una griglia adattiva (vanno a capo). Con `onEdit` c'è la matita che
//  apre il foglio di nome, qualifica e specialità.
//

import SwiftUI

struct AdminMemberSpecialtiesCard: View {
    let specialties: [String]
    /// `nil`: chi guarda non può modificarle (o "Lavoro sul campo" è spento).
    var onEdit: (() -> Void)?

    var body: some View {
        AdminCard(title: "Specialties", systemImage: "wrench.and.screwdriver") {
            if let onEdit {
                Button("Edit", systemImage: "pencil", action: onEdit)
                    .labelStyle(.iconOnly)
                    .tint(Color.liteAccent)
            }
        } content: {
            if specialties.isEmpty {
                AdminSectionNotice(text: String(localized: "No specialties set."), systemImage: "star")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                          alignment: .leading, spacing: 8) {
                    ForEach(specialties, id: \.self) { specialty in
                        AdminMemberBadge(text: specialty)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
