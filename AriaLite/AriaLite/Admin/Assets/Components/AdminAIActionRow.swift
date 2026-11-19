//
//  AdminAIActionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Una richiesta all'AI in un Form ("Improve with AI" di allarmi e piani) come vero pulsante, non come riga
//  di testo: una scheda di vetro a sé (staccata dalle altre, senza lo sfondo della sezione) con l'icona su
//  un riquadro pieno, il titolo che dice cosa cambia, il sottotitolo e la rotella mentre è in corso; al tocco
//  si schiarisce, disattivata si attenua. AdminAIActionLabel è la stessa scheda come etichetta di un Menu
//  (con l'indicatore su e giù): il Menu prende `.adminAIActionRow()` per staccarsi allo stesso modo.
//

import SwiftUI

struct AdminAIActionRow: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var isRunning = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AdminAIActionLabel(title: title, subtitle: subtitle, systemImage: systemImage, isRunning: isRunning)
        }
        .buttonStyle(AdminAIActionButtonStyle())
        .adminAIActionRow()
        .accessibilityHint(Text("Asks the assistant for a proposal"))
    }
}

/// La scheda di una richiesta all'AI: per un pulsante (AdminAIActionRow) o per un Menu (`isMenu`), dove
/// scegliere una voce fa partire la richiesta.
struct AdminAIActionLabel: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var isRunning = false
    var isMenu = false

    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var tileSide: CGFloat = 34

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.liteOnAccent)
                .frame(width: tileSide, height: tileSide)
                .background(Color.liteAccent, in: RoundedRectangle(cornerRadius: tileSide * 0.28, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isEnabled || isRunning ? 1 : 0.5)
    }

    @ViewBuilder
    private var trailing: some View {
        if isRunning {
            ProgressView()
        } else if isMenu {
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

/// Al tocco la scheda si schiarisce e rimpicciolisce appena, come un pulsante.
struct AdminAIActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Una richiesta all'AI come riga di un Form: senza lo sfondo né il separatore della sezione, così ogni
    /// scheda sta da sola.
    func adminAIActionRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            .listRowSeparator(.hidden)
    }
}

/// L'azione principale del foglio, in evidenza a tutta larghezza sopra le altre.
struct AdminAIPrimaryActionButton: View {
    let title: String
    let systemImage: String
    var isRunning = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isRunning {
                    ProgressView().tint(Color.liteOnAccent)
                } else {
                    Image(systemName: systemImage)
                }
                Text(verbatim: title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 34)
        }
        .ariaAccentGlassButtonStyle()
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .accessibilityHint(Text("Asks the assistant for a proposal"))
    }
}
