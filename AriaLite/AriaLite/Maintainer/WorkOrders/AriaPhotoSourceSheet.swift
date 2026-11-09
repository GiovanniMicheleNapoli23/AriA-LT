//
//  AriaPhotoSourceSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 17/10/26.
//
//  Scelta della sorgente di una foto (galleria o fotocamera) per un passo del lavoro.
//

import PhotosUI
import SwiftUI

// MARK: - PhotoSourceSheet

struct PhotoSourceSheet: View {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let onCamera: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// Altezza misurata del contenuto: il foglio è alto quanto serve, né tagliato né vuoto.
    @State private var sheetHeight: CGFloat = 214
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Coi testi di accessibilità le due caselle affiancate non ci stanno: una sotto l'altra.
    private var tilesLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Photo")
                .font(.headline)
                .foregroundStyle(.primary)

            tilesLayout {
                // Galleria
                PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                    PhotoSourceTile(
                        icon: "photo.on.rectangle.angled",
                        label: String(localized: "Gallery")
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: selectedPhotoItems) { _, items in
                    if !items.isEmpty { dismiss() }
                }

                // Fotocamera
                Button {
                    dismiss()
                    onCamera()
                } label: {
                    PhotoSourceTile(
                        icon: "camera",
                        label: String(localized: "Camera")
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        // Sopra c'è posto per la maniglia di sistema.
        .padding(.top, 24)
        .padding(.bottom, 24)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        // iPad: il form sheet si adatta all'altezza del contenuto invece di lasciarlo a metà.
        .presentationSizing(.form.fitted(horizontal: false, vertical: true))
    }
}

// MARK: - PhotoSourceTile

private struct PhotoSourceTile: View {
    let icon: String
    let label: String
    @ScaledMetric(relativeTo: .title) private var circleSide: CGFloat = 64

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: circleSide, height: circleSide)
                Image(systemName: icon)
                    .font(.title.weight(.medium))
                    .foregroundStyle(Color.liteAccent)
            }
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 18))
    }
}
