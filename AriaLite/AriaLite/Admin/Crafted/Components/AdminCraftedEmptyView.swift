//
//  AdminCraftedEmptyView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Quando la lista di Crafted non ha righe: sta caricando, niente corrisponde alla ricerca, i rapporti
//  sono solo per owner e admin, il caricamento è fallito, o non c'è ancora niente (con i tre passi che
//  portano al primo rapporto).
//

import SwiftUI

struct AdminCraftedEmptyView: View {
    let state: AdminCraftedEmptyState
    let retry: () async -> Void
    let create: () -> Void
    let canCreate: Bool

    var body: some View {
        switch state {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading documents…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        case .noMatch(let query, let category):
            if let category {
                ContentUnavailableView("No results", systemImage: "magnifyingglass",
                                       description: Text("Nothing in \(category) matches “\(query)”."))
                    .padding(.top, 40)
            } else {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 40)
            }
        case .restricted:
            nothingYet(description: Text("Intervention reports are visible to owners and admins."), showsSteps: false)
        case .failed(let message):
            AdminCraftedLoadState(error: message, title: "Can't load documents", retry: retry)
        case .empty:
            nothingYet(description: Text("Ask Aria for a chart, a plan or a work order, and it will be listed here."),
                       showsSteps: true)
        }
    }

    private func nothingYet(description: Text, showsSteps: Bool) -> some View {
        VStack(spacing: 24) {
            ContentUnavailableView {
                Label("Nothing crafted yet", systemImage: "sparkles")
            } description: {
                description
            } actions: {
                Button("New artifact", systemImage: "plus", action: create)
                    .ariaGlassButtonStyle()
                    .disabled(!canCreate)
            }
            if showsSteps { AdminCraftedPreviewSteps() }
        }
        .padding(.top, 24)
    }
}

/// I tre passi che portano al primo rapporto (preview della web).
private struct AdminCraftedPreviewSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your first report will appear here")
                .font(.headline)
            step(1, title: Text("Work it with Aria"), detail: Text("Follow an intervention in chat, one step at a time."))
            step(2, title: Text("Close the procedure"), detail: Text("Give the outcome: resolved, not resolved or unclear."))
            step(3, title: Text("Read the report"), detail: Text("Aria writes it and files it on this page."))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func step(_ number: Int, title: Text, detail: Text) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number, format: .number)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 26, minHeight: 26)
                .background(Color.secondary.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.subheadline.weight(.semibold))
                detail.font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
