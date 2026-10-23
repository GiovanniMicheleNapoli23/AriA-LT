//
//  AdminMarketplaceGlyph.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  L'icona di un elemento del catalogo: un quadrato arrotondato come AdminConnectorIcon, con il nome Lucide
//  della web tradotto in un simbolo SF (o quello del tipo). Vale anche per i connettori del catalogo.
//

import SwiftUI

struct AdminMarketplaceGlyph: View {
    let item: AdminMarketplaceItem
    /// Sostituisce il lato scalato di 44 (il dettaglio la usa più grande).
    var side: CGFloat? = nil
    @ScaledMetric(relativeTo: .title3) private var scaledSide: CGFloat = 44

    private var resolvedSide: CGFloat { side ?? scaledSide }

    /// Nomi Lucide del catalogo → simboli SF che esistono da iOS 17.
    private static let symbols: [String: String] = [
        "Workflow": "point.3.connected.trianglepath.dotted", "Building2": "building.2",
        "Wrench": "wrench.and.screwdriver", "PackageSearch": "shippingbox", "Truck": "truck.box",
        "ClipboardCheck": "checklist", "FlaskConical": "flask", "Factory": "gearshape.2",
        "MessageSquare": "bubble.left.and.bubble.right", "Mail": "envelope", "Bot": "cpu",
        "Sunrise": "sunrise", "Radar": "dot.radiowaves.left.and.right", "Bell": "bell",
        "Gauge": "gauge.with.needle", "ChartColumn": "chart.bar", "ScrollText": "scroll",
        "Lock": "lock", "ShieldCheck": "checkmark.shield", "Leaf": "leaf", "MonitorCog": "desktopcomputer",
        "Radio": "antenna.radiowaves.left.and.right", "Waypoints": "point.3.connected.trianglepath.dotted",
        "Server": "server.rack", "Activity": "waveform.path.ecg", "Table2": "tablecells",
        "Database": "cylinder.split.1x2", "ClipboardList": "list.clipboard", "Boxes": "square.stack.3d.up",
        "Headset": "headphones", "Ticket": "ticket", "Phone": "phone", "BookOpen": "book",
        "ListChecks": "list.bullet.clipboard", "FolderOpen": "folder", "CalendarDays": "calendar",
        "Sparkles": "sparkles", "Zap": "bolt", "HardHat": "figure.stand",
        "ShieldAlert": "exclamationmark.shield", "ChartLine": "chart.xyaxis.line", "Plug": "cable.connector",
        "Gavel": "hammer", "Thermometer": "thermometer.medium", "Recycle": "arrow.3.trianglepath",
        "BookMarked": "books.vertical", "CupSoda": "cup.and.saucer", "Package": "cube.box",
        "Milk": "waterbottle", "Cog": "gearshape", "Wind": "wind", "Cylinder": "cylinder", "Pill": "pills",
        "BrickWall": "square.grid.3x3.fill",
    ]

    private var systemImage: String {
        item.icon.flatMap { Self.symbols[$0] } ?? item.kind.systemImage
    }

    /// Il colore del marchio per un connettore senza logo (PI, ServiceNow): il simbolo del catalogo nel suo colore.
    private var tint: Color {
        item.kind == .connector ? (AdminConnectorBrand.forProvider(item.sourceId).color ?? .liteAccent) : .liteAccent
    }

    var body: some View {
        if item.kind == .connector, AdminConnectorBrand.forProvider(item.sourceId).imageName != nil {
            AdminConnectorIcon(provider: item.sourceId, name: item.name, side: resolvedSide)
        } else {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .foregroundStyle(tint)
                .padding(resolvedSide * 0.25)
                .frame(width: resolvedSide, height: resolvedSide)
                .background(tint.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: resolvedSide * 0.28, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}
