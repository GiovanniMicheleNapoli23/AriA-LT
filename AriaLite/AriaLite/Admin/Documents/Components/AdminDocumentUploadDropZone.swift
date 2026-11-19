//
//  AdminDocumentUploadDropZone.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il foglio di caricamento senza file: un'area tratteggiata, tutta toccabile, che apre Files e dice
//  quali formati si possono caricare.
//

import SwiftUI

struct AdminDocumentUploadDropZone: View {
    let isReading: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var iconSide: CGFloat = 52

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.liteAccent.opacity(0.12))
                    if isReading {
                        ProgressView()
                    } else {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.liteAccent)
                    }
                }
                .frame(width: iconSide, height: iconSide)
                Text("Choose files")
                    .font(.headline)
                    .foregroundStyle(Color.liteText)
                Text("PDF, Word, Excel, PowerPoint, text or images")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .background(Color.liteAccent.opacity(0.04), in: shape)
            .overlay {
                shape.strokeBorder(Color.liteAccent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }
}
