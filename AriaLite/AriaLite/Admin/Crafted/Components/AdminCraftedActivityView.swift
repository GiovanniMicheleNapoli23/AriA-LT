//
//  AdminCraftedActivityView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il foglio di condivisione di sistema per un file, aperto dopo che il .docx è stato preparato
//  (ShareLink vuole il file già pronto, e qui lo si scrive solo quando si tocca "Share").
//

import SwiftUI
import UIKit

struct AdminCraftedActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
