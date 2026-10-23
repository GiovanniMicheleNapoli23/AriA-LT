//
//  AdminCraftedAriaPanel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il pannello di Aria (AriaEditCard della web): su cosa lavora, cosa si sono detti, a che punto è, la
//  proposta con Accetta e Scarta, e in fondo la riga per dare l'istruzione — o un seguito, nella stessa
//  conversazione. Si scorre in verticale; la riga dell'istruzione resta fissa sotto.
//

import SwiftUI

struct AdminCraftedAriaPanel: View {
    let editor: AdminCraftedAriaEditor
    @Binding var panel: AdminCraftedAriaPanelState
    let proposal: AdminCraftedAriaProposalSummary?
    let actions: AdminCraftedAriaActions

    /// Si sceglie su cosa lavora Aria solo prima della prima richiesta: i seguiti restano su quello.
    private var canPickScope: Bool { editor.sessionId == nil && !editor.isRunning }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                scope
                if editor.thread.isEmpty, !editor.isRunning {
                    AdminCraftedAriaSuggestions { panel.instruction = $0 }
                }
                AdminCraftedAriaThread(lines: editor.thread)
                if editor.isRunning { working }
                if let proposal, !editor.isRunning {
                    AdminCraftedAriaProposalCard(summary: proposal, actions: actions)
                }
            }
            .padding(16)
            .ariaReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdminCraftedAriaComposer(editor: editor, instruction: $panel.instruction, hasProposal: proposal != nil,
                                     actions: actions)
        }
    }

    // MARK: Parti

    @ViewBuilder
    private var scope: some View {
        let text = AdminCraftedAriaText.scopeText(count: panel.scope.count)
        if canPickScope {
            Button { panel.showsScope = true } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aria works on").font(.caption).foregroundStyle(.secondary)
                        Text(text).font(.subheadline.weight(.semibold))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choose what Aria changes")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aria works on").font(.caption).foregroundStyle(.secondary)
                Text(text).font(.subheadline.weight(.semibold))
            }
        }
    }

    private var working: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(editor.progressText ?? String(localized: "Aria is reading and rewriting…"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
