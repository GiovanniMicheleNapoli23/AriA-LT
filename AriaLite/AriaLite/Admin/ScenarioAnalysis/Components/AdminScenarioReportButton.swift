//
//  AdminScenarioReportButton.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il report Word di una procedura: "Download report", poi anteprima (Quick Look) e condivisione del file.
//

import QuickLook
import SwiftUI

struct AdminScenarioReportButton: View {
    let viewModel: AdminScenarioReportViewModel

    @State private var previewURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let file = viewModel.file {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { fileActions(file) }
                    VStack(alignment: .leading, spacing: 10) { fileActions(file) }
                }
                Text(file.filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Button {
                    Task { await viewModel.download() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                            Text("Preparing report…")
                        } else {
                            Image(systemName: "doc.text")
                            Text("Download report (.docx)")
                        }
                    }
                }
                .ariaGlassButtonStyle()
                .disabled(viewModel.isLoading)
            }
            if let message = viewModel.errorMessage {
                AdminSectionNotice(text: message, isError: true)
            }
        }
        .quickLookPreview($previewURL)
    }

    @ViewBuilder
    private func fileActions(_ file: AriaReportFile) -> some View {
        Button {
            previewURL = file.url
        } label: {
            Label("Preview", systemImage: "eye")
        }
        .ariaGlassButtonStyle()
        ShareLink(item: file.url) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .ariaGlassButtonStyle()
    }
}
