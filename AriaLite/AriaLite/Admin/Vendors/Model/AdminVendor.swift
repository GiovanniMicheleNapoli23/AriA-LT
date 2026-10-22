//
//  AdminVendor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un fornitore come lo manda il backend (VendorResponse). Lettura tollerante: è obbligatorio solo `id`
//  (nell'OpenAPI è facoltativo, ma senza non si apre il dettaglio), i campi illeggibili valgono come assenti,
//  il rating può arrivare intero, decimale o come testo.
//

import Foundation

nonisolated struct AdminVendor: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String
    var companyName: String?
    var email: String?
    var phone: String?
    var website: String?
    var address: String?
    var city: String?
    var country: String?
    /// Testo libero (l'OpenAPI non ha un elenco): si mostra com'è, senza mai interpretarlo.
    var vendorType: String?
    var rating: Double?
    var notes: String?
    var plantId: String?
    var createdAt: Date?
    var updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, name, companyName, email, phone, website, address, city, country
        case vendorType, rating, notes, plantId, createdAt, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        func text(_ key: CodingKeys) -> String? { json(key)?.nonEmptyString }
        guard let id = text(.id) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Vendor without id"))
        }
        self.id = id
        name = text(.name) ?? ""
        companyName = text(.companyName)
        email = text(.email)
        phone = text(.phone)
        website = text(.website)
        address = text(.address)
        city = text(.city)
        country = text(.country)
        vendorType = text(.vendorType)
        rating = json(.rating)?.doubleValue.flatMap { $0.isFinite ? $0 : nil }
        notes = text(.notes)
        plantId = text(.plantId)
        createdAt = text(.createdAt).flatMap(AriaWireDate.parse)
        updatedAt = text(.updatedAt).flatMap(AriaWireDate.parse)
    }

    /// Il nome da mostrare: senza nome, la ragione sociale.
    var title: String {
        if !name.isEmpty { return name }
        return companyName ?? String(localized: "Unnamed vendor")
    }

    /// La ragione sociale, solo se dice qualcosa in più del nome.
    var distinctCompanyName: String? {
        guard let companyName, companyName.caseInsensitiveCompare(name) != .orderedSame else { return nil }
        return companyName
    }

    /// Il rating portato nella scala 0…5 (un valore fuori scala dal server non rompe le stelle).
    var clampedRating: Double? { rating.map(AdminVendorRating.clamp) }

    /// "Milano, Italy": città e paese, quelli che ci sono.
    var cityAndCountry: String? {
        let parts = [city, country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
