//
//  SearchBar.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/30.
//
import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    // swiftUI 計算參數
    private var searchText: Binding<String> {
        Binding<String>(
            get: {
                self.text.capitalized
            }, set: {
                self.text = $0
            } )
    }
    
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            TextField("Search ...", text: searchText) { editing in
                withAnimation {
                    self.isEditing = editing
                }
            }
            .padding(7)
            .padding(.horizontal, 25)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                    if isEditing {
                        Button(action: {
                            self.text = ""
                        }) {
                            Image(systemName: "multiply.circle.fill")
                                .foregroundStyle(.gray)
                                .padding(.trailing, 8)
                        }
                    }
                    
                    
                })
            .padding(.horizontal, 10)
            .onTapGesture {
                withAnimation {
                    self.isEditing = true
                }
            }
            
            if isEditing {
                Button(action: {
                    self.isEditing = false
                    self.text = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Text("Cancel")
                }
                .padding(.trailing, 10)
            }
        }
    }
}


#Preview {
    @Previewable @State var text: String = ""
    SearchBar(text: $text)
}



