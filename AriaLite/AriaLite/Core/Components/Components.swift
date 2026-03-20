//
//  Components.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/03/26.
//

import SwiftUI

// SectionHeader
struct SectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }
}











