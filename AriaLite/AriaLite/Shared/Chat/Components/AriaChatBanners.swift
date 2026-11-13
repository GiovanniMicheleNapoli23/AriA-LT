//
//  AriaChatBanners.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli avvisi sopra il composer: conferma di un'azione, errore del turno, stabilimento mancante.
//

import SwiftUI

/// Conferma breve (es. "Salvato"): sparisce da sola dopo 3 secondi.
struct AriaChatNoticeBanner: View {
    let notice: String
    var onExpire: () -> Void

    var body: some View {
        Label(notice, systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.green)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule(), tint: Color.green.opacity(0.18))
            .task(id: notice) {
                try? await Task.sleep(for: .seconds(3))
                onExpire()
            }
    }
}

/// Errore del turno, con "Riprova" quando l'ultima domanda si può rimandare.
struct AriaChatErrorBanner: View {
    let error: String
    var onRetry: (() -> Void)?
    var onDismiss: () -> Void
    @ScaledMetric(relativeTo: .caption2) private var dismissSide: CGFloat = 26

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            // Fino a 4 righe: in italiano alcuni errori ne chiedono 3 sui telefoni da 375-402pt.
            Text(error)
                .font(.footnote)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: dismissSide, height: dismissSide)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), tint: Color.red.opacity(0.14))
    }
}

/// PlantGuardBanner della web: senza stabilimento il backend non risponde.
struct AriaPlantGuardBanner: View {
    let backend: AriaBackend
    let state: AriaPlantGuard
    /// Apre "Nuovo stabilimento" (`state == .create`).
    var onCreate: () -> Void

    var body: some View {
        HStack {
            Label(message, systemImage: "building.2")
                .font(.footnote.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            switch state {
            case .choose:
                Menu {
                    ForEach(backend.plants) { plant in
                        Button(plant.name) { Task { await backend.selectPlant(plant.id) } }
                    }
                } label: {
                    Text("Choose").font(.footnote.weight(.semibold))
                }
            case .create:
                Button("Add site", action: onCreate)
                    .font(.footnote.weight(.semibold))
            case .askAdmin:
                EmptyView()
            }
        }
        .padding(12)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), tint: Color.orange.opacity(0.14))
        .task { await backend.bootstrapIfNeeded() }
    }

    private var message: LocalizedStringKey {
        switch state {
        case .choose: "Select a site before chatting."
        case .create: "Add your first site to start chatting."
        case .askAdmin: "No sites yet. Ask an owner or admin of your company to add one."
        }
    }
}
