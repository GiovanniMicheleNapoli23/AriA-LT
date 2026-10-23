//
//  AdminCraftedComposerViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il composer di Crafted ("Cosa vuoi che Aria crei?", artifact-composer.tsx): un campo, gli esempi per tipo
//  che lo riempiono, e Crea, che chiede ad Aria l'artifact tramite il generatore.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedComposerViewModel: Identifiable {
    /// Quanto può essere lunga una richiesta (maxLength della web).
    static let maxLength = 2000

    var text = "" {
        didSet {
            if text.count > Self.maxLength { text = String(text.prefix(Self.maxLength)) }
        }
    }

    @ObservationIgnored private let generator: AdminCraftedGenerator
    @ObservationIgnored private let onCreated: (AdminCraftedArtifact) -> Void

    init(generator: AdminCraftedGenerator, onCreated: @escaping (AdminCraftedArtifact) -> Void) {
        self.generator = generator
        self.onCreated = onCreated
    }

    var examples: [AdminCraftedKind.Example] { AdminCraftedKind.examples }

    /// Perché non si può creare (nessuno stabilimento), altrimenti nil.
    var blockedReason: String? { generator.blockedReason }

    var canCreate: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && blockedReason == nil }

    /// Toccare un esempio scrive una richiesta vera nel campo, da mandare così o da correggere.
    func fill(with example: AdminCraftedKind.Example) { text = example.text }

    func create() {
        guard canCreate, let artifact = generator.create(request: text) else { return }
        onCreated(artifact)
    }
}
