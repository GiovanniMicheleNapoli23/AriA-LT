//
//  AdminMemberSpecialtiesCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le specialità del membro come capsule, in una griglia adattiva (vanno a capo).
//

import SwiftUI

struct AdminMemberSpecialtiesCard: View {
    let specialties: [String]

    var body: some View {
        AdminCard(title: "Specialties", systemImage: "wrench.and.screwdriver") {
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
