//
//  AdminCraftedPaperBlock.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un paragrafo della pagina: titolo o testo (con il markdown scritto come testo reso da AriaMarkdown),
//  marcato se letto diverso dall'originale, con le parole cambiate nel confronto, o aperto alla tastiera
//  quando si modifica. Colori fissi: sta sulla carta bianca.
//

import SwiftUI

struct AdminCraftedPaperBlock: View {
    let viewModel: AdminCraftedReportReaderViewModel
    let index: Int
    /// Il corpo di una cella di tabella è più piccolo del testo della pagina.
    var isInTable = false

    @FocusState private var isFocused: Bool
    @ScaledMetric private var spacer = 8.0
    @ScaledMetric private var inset = 6.0

    var body: some View {
        let style = viewModel.blockStyle(at: index)
        if case .editing = style {
            field
        } else if isBlank {
            Color.clear.frame(height: spacer)
        } else if viewModel.isEditable(index) {
            Button { viewModel.beginEditing(block: index) } label: { marked(label(style), style) }
                .buttonStyle(.plain)
                .accessibilityHint("Edit")
        } else if viewModel.isPickable(index) {
            Button { viewModel.togglePick(index) } label: { marked(label(style), style) }
                .buttonStyle(.plain)
                .accessibilityHint("Pick for Aria")
        } else {
            marked(label(style), style)
        }
    }

    /// Spazio fra due paragrafi: nelle celle sì, c'è sempre qualcosa da toccare.
    private var isBlank: Bool {
        if isInTable { return false }
        return viewModel.text(at: index).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var level: Int? { viewModel.headingLevel(at: index) }

    private var font: Font {
        switch level {
        case 0?: .title.weight(.bold)
        case 1?: .title2.weight(.bold)
        case 2?: .title3.weight(.bold)
        case 3?: .headline
        case .some: .subheadline.weight(.bold)
        case nil: isInTable ? .footnote : .callout
        }
    }

    @ViewBuilder
    private func label(_ style: AdminCraftedReportReaderViewModel.BlockStyle) -> some View {
        Group {
            if case .diff(let segments) = style {
                Text(AdminCraftedPaperStyle.attributed(segments))
            } else {
                Text(AriaMarkdown.inline(viewModel.text(at: index)))
            }
        }
        .font(font)
        .foregroundStyle(AdminCraftedPaperStyle.ink)
        .frame(maxWidth: .infinity, minHeight: isInTable ? spacer * 2 : nil, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    /// Letto diverso dall'originale: fondo chiaro e una barretta; in modifica, un fondo che dice "tocca".
    @ViewBuilder
    private func marked(_ view: some View, _ style: AdminCraftedReportReaderViewModel.BlockStyle) -> some View {
        if case .edited = style {
            view
                .padding(.leading, inset)
                .background(AdminCraftedPaperStyle.editedFill, in: RoundedRectangle(cornerRadius: 2))
                .overlay(alignment: .leading) {
                    Rectangle().fill(AdminCraftedPaperStyle.editedBar).frame(width: 3)
                }
        } else if case .picked = style {
            view
                .padding(.horizontal, 2)
                .background(AdminCraftedPaperStyle.editableFill, in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(AdminCraftedPaperStyle.editableRing, lineWidth: 2))
        } else if viewModel.isEditing {
            view
                .padding(.horizontal, 2)
                .background(AdminCraftedPaperStyle.editableFill, in: RoundedRectangle(cornerRadius: 3))
        } else {
            view
        }
    }

    private var field: some View {
        TextField("Paragraph", text: Binding(get: { viewModel.text(at: index) },
                                             set: { viewModel.setDraft($0, at: index) }), axis: .vertical)
            .focused($isFocused)
            .font(font)
            .foregroundStyle(AdminCraftedPaperStyle.ink)
            .tint(AdminCraftedPaperStyle.editableRing)
            .submitLabel(.done)
            .padding(inset)
            .background(AdminCraftedPaperStyle.editableFill, in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(AdminCraftedPaperStyle.editableRing, lineWidth: 2))
            .onAppear { isFocused = true }
    }
}
