//
//  AdminWorkOrderTabBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le schede del dettaglio come pulsanti di vetro nativo con icona, senza scorrere in orizzontale:
//  in fila con icona e titolo quando ci stanno (iPad), cinque colonne uguali con il titolo sotto
//  l'icona su un iPhone in verticale, e una griglia che va a capo con il testo molto grande.
//

import SwiftUI

struct AdminWorkOrderTabBar: View {
    @Binding var selection: AdminWorkOrderTab

    var body: some View {
        AriaGlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(AdminWorkOrderTab.allCases) { tab in
                        button(tab) { AdminWorkOrderChip(title: tab.title, icon: tab.systemImage, isOn: tab == selection) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                compactBar

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(AdminWorkOrderTab.allCases) { tab in
                        button(tab) {
                            AdminWorkOrderChip(title: tab.title, icon: tab.systemImage, isOn: tab == selection)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Section"))
    }

    private func button(_ tab: AdminWorkOrderTab, @ViewBuilder label: () -> some View) -> some View {
        Button {
            selection = tab
        } label: {
            label()
        }
        .adminWorkOrderChipStyle(isOn: tab == selection)
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(tab == selection ? .isSelected : [])
    }

    /// Una barra di vetro sola con la scheda scelta piena, come un segmentato con le icone: i pulsanti di
    /// vetro hanno un margine loro e cinque non ci starebbero su un iPhone.
    private var compactBar: some View {
        HStack(spacing: 2) {
            ForEach(AdminWorkOrderTab.allCases) { tab in
                let isOn = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage).font(.footnote.weight(.semibold))
                        Text(tab.title)
                            .font(.caption2.weight(isOn ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(isOn ? Color.liteOnAccent : Color.liteText)
                    .background(isOn ? Color.liteAccent : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tab.title))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.snappy, value: selection)
    }
}
