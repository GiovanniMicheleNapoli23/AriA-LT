//
//  AdminDocumentFileIcon.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'icona di un documento secondo il tipo di file (PDF, foglio, immagine…), in un quadrato
//  che cresce con il Dynamic Type come il testo accanto.
//

import SwiftUI

struct AdminDocumentFileIcon: View {
    let fileName: String?
    let mimeType: String?
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 40

    var body: some View {
        Image(systemName: Self.symbol(fileName: fileName, mimeType: mimeType))
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.liteAccent)
            .frame(width: side, height: side)
            .background(Color.liteAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }

    /// Simbolo SF per tipo MIME, o per estensione se il tipo manca.
    static func symbol(fileName: String?, mimeType: String?) -> String {
        let mime = mimeType?.lowercased() ?? ""
        let ext = (fileName as NSString?)?.pathExtension.lowercased() ?? ""
        if mime == "application/pdf" || ext == "pdf" { return "doc.richtext" }
        if mime.hasPrefix("image/") || ["jpg", "jpeg", "png", "heic", "tif", "tiff", "webp"].contains(ext) { return "photo" }
        if mime.contains("spreadsheet") || mime.contains("excel") || ["xls", "xlsx", "csv"].contains(ext) { return "tablecells" }
        if mime.contains("presentation") || ["ppt", "pptx", "key"].contains(ext) { return "rectangle.on.rectangle" }
        if mime.hasPrefix("text/") || mime.contains("word") || ["txt", "doc", "docx", "rtf", "md"].contains(ext) { return "doc.text" }
        return "doc"
    }
}
