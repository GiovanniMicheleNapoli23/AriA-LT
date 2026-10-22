//
//  AdminComingSoonPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le sezioni che sulla web sono ancora "coming soon" e non chiamano il backend: Meters, Locations,
//  Checklist Templates. Qui solo titolo, icona e una riga di spiegazione.
//

import Foundation

enum AdminComingSoonPage: Hashable {
    case meters
    case locations
    case checklistTemplates

    var title: LocalizedStringResource {
        switch self {
        case .meters: "Meters"
        case .locations: "Locations"
        case .checklistTemplates: "Checklist Templates"
        }
    }

    var systemImage: String {
        switch self {
        case .meters: "gauge.with.needle"
        case .locations: "mappin.and.ellipse"
        case .checklistTemplates: "checklist"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .meters: "Meter readings for your assets will appear here."
        case .locations: "The places where your assets are installed will appear here."
        case .checklistTemplates: "Reusable checklists for work orders and inspections will appear here."
        }
    }
}
