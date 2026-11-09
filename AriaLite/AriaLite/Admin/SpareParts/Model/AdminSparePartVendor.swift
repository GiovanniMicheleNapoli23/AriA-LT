//
//  AdminSparePartVendor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un fornitore (VendorResponse): ai ricambi servono solo il nome da mostrare e la scelta nel modulo.
//

import Foundation

nonisolated struct AdminSparePartVendor: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let companyName: String?
    let vendorType: String?

    init(from decoder: any Decoder) throws {
        let wire = try AdminSparePartWireReader(decoder)
        guard let id = wire.string("id") else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Vendor without id"))
        }
        self.id = id
        companyName = wire.string("companyName")
        name = wire.string("name") ?? companyName ?? id
        vendorType = wire.string("vendorType")
    }

    /// Il nome e, se diversa, la ragione sociale.
    var displayName: String {
        guard let companyName, companyName != name else { return name }
        return "\(name) (\(companyName))"
    }
}
