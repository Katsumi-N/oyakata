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
    @Query private var taskNames: [TaskName]
    
    @State private var showingAddView = false
    @State private var searchText = ""
    @State private var showResolved = true
    @State private var selectedTaskName: TaskName?
    
    // 利用可能な課題名を取得（ミスリストに関連する画像がある課題のみ）
    var availableTaskNames: [TaskName] {
        let taskNamesWithMiss = Set(missListItems.compactMap { $0.imageData?.taskName })
        return taskNames.filter { taskNamesWithMiss.contains($0) }.sorted { $0.name < $1.name }
    }
    
    var filteredItems: [MissListItem] {
        var filtered = missListItems
        
        if !showResolved {
            filtered = filtered.filter { !$0.isResolved }
        }
        
        if let selectedTask = selectedTaskName {
            filtered = filtered.filter { item in
                item.imageData?.taskName == selectedTask
            }
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
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("ミスを検索...", text: $searchText)
                        .font(.system(size: 16))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                
                // 課題名フィルター
                if !availableTaskNames.isEmpty {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                        
                        Picker("課題名でフィルタ", selection: $selectedTaskName) {
                            Text("全ての課題").tag(TaskName?.none)
                            ForEach(availableTaskNames, id: \.id) { taskName in
                                Text(taskName.name).tag(taskName as TaskName?)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 16))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
                
                HStack {
                    Toggle("解決済みを表示", isOn: $showResolved)
                        .font(.system(size: 16))
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            // ミスリスト表示
            if filteredItems.isEmpty {
                MissListEmptyView(hasFilters: selectedTaskName != nil || !searchText.isEmpty)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredItems, id: \.id) { item in
                        NavigationLink(destination: EditMissListItemView(missItem: item)) {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddView = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
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
                        Text(imageData.tags.map { $0.displayName }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .tracking(0.2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.15))
                    .clipShape(Capsule())
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
    let hasFilters: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            if hasFilters {
                Text("条件に一致するミスリストがありません")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Text("フィルター条件を変更するか、検索キーワードをクリアしてください")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("ミスリストがありません")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Text("右上の + ボタンからミスを記録してください")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct AddMissListItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ImageData.createdAt, order: .reverse) private var images: [ImageData]
    
    @State private var title = ""
    @State private var content = ""
    
    // 最新の画像を自動選択
    private var autoSelectedImage: ImageData? {
        return images.first
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("ミスの内容") {
                    TextField("タイトル", text: $title)
                    TextField("詳細説明", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // 自動選択された画像がある場合は表示（選択不可）
                if let imageData = autoSelectedImage {
                    Section("関連する画像（最新の画像を自動選択）") {
                        HStack {
                            if let image = imageData.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(imageData.tags.map { $0.displayName }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let taskName = imageData.taskName {
                                    Text(taskName.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("作成日: \(DateFormatter.localizedString(from: imageData.createdAt, dateStyle: .short, timeStyle: .short))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
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
        let missItem = MissListItem(title: title, content: content, imageData: autoSelectedImage)
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(missItem.isResolved ? .orange : .green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
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
    
    let missItem: MissListItem
    @State private var title: String = ""
    @State private var content: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("ミスの内容") {
                    TextField("タイトル", text: $title)
                    TextField("詳細説明", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // 関連する画像がある場合は表示（編集不可）
                if let imageData = missItem.imageData {
                    Section("関連する画像") {
                        HStack {
                            if let image = imageData.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(imageData.tags.map { $0.displayName }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let taskName = imageData.taskName {
                                    Text(taskName.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
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
        }
    }
    
    private func updateMissItem() {
        missItem.updateContent(title: title, content: content)
        // 画像の関連付けは変更しない（元の関連付けを維持）
        dismiss()
    }
}
