//
//  AriaAvailabilityRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 08/10/26.
//
//  Disponibilità dell'operatore, nella sezione profilo (impostazioni): decide se l'assegnazione
//  automatica gli manda ordini nuovi. Mostra lo stato e cosa comporta; un tocco apre le tre scelte.
//

import SwiftUI

extension AriaAvailability {
    var color: Color {
        switch self {
        case .available: .green
        case .busy: .orange
        case .offDuty: .gray
        }
    }
}

struct AriaAvailabilityRow: View {
    let store: AriaWorkOrderStore

    /// `available` dura 12 ore dall'ultimo invio.
    private var expiry: Date? {
        guard store.availability == .available, let at = store.profile?.availabilityAt else { return nil }
        return at.addingTimeInterval(12 * 3600)
    }

    private var caption: String {
        switch store.availability {
        case .available:
            if let expiry { String(localized: "Receiving new tasks until \(expiry.formatted(date: .omitted, time: .shortened))") }
            else { String(localized: "Receiving new tasks") }
        case .busy: String(localized: "No new tasks while you are busy")
        case .offDuty: String(localized: "No new tasks while you are off duty")
        }
    }

    var body: some View {
        Menu {
            Picker("Availability", selection: Binding(
                get: { store.availability },
                set: { newValue in Task { await store.setAvailability(newValue) } }
            )) {
                ForEach(AriaAvailability.allCases, id: \.self) { value in
                    Label(value.localized, systemImage: value.systemImage).tag(value)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // Su una riga se titolo e stato ci stanno interi; altrimenti (testo grande, schermo stretto) lo stato va sotto.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        icon
                        title.fixedSize()
                        Spacer(minLength: 8)
                        status.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            icon
                            title
                        }
                        status
                    }
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(store.isUpdatingAvailability)
        .sensoryFeedback(.selection, trigger: store.availability)
    }

    private var icon: some View {
        Image(systemName: "person.crop.circle.badge.clock")
            .font(.body.weight(.medium))
            .foregroundStyle(Color.liteAccent)
    }

    private var title: some View {
        Text("Availability")
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
    }

    private var status: some View {
        HStack(spacing: 6) {
            if store.isUpdatingAvailability {
                ProgressView()
            } else {
                Circle().fill(store.availability.color).frame(width: 8, height: 8)
                Text(store.availability.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}
