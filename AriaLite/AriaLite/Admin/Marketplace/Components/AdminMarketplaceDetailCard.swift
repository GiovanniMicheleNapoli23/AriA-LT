//
//  AdminMarketplaceDetailCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una scheda del dettaglio: titolo con icona, didascalia facoltativa, accessorio a destra e contenuto, sul vetro come le altre schede admin.
//

import SwiftUI

struct AdminMarketplaceDetailCard<Accessory: View, Content: View>: View {
    let title: Text
    let systemImage: String
    var caption: Text?
    private let accessory: Accessory
    private let content: Content

    init(title: Text, systemImage: String, caption: Text? = nil,
         @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.caption = caption
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liteAccent)
                        .accessibilityHidden(true)
                    title
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    accessory
                }
                if let caption {
                    caption
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

extension AdminMarketplaceDetailCard where Accessory == EmptyView {
    init(title: Text, systemImage: String, caption: Text? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, systemImage: systemImage, caption: caption, accessory: { EmptyView() }, content: content)
    }
}
