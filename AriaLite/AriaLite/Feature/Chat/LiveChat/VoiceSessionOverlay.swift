//
//  VoiceSessionOverlay.swift
//  Aria_v1.0
//
//  Vista inline che appare al posto della barra di input
//  quando la chat è in modalità "Voice (WebRTC)".
//

import SwiftUI

struct VoiceSessionOverlay: View {

    @Bindable var voice: AriaVoiceViewModel

    var body: some View {
        HStack(spacing: 12) {

            // Stato dot + testo
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.4), radius: 4)

                Text(statusText)
                    .font(.caption.monospaced())
                    .foregroundStyle(statusColor)

                if voice.isSearchingDocs {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("RAG")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.orange)
                    }
                    .transition(.opacity)
                }
            }

            Spacer()

            // Waveform animata quando connesso
            if voice.isConnected {
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(Color.liteAccent.opacity(0.6))
                            .frame(width: 3, height: CGFloat([8, 14, 10, 6][i]))
                            .animation(
                                .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.12),
                                value: voice.isConnected
                            )
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }

            // Mute toggle — solo quando connesso
            if voice.isConnected {
                Button {
                    voice.isMuted.toggle()
                } label: {
                    Image(systemName: voice.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(voice.isMuted ? .red : Color.liteAccent)
                        .frame(width: 34, height: 34)
                        .glassEffect(
                            voice.isMuted
                                ? .regular.tint(.red.opacity(0.15))
                                : .regular.tint(Color.liteAccent.opacity(0.1)),
                            in: Circle()
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.25), value: voice.isConnected)
        .animation(.easeInOut(duration: 0.25), value: voice.isSearchingDocs)
        .animation(.easeInOut(duration: 0.2), value: voice.isMuted)

        if let err = voice.error {
            Text(err)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .transition(.opacity)
        }
    }

    private var statusColor: Color {
        if voice.isConnecting { return .orange }
        return voice.isConnected ? .green : .secondary
    }

    private var statusText: String {
        if voice.isConnecting { return "CONNECTING…" }
        return voice.isConnected ? "LIVE" : "OFFLINE"
    }
}
