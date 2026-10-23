//
//  AdminCraftedAriaComposer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La riga dove si scrive ad Aria cosa cambiare — o, con una proposta in pagina, come chiederla
//  diversamente — con Invia, che mentre lei lavora diventa Ferma. Senza stabilimento il campo dice perché
//  non si può.
//

import SwiftUI

struct AdminCraftedAriaComposer: View {
    let editor: AdminCraftedAriaEditor
    @Binding var instruction: String
    let hasProposal: Bool
    let actions: AdminCraftedAriaActions

    private var canSend: Bool {
        editor.blockedReason == nil && !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(text: $instruction, prompt: prompt, axis: .vertical) {
                Text("Instruction")
            }
            .lineLimit(1...5)
            .submitLabel(.send)
            .onSubmit { if canSend, !editor.isRunning { actions.send() } }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if editor.isRunning {
                Button(action: actions.stop) {
                    Image(systemName: "stop.circle.fill").font(.title)
                }
                .accessibilityLabel("Stop")
            } else {
                Button(action: actions.send) {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .ariaReadableWidth()
        .background(.bar)
    }

    private var prompt: Text {
        if let blocked = editor.blockedReason { return Text(verbatim: blocked) }
        return hasProposal ? Text("Ask for it differently — shorter, more formal…")
            : Text("Tell Aria what to change — e.g. make the conclusion shorter, translate the table headings…")
    }
}
