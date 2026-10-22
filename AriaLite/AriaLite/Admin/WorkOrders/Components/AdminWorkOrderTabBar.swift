//
//  AdminWorkOrderTabBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le schede del dettaglio come pulsanti di vetro nativo con icona, che scorrono in orizzontale: cinque
//  segmenti non ci stanno su un iPhone in verticale.
//

import SwiftUI

struct AdminWorkOrderTabBar: View {
    @Binding var selection: AdminWorkOrderTab

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                AriaGlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(AdminWorkOrderTab.allCases) { tab in
                            Button {
                                selection = tab
                            } label: {
                                AdminWorkOrderChip(title: tab.title, icon: tab.systemImage, isOn: tab == selection)
                            }
                            .adminWorkOrderChipStyle(isOn: tab == selection)
                            .accessibilityAddTraits(tab == selection ? .isSelected : [])
                            .id(tab)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            // Il vetro (e la sua ombra) non si taglia ai bordi della striscia.
            .scrollClipDisabled()
            .onChange(of: selection) { _, tab in
                withAnimation(.snappy) { proxy.scrollTo(tab, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Section"))
    }
}
