//
//  MissListView.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import SwiftUI
import SwiftData

struct MissListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var missListItems: [MissListItem]
    @Query private var images: [ImageData]
    
    @State private var showingAddView = false
    @State private var searchText = ""
    @State private var showResolved = true
    
    var filteredItems: [MissListItem] {
        var filtered = missListItems
        
        if !showResolved {
            filtered = filtered.filter { !$0.isResolved }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            // 検索・フィルターセクション
            VStack(spacing: 12) {
                SearchBar(text: $searchText)
                
                HStack {
                    Toggle("解決済みを表示", isOn: $showResolved)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            
            // ミスリスト表示
            if filteredItems.isEmpty {
                MissListEmptyView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredItems, id: \.id) { item in
                        NavigationLink(destination: MissListDetailView(missItem: item)) {
                            MissListRowView(missItem: item)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("ミスリスト")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddView = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddView) {
            AddMissListItemView()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredItems[index])
            }
        }
    }
}

struct MissListRowView: View {
    @Environment(\.modelContext) private var modelContext
    let missItem: MissListItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(missItem.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .tracking(0.3)
                        .lineSpacing(2)
                    
                    Text(missItem.content)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .tracking(0.2)
                        .lineSpacing(3)
                }
                
                Spacer()
                
                Button(action: {
                    missItem.toggleResolved()
                }) {
                    Image(systemName: missItem.isResolved ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(missItem.isResolved ? .green : .gray)
                        .font(.title2)
                }
            }
            
            HStack {
                if let imageData = missItem.imageData {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(imageData.tagType.displayName)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .tracking(0.2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Text(DateFormatter.localizedString(from: missItem.createdAt, dateStyle: .short, timeStyle: .none))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .tracking(0.2)
            }
        }
        .padding(.vertical, 8)
        .opacity(missItem.isResolved ? 0.7 : 1.0)
    }
}

struct MissListEmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("ミスリストがありません")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("右上の + ボタンからミスを記録してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct AddMissListItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var images: [ImageData]
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImage: ImageData?
    
    var body: some View {
        NavigationView {
            Form {
                Section("ミスの内容") {
                    TextField("タイトル", text: $title)
                    TextField("詳細説明", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("関連する画像（任意）") {
                    Picker("画像を選択", selection: $selectedImage) {
                        Text("選択なし").tag(ImageData?.none)
                        ForEach(images, id: \.id) { image in
                            HStack {
                                Text(image.tagType.displayName)
                                if let taskName = image.taskName {
                                    Text("- \(taskName.name)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(image as ImageData?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("新しいミス記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveMissItem()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
    }
    
    private func saveMissItem() {
        let missItem = MissListItem(title: title, content: content, imageData: selectedImage)
        modelContext.insert(missItem)
        dismiss()
    }
}

struct MissListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let missItem: MissListItem
    @State private var showingEditView = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ステータス表示
                HStack {
                    Image(systemName: missItem.isResolved ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(missItem.isResolved ? .green : .gray)
                        .font(.title2)
                    
                    Text(missItem.isResolved ? "解決済み" : "未解決")
                        .font(.headline)
                        .foregroundColor(missItem.isResolved ? .green : .primary)
                    
                    Spacer()
                    
                    Button(action: {
                        missItem.toggleResolved()
                    }) {
                        Text(missItem.isResolved ? "未解決にする" : "解決済みにする")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(missItem.isResolved ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // 内容表示
                VStack(alignment: .leading, spacing: 12) {
                    Text("詳細")
                        .font(.headline)
                    
                    Text(missItem.content)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // 関連画像
                if let imageData = missItem.imageData {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("関連画像")
                            .font(.headline)
                        
                        NavigationLink(destination: ImageDetailView(imageData: imageData)) {
                            ImageGridItemView(imageData: imageData)
                                .frame(maxWidth: 200)
                        }
                    }
                }
                
                // 作成・更新日時
                VStack(alignment: .leading, spacing: 8) {
                    Text("作成日: \(DateFormatter.localizedString(from: missItem.createdAt, dateStyle: .medium, timeStyle: .short))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if missItem.updatedAt != missItem.createdAt {
                        Text("更新日: \(DateFormatter.localizedString(from: missItem.updatedAt, dateStyle: .medium, timeStyle: .short))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(missItem.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編集") {
                    showingEditView = true
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditMissListItemView(missItem: missItem)
        }
    }
}

struct EditMissListItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var images: [ImageData]
    
    let missItem: MissListItem
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedImage: ImageData?
    
    var body: some View {
        NavigationView {
            Form {
                Section("ミスの内容") {
                    TextField("タイトル", text: $title)
                    TextField("詳細説明", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("関連する画像（任意）") {
                    Picker("画像を選択", selection: $selectedImage) {
                        Text("選択なし").tag(ImageData?.none)
                        ForEach(images, id: \.id) { image in
                            HStack {
                                Text(image.tagType.displayName)
                                if let taskName = image.taskName {
                                    Text("- \(taskName.name)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(image as ImageData?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("ミス記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        updateMissItem()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
        .onAppear {
            title = missItem.title
            content = missItem.content
            selectedImage = missItem.imageData
        }
    }
    
    private func updateMissItem() {
        missItem.updateContent(title: title, content: content)
        missItem.imageData = selectedImage
        dismiss()
    }
}
