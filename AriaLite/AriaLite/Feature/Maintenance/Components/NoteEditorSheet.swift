//
//  NoteEditorSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//
import SwiftUI

struct NoteEditorSheet: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(16)
                .navigationTitle("Nota")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla", action: onCancel)
                            .tint(Color.liteAccent)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: onSave) {
                            Text("Salva")
                                .fontWeight(.semibold)
                        }
                        .tint(Color.liteAccent)
                    }
                }


        }
        .ignoresSafeArea(.keyboard)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}



#Preview {
    @Previewable @State var text: String = "Hello, World!"
    NoteEditorSheet(text: $text, onSave: {}, onCancel: {})
}
