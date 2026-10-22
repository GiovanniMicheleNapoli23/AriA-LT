//
//  AdminPlantRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga dell'elenco: nome, codice, ubicazione, descrizione su due righe e il badge "Current".
//

import SwiftUI

struct AdminPlantRow: View {
    let plant: AdminPlant
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: plant.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if isActive { AdminPlantActiveBadge() }
            }
            HStack(spacing: 8) {
                AdminPlantCodeBadge(code: plant.code)
                if let location = plant.location {
                    Label {
                        Text(verbatim: location)
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            if let description = plant.description {
                Text(verbatim: description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
