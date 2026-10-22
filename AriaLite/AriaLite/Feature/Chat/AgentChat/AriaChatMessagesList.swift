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

    /// Si scrive in un campo dentro un messaggio (ricordo, parametri da approvare).
    @State private var inlineEditorFocused = false

    private var chat: AriaAgentChat { model.chat }

    var body: some View {
        ScrollView {
            // VStack e non LazyVStack: con altezze stimate lo scroll in fondo saltella mentre il testo cresce.
            VStack(alignment: .leading, spacing: 16) {
                ForEach(chat.messages) { message in
                    AriaAgentMessageView(message: message, chat: chat, webBase: model.backend.webURL,
                                         isLast: message.id == chat.messages.last?.id,
                                         orbNamespace: orbNamespace)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                            model.messageHeightChanged(message.id, height: height)
                        }
                        .frame(minHeight: model.minHeight(for: message.id), alignment: .top)
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
            // La tastiera aperta da un campo nel messaggio non deve trascinare la lista in fondo, campo fuori schermo.
            if model.scroll.sticksToBottom(sizes), !inlineEditorFocused { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .onPreferenceChange(AriaInlineEditorFocusKey.self) { focused in
            Task { @MainActor in inlineEditorFocused = focused }
        }
        .onScrollPhaseChange { _, phase in
            model.scroll.phaseChanged(to: phase)
        }
        // Un messaggio nuovo (mandato o ricevuto) riporta sempre in fondo.
        .onChange(of: chat.messages.count) {
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

    var body: some View {
        Button(action: action) {
            Image(systemName: isStreaming ? "arrow.down.circle.dotted" : "arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .ariaGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scroll to the latest message")
    }
}
