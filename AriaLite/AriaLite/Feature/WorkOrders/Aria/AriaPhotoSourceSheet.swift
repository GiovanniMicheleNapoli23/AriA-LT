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

    var body: some View {
        VStack(spacing: 16) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Text("Add Photo")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 4)

            HStack(spacing: 16) {
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
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(200)])
        
    }
}

// MARK: - PhotoSourceTile

private struct PhotoSourceTile: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.liteAccent)
            }
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 18))
    }
}
