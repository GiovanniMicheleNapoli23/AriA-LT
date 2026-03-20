//
//  WorkOrderRowView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//

import SwiftUI

// MARK: - WorkOrderRowView
struct WorkOrderRowView: View {
    let workOrder: WorkOrder
    let viewModel: AppViewModel

    private var completedCount: Int {
        workOrder.checklist.filter { viewModel.isItemCompleted($0, in: workOrder.id) }.count
    }

    private var progress: Double {
        Double(completedCount) / Double(max(workOrder.checklist.count, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workOrder.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(completedCount)/\(workOrder.checklist.count) completati · \(workOrder.documents.count) doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(progress >= 1 ? .green : Color.liteAccent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.liteAccent.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(progress >= 1 ? Color.green : Color.liteAccent)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(duration: 0.4), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
