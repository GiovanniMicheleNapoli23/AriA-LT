//
//  AdminCraftedArtifactStateView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Quando non c'è ancora niente da leggere: Aria lo sta creando, si sta aprendo la conversazione, oppure
//  non è stato possibile crearlo (con "Riprova"). La richiesta sta già nell'intestazione.
//

import SwiftUI

struct AdminCraftedArtifactStateView: View {
    let phase: AdminCraftedArtifactReaderViewModel.Phase
    let failureNote: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            switch phase {
            case .failed:
                Image(systemName: "exclamationmark.triangle").font(.title).foregroundStyle(.orange)
                Text("It could not be made").font(.headline)
                Text(failureNote).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button(action: retry) { Label("Try again", systemImage: "arrow.clockwise") }
                    .ariaGlassButtonStyle()
                    .padding(.top, 4)
            case .generating:
                ProgressView().controlSize(.large)
                Text("Aria is making it").font(.headline)
                Text("Carry on working: when it is ready you will find it in this list.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            default:
                ProgressView().controlSize(.large)
                Text("Opening…").font(.headline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
