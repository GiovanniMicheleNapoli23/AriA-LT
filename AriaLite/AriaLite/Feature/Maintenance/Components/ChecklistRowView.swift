//
//  ChecklistRowView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//
import SwiftUI

// ChecklistRowView
struct ChecklistRowView: View {
    let item: ChecklistItem
    let workOrderID: UUID
    let viewModel: AppViewModel
    let onAddNote: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            let completed = viewModel.isItemCompleted(item, in: workOrderID)
            Button {
                viewModel.toggleItem(workOrderID: workOrderID, itemID: item.id, current: completed)
            } label: {
                Image(systemName: completed ? "checkmark.square.fill" : "square")
                    .foregroundStyle(completed ? .green : .secondary)
                    .imageScale(.large)
            }

            Text(item.text)
                .strikethrough(completed, color: .secondary)
                .foregroundStyle(completed ? .secondary : .primary)

            Spacer()

            let hasNote = viewModel.fieldNotes[workOrderID]?[item.id] != nil
            Button(action: onAddNote) {
                Image(systemName: hasNote ? "note.text" : "note.text.badge.plus")
                    .foregroundStyle(hasNote ? .primary : .secondary)
            }
        }
    }
}
