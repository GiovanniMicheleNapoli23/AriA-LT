//
//  AdminSparePart.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ricambio come lo manda il backend (SparePartResponse). Lettura tollerante: è obbligatorio solo `id`,
//  i numeri possono arrivare interi o decimali, le enum sconosciute diventano `unknown`.
//

import Foundation

nonisolated struct AdminSparePart: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var code: String
    var name: String
    var category: AdminSparePartCategory?
    var status: AdminSparePartStatus?
    var description: String?
    var manufacturer: String?
    var partNumber: String?
    var compatibleAssetTags: [String]
    var stockQuantity: Int
    var minQuantity: Int?
    var unit: String?
    var unitPrice: Double?
    var location: String?
    var barcode: String?
    /// Articolo non a magazzino: la quantità non si segue.
    var nonStock: Bool
    var plantId: String?
    var vendorId: String?
    /// Testo grezzo: l'URL si risolve (e si controlla) nel view model.
    var photoUrl: String?
    var createdAt: Date?
    var updatedAt: Date?
    /// Quanto è sicura l'estrazione automatica (ricambi creati dall'AI), 0…1.
    var confidence: Double?

    init(from decoder: any Decoder) throws {
        let wire = try AdminSparePartWireReader(decoder)
        guard let id = wire.string("id") else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Spare part without id"))
        }
        self.id = id
        code = wire.string("code") ?? ""
        name = wire.string("name") ?? ""
        category = wire.string("category").map(AdminSparePartCategory.init(wire:))
        status = wire.string("status").map(AdminSparePartStatus.init(wire:))
        description = wire.string("description")
        manufacturer = wire.string("manufacturer")
        partNumber = wire.string("partNumber")
        compatibleAssetTags = wire.strings("compatibleAssetTags")
        stockQuantity = wire.int("stockQuantity") ?? 0
        minQuantity = wire.int("minQuantity")
        unit = wire.string("unit")
        unitPrice = wire.double("unitPrice")
        location = wire.string("location")
        barcode = wire.string("barcode")
        nonStock = wire.bool("nonStock") ?? false
        plantId = wire.string("plantId")
        vendorId = wire.string("vendorId")
        photoUrl = wire.string("photoUrl")
        createdAt = wire.date("createdAt")
        updatedAt = wire.date("updatedAt")
        confidence = wire.double("confidence")
    }

    /// Scorta bassa con la stessa regola di GET /v1/spare-parts/low-stock (`stock <= min`, oppure 0);
    /// un articolo non a magazzino non è mai "basso".
    var isLowStock: Bool {
        guard !nonStock else { return false }
        if stockQuantity <= 0 { return true }
        if let minQuantity { return stockQuantity <= minQuantity }
        return false
    }

    /// "12 pcs": la quantità con l'unità del ricambio, se c'è.
    func quantityText(_ quantity: Int) -> String {
        guard let unit else { return "\(quantity)" }
        return "\(quantity) \(unit)"
    }

    /// Il nome da mostrare: senza nome, il codice.
    var title: String { name.isEmpty ? code : name }
}
