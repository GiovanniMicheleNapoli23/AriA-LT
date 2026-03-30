//
//  AIHelpSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/03/26.
//

import SwiftUI

struct AIHelpSheet: View {
    let currentItem: ChecklistItem
    @Bindable var voice: AriaVoiceViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header
            HStack {
                Label("AriA Engine", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.liteAccent)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Procedura attuale")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(currentItem.text)
                        .font(.body.bold())
                        .foregroundStyle(Color.liteAccent)

                    if let description = currentItem.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            Divider()

            VStack(spacing: 10) {
                VoiceSessionOverlay(voice: voice)

                Button {
                    voice.toggleConnection()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: voice.isConnected ? "mic.fill" : "mic")
                            .font(.body.bold())
                            .contentTransition(.symbolEffect(.replace))
                        Text(voice.isConnected ? "Termina conversazione" : "Chiedi ad AriA")
                            .font(.body.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassEffect(
                        voice.isConnected
                            ? .regular.tint(.red.opacity(0.25))
                            : .regular.tint(Color.liteAccent.opacity(0.25)),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .foregroundStyle(voice.isConnected ? .red : Color.liteAccent)
                    .animation(.easeInOut(duration: 0.2), value: voice.isConnected)
                }
                .buttonStyle(.plain)
                .disabled(voice.isConnecting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.light)
    }
}
