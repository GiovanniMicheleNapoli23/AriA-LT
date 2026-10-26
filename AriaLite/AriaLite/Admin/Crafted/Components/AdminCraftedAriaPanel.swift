//
//  AdminCraftedAriaPanel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il pannello di Aria (AriaEditCard della web): su cosa lavora, cosa si sono detti, a che punto è, la
//  proposta con Accetta e Scarta, e in fondo la riga per dare l'istruzione — o un seguito, nella stessa
//  conversazione. Prima della prima richiesta, due righe su cosa succede e tre istruzioni pronte.
//  Si scorre in verticale; la riga dell'istruzione resta sotto, flottante.
//

import SwiftUI

struct AdminCraftedAriaPanel: View {
    let editor: AdminCraftedAriaEditor
    @Binding var panel: AdminCraftedAriaPanelState
    let proposal: AdminCraftedAriaProposalSummary?
    let actions: AdminCraftedAriaActions

    @ScaledMetric(relativeTo: .callout) private var orbSide: CGFloat = 22

    /// Si sceglie su cosa lavora Aria solo prima della prima richiesta: i seguiti restano su quello.
    private var canPickScope: Bool { editor.sessionId == nil && !editor.isRunning }
    private var isFresh: Bool { editor.thread.isEmpty && !editor.isRunning }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isFresh { AdminCraftedAriaIntro() }
                    scope
                    if isFresh {
                        AdminCraftedAriaSuggestions(isEnabled: editor.blockedReason == nil, pick: ask)
                    }
                    AdminCraftedAriaThread(lines: editor.thread)
                    if editor.isRunning { working }
                    if let proposal, !editor.isRunning {
                        AdminCraftedAriaProposalCard(summary: proposal, actions: actions)
                    }
                    Color.clear.frame(height: 1).id(Self.end)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .ariaReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            // Una riga nuova, il lavoro che parte o la proposta che arriva: si va in fondo per vederla.
            .onChange(of: editor.thread.count) { scrollToEnd(reader) }
            .onChange(of: proposal) { scrollToEnd(reader) }
        }
        .ariaBottomBar {
            AdminCraftedAriaComposer(editor: editor, instruction: $panel.instruction, hasProposal: proposal != nil,
                                     actions: actions)
        }
    }

    private static let end = "aria.panel.end"

    private func scrollToEnd(_ reader: ScrollViewProxy) {
        withAnimation(.snappy) { reader.scrollTo(Self.end, anchor: .bottom) }
    }

    /// Un'istruzione pronta parte subito: è già intera, e la proposta si può sempre scartare.
    private func ask(_ instruction: String) {
        panel.instruction = instruction
        actions.send()
    }

    // MARK: Parti

    private var scope: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { scopeCaption; scopeValue }
            VStack(alignment: .leading, spacing: 6) { scopeCaption; scopeValue }
        }
    }

    private var scopeCaption: some View {
        Text("Aria works on").font(.subheadline).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var scopeValue: some View {
        let label = Label(AdminCraftedAriaText.scopeText(count: panel.scope.count),
                          systemImage: panel.scope.isEmpty ? "doc.text" : "checklist")
            .font(.subheadline.weight(.semibold))
        if canPickScope {
            Button { panel.showsScope = true } label: {
                HStack(spacing: 6) {
                    label
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.fill.tertiary, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choose what Aria changes")
        } else {
            label
        }
    }

    private var working: some View {
        HStack(spacing: 10) {
            AriaOrb(mood: .thinking).frame(width: orbSide, height: orbSide)
            Text(editor.progressText ?? String(localized: "Aria is reading and rewriting…"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
