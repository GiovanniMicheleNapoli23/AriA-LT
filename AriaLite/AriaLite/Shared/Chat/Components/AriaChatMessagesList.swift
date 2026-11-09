//
//  AriaChatMessagesList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La lista dei messaggi che segue l'ultimo turno, e il pulsante per tornare in fondo.
//

import SwiftUI

struct AriaChatMessagesList: View {
    let model: AriaAgentChatViewModel
    let orbNamespace: Namespace.ID?
    let proxy: ScrollViewProxy

    var body: some View {
        ScrollView {
            // VStack e non LazyVStack: con altezze stimate lo scroll in fondo saltella mentre il testo cresce.
            VStack(alignment: .leading, spacing: 16) {
                // Una volta per body, non una scansione dei messaggi per riga.
                let lastID = model.lastMessageID
                let reply = model.replyMinHeight
                ForEach(model.messages) { message in
                    AriaAgentMessageView(message: message, chat: model.chat, webBase: model.webURL,
                                         isLast: message.id == lastID,
                                         orbNamespace: orbNamespace)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                            model.messageHeightChanged(message.id, height: height)
                        }
                        .frame(minHeight: message.id == reply?.id ? reply?.height : nil, alignment: .top)
                        .id(message.id)
                }
                Color.clear.frame(height: 1).id("bottom")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            // iPad: colonna leggibile al centro; la scroll view resta larga quanto lo schermo.
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(.bottom)
        // Il riquadro della lista è già senza barra in alto e pannello in basso. onGeometryChange dà anche il valore iniziale.
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            model.visibleHeight = height
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.visibleRect.maxY >= geometry.contentSize.height - 80
        } action: { _, near in
            model.scroll.isNearBottom = near
        }
        // Testo in streaming, card, tastiera, pannello in basso: qualunque cambio di altezza, se si segue si resta in fondo.
        .onScrollGeometryChange(for: AriaChatScrollFollow.Sizes.self) { geometry in
            AriaChatScrollFollow.Sizes(content: geometry.contentSize.height, container: geometry.containerSize.height)
        } action: { _, sizes in
            if model.scroll.sticksToBottom(sizes) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .onPreferenceChange(AriaInlineEditorFocusKey.self) { focused in
            Task { @MainActor in model.scroll.isEditingInline = focused }
        }
        .onScrollPhaseChange { _, phase in
            model.scroll.phaseChanged(to: phase)
        }
        // Un messaggio nuovo (mandato o ricevuto) riporta sempre in fondo.
        .onChange(of: model.messageCount) {
            model.scroll.followBottom()
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

/// Un campo dentro un messaggio ha il fuoco: la lista smette di seguire il fondo finché lo tiene.
struct AriaInlineEditorFocusKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// Compare quando l'operatore sta rileggendo più in alto; durante lo streaming lo dice l'icona.
struct AriaChatJumpToBottomButton: View {
    let isStreaming: Bool
    var action: () -> Void
    // Il cerchio cresce con l'icona: a testo grande non la taglia.
    @ScaledMetric(relativeTo: .subheadline) private var side: CGFloat = 40

    var body: some View {
        Button(action: action) {
            Image(systemName: isStreaming ? "arrow.down.circle.dotted" : "arrow.down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: side, height: side)
                .ariaGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scroll to the latest message")
    }
}
