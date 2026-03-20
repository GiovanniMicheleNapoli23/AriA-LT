//
//  ReportView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//

import SwiftUI

struct ReportView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Report",
                systemImage: "chart.bar.doc.horizontal",
                description: Text("I report saranno disponibili a breve.")
            )
            .navigationTitle("Report")
        }
    }
}

#Preview {
    ReportView()
}
