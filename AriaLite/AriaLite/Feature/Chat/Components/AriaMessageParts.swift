//
//  AriaMessageParts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le parti di una risposta di Aria sopra e sotto il testo: strumenti usati, fonti, ragionamento,
//  conoscenza usata, immagini, eventi CMMS e i pulsanti di navigazione.
//

import SwiftUI

/// Gli strumenti che Aria sta usando o ha usato, con il loro stato.
struct AriaMessageActivityStrip: View {
    let calls: [AriaToolCall]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(calls) { call in
                HStack(spacing: 6) {
                    switch call.status {
                    case .running: ProgressView().controlSize(.mini)
                    case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .error: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    case .proposed: Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
                    case .rejected: Image(systemName: "nosign").foregroundStyle(.red)
                    case .unknown: Image(systemName: "gearshape").foregroundStyle(.secondary)
                    }
                    Text(AriaChatCopy.toolLabel(call.name))
                        .foregroundStyle(.secondary)
                    if let error = call.error, call.status == .error {
                        Text(error).foregroundStyle(.red).lineLimit(1)
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
    }
}

struct AriaMessageSources: View {
    let sources: [AriaSourceRef]
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sources, id: \.self) { source in
                    if let url = source.url.flatMap(URL.init(string:)).flatMap(AriaURLPolicy.external) {
                        Link(destination: url) { Label(source.title, systemImage: "link") }
                    } else {
                        Label(source.title, systemImage: "doc.text")
                    }
                }
            }
            .font(.system(size: 12))
            .padding(.top, 4)
        } label: {
            Text("\(sources.count) sources").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
        }
    }
}

struct AriaMessageReasoning: View {
    let text: String
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        } label: {
            Label("Reasoning", systemImage: "brain.head.profile")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct AriaMessageFactsUsed: View {
    let facts: [String]
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(facts, id: \.self) { Text("• \($0)") }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        } label: {
            Label("Learned knowledge used · \(facts.count)", systemImage: "books.vertical")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct AriaMessageImages: View {
    let images: [AriaImageReference]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images) { image in
                    if let url = URL(string: image.url).flatMap(AriaURLPolicy.external) {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Si scarica solo da https; il link resta valido anche con http.
                                AsyncImage(url: AriaURLPolicy.image(url)) { phase in
                                    if let picture = phase.image {
                                        picture.resizable().scaledToFill()
                                    } else {
                                        Color(.tertiarySystemFill)
                                    }
                                }
                                .frame(width: 150, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                if let caption = image.caption {
                                    Text(caption).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                            .frame(width: 150)
                        }
                    }
                }
            }
        }
    }
}

/// Eventi CMMS della pipeline: WO suggerito e scritture su sistemi esterni (MaintainX).
struct AriaMessageCMMSNotices: View {
    let pipeline: [AriaPipelineEntry]
    /// Apre l'entità citata (tipo e id) sulla web app.
    var onOpenEntity: (_ type: String, _ id: String) -> Void

    var body: some View {
        ForEach(pipeline) { entry in
            switch entry.name {
            case "aria.cmms_work_order_created" where entry.data["detected"]?.boolValue == true:
                AriaCard(tint: .blue) {
                    // Su 375-390 pt in italiano etichetta e badge non stanno su una riga: il badge va sotto.
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Label("Work order suggested", systemImage: "wand.and.stars").font(.system(size: 13, weight: .semibold))
                            Spacer()
                            AriaBadge(text: String(localized: "auto-detected"), tint: .blue).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Work order suggested", systemImage: "wand.and.stars").font(.system(size: 13, weight: .semibold))
                            AriaBadge(text: String(localized: "auto-detected"), tint: .blue)
                        }
                    }
                    if let title = entry.data["title"]?.nonEmptyString { Text(title).font(.system(size: 14, weight: .medium)) }
                    if let suggestion = entry.data["suggestion"]?.nonEmptyString {
                        Text(suggestion).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            case "aria.external_action":
                let ok = entry.data["status"]?.stringValue == "ok"
                Label("\(entry.data["system"]?.stringValue ?? "CMMS"): \(entry.data["summary"]?.stringValue ?? entry.data["tool"]?.stringValue ?? "")",
                      systemImage: ok ? "arrow.up.forward.app.fill" : "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ok ? .green : .orange)
            case "aria.cmms_entity_referenced":
                if let type = entry.data["entity_type"]?.stringValue, let id = entry.data["entity_id"]?.stringValue {
                    Button(entry.data["entity_label"]?.stringValue ?? "\(type) \(id)", systemImage: "link") {
                        onOpenEntity(type, id)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.borderless)
                }
            default:
                EmptyView()
            }
        }
    }
}

/// ui-action-bar della web: nessuna navigazione automatica, solo pulsanti.
struct AriaMessageActionBar: View {
    let actions: [AriaUIAction]
    var onOpen: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    if let to = action.to {
                        Button(AriaChatCopy.actionLabel(for: action)) { onOpen(to) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}
