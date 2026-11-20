//
//  AdminConnectorBrand.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il marchio di un connettore (logo e colore) letto dal catalogo del Marketplace, per provider.
//  I provider ritirati non sono nel catalogo: per loro vale solo l'asset, se esiste.
//

import SwiftUI
import UIKit

nonisolated struct AdminConnectorBrand: Sendable, Hashable {
    /// Il nome dell'immagine nel catalogo asset ("ConnectorBrands/<provider>"), nil se non c'è.
    let imageName: String?
    /// Il colore del marchio, "#RRGGBB", nil se non c'è.
    let hex: String?

    /// Un marchio per ogni connettore del catalogo, letto una volta sola. Logo e colore non si traducono: si legge
    /// solo quel che serve dal JSON del bundle (non il catalogo intero, che si decodifica con le traduzioni nel
    /// Marketplace), così il primo disegno di un'icona, anche nella chat, non pesa sul main actor.
    nonisolated private static let byProvider: [String: AdminConnectorBrand] = {
        guard let url = Bundle.main.url(forResource: "MarketplaceCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return [:] }
        var result: [String: AdminConnectorBrand] = [:]
        for entry in payload.items where entry.kind == AdminMarketplaceKind.connector.rawValue {
            guard let provider = entry.sourceId else { continue }
            result[provider] = AdminConnectorBrand(imageName: entry.connector?.brandImage, hex: entry.connector?.brandHex)
        }
        return result
    }()

    /// Solo i campi del catalogo che servono al marchio; un elemento strano non svuota gli altri.
    nonisolated private struct Payload: Decodable {
        let items: [Entry]

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var list = try container.nestedUnkeyedContainer(forKey: .items)
            var entries: [Entry] = []
            while !list.isAtEnd {
                if let entry = try? list.decode(Entry.self) { entries.append(entry) } else { _ = try? list.decode(Skip.self) }
            }
            items = entries
        }

        private nonisolated enum CodingKeys: String, CodingKey { case items }
        private nonisolated struct Skip: Decodable {}
    }

    nonisolated private struct Entry: Decodable {
        let kind: String?
        let sourceId: String?
        let connector: Brand?

        nonisolated struct Brand: Decodable {
            let brandImage: String?
            let brandHex: String?
        }

        private nonisolated enum CodingKeys: String, CodingKey { case kind, sourceId, connector }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = try? c.decodeIfPresent(String.self, forKey: .kind)
            sourceId = try? c.decodeIfPresent(String.self, forKey: .sourceId)
            connector = try? c.decodeIfPresent(Brand.self, forKey: .connector)
        }
    }

    /// Il marchio del provider: dal catalogo, o solo l'asset se il provider non è più nel catalogo.
    nonisolated static func forProvider(_ provider: String) -> AdminConnectorBrand {
        if let brand = byProvider[provider] { return brand }
        let asset = "ConnectorBrands/\(provider)"
        return AdminConnectorBrand(imageName: UIImage(named: asset) != nil ? asset : nil, hex: nil)
    }

    /// Il colore del marchio; nil se `hex` non è un "#RRGGBB" valido.
    var color: Color? {
        guard let rgb else { return nil }
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// Luminanza relativa WCAG (0 nero, 1 bianco): serve a non far sparire i marchi scuri nel dark mode.
    var relativeLuminance: Double? {
        guard let rgb else { return nil }
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    private var rgb: (red: Double, green: Double, blue: Double)? {
        guard let hex, hex.count == 7, hex.hasPrefix("#"),
              let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255,
                Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255)
    }
}
