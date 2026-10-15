//
//  AriaURLPolicy.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Quali URL arrivati dal modello o dal server si possono aprire o caricare: solo web e mail,
//  mai gli schemi che attivano altre app (tel:, sms:, aria://sign-in…) o file locali.
//

import Foundation

nonisolated enum AriaURLPolicy {
    /// Link da aprire fuori dall'app: https, http (con host) e mailto.
    static func external(_ url: URL) -> URL? {
        switch url.scheme?.lowercased() {
        case "https", "http": hasHost(url) ? url : nil
        case "mailto": url
        default: nil
        }
    }

    /// Immagini da scaricare: solo https.
    static func image(_ url: URL) -> URL? {
        url.scheme?.lowercased() == "https" && hasHost(url) ? url : nil
    }

    private static func hasHost(_ url: URL) -> Bool {
        !(url.host(percentEncoded: false) ?? "").isEmpty
    }
}
