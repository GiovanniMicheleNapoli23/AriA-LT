//
//  AdminCraftedReportLanguageMenu.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La lingua del rapporto: il backend lo riscrive nella lingua scelta e ogni lingua ha le sue versioni.
//

import SwiftUI

struct AdminCraftedReportLanguageMenu: View {
    let viewModel: AdminCraftedReportReaderViewModel

    var body: some View {
        Menu {
            Picker("Report language", selection: Binding(get: { viewModel.locale },
                                                         set: { viewModel.selectLanguage($0) })) {
                ForEach(viewModel.languages) { language in
                    Text(language.native).tag(language.code)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(viewModel.languageName).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.liteAccent)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .ariaGlass(in: Capsule())
        }
        .disabled(viewModel.isEditing)
        .accessibilityLabel("Report language")
        .accessibilityValue(viewModel.languageName)
    }
}
