//
//  AdminMobileUserSeatsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il riquadro in cima alla lista: quanti posti della licenza sono usati, con una barra. Arancione
//  quando restano pochi posti, rosso quando sono finiti.
//

import SwiftUI

struct AdminMobileUserSeatsCard: View {
    let seats: AdminMobileUserSeats
    let text: String

    private var tint: Color {
        if seats.isFull { return .red }
        return seats.total > 0 && seats.fraction >= 0.8 ? .orange : Color.liteAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Mobile seats", systemImage: "iphone.gen3")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(text)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: seats.fraction)
                .tint(tint)
            if seats.isFull {
                Text("No seats left. Remove an operator or ask your administrator for more seats.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
