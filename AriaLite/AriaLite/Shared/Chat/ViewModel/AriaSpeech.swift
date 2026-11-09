//
//  AriaSpeech.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lettura ad alta voce di una risposta (il pulsante con l'altoparlante sotto i messaggi).
//

import AVFoundation
import Foundation

@MainActor
final class AriaSpeech {
    static let shared = AriaSpeech()
    private let synthesizer = AVSpeechSynthesizer()

    func toggle(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        // Senza markdown: si legge il testo, non i simboli.
        let plain = String(AriaMarkdown.inline(text).characters)
            .replacingOccurrences(of: #"[#>|*`_]"#, with: "", options: .regularExpression)
        let utterance = AVSpeechUtterance(string: plain)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier == "it" ? "it-IT" : "en-US")
        synthesizer.speak(utterance)
    }
}
