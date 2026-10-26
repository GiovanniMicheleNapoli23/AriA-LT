//
//  AdminCraftedAriaComposer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La riga dove si scrive ad Aria cosa cambiare — o, con una proposta in pagina, come chiederla
//  diversamente — con Invia, che mentre lei lavora diventa Ferma. Senza stabilimento il campo dice perché
//  non si può. Stesso vetro e stesso cerchio della barra della chat.
//

import SwiftUI

struct AdminCraftedAriaComposer: View {
    let editor: AdminCraftedAriaEditor
    @Binding var instruction: String
    let hasProposal: Bool
    let actions: AdminCraftedAriaActions

    /// Come i cerchi della barra della chat.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 38

    private var canSend: Bool {
        editor.blockedReason == nil && !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            TextField(text: $instruction, prompt: prompt, axis: .vertical) {
                Text("Instruction")
            }
            .font(.body)
            .lineLimit(1...5)
            .submitLabel(.send)
            .onSubmit { if canSend, !editor.isRunning { actions.send() } }
            .padding(.leading, 10)
            .padding(.vertical, 6)
            // Alto quanto il cerchio: a riga singola testo e pulsante hanno lo stesso centro.
            .frame(minHeight: side)
            primaryButton
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .padding(6)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: true)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .ariaReadableWidth()
    }

    private var primaryButton: some View {
        Button(action: editor.isRunning ? actions.stop : actions.send) {
            ZStack {
                Circle().fill(tint).frame(width: side, height: side)
                Image(systemName: editor.isRunning ? "stop.fill" : "arrow.up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(onTint)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .disabled(!editor.isRunning && !canSend)
        .animation(.snappy(duration: 0.2), value: canSend)
        .animation(.snappy(duration: 0.2), value: editor.isRunning)
        .accessibilityLabel(editor.isRunning ? Text("Stop") : Text("Send"))
    }

    private var tint: Color {
        if editor.isRunning { return .red }
        return canSend ? .liteAccent : Color.secondary.opacity(0.35)
    }

    /// L'icona sopra il cerchio: nera sull'accento chiaro della modalità scura.
    private var onTint: Color {
        !editor.isRunning && canSend ? .liteOnAccent : .white
    }

    private var prompt: Text {
        if let blocked = editor.blockedReason { return Text(verbatim: blocked) }
        return hasProposal ? Text("Ask for a different version") : Text("Tell Aria what to change")
    }
}
