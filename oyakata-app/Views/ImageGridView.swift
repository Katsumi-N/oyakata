//
//  ImageGridView.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import SwiftUI
import SwiftData

struct ImageGroup: Identifiable {
    let id: String
    let images: [ImageData]
    let groupId: UUID?
    let groupCreatedAt: Date
    
    var representativeImage: ImageData {
        return images.first!
    }
}

struct ImageGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Query private var images: [ImageData]
    
    @State private var showingImagePicker = false
    @State private var selectedTag: TagType?
    @State private var selectedTask: TaskName?
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var groupToDelete: ImageGroup?
    @State private var imageToDelete: ImageData?
    
    var columns: [GridItem] {
        let spacing: CGFloat = 12
        
        // サイズクラスに基づいて固定サイズのレイアウトを決定
        switch (horizontalSizeClass, verticalSizeClass) {
        case (.compact, .regular):
            // iPhone縦向き - 2列
            return Array(repeating: GridItem(.flexible(minimum: 160, maximum: 200), spacing: spacing), count: 2)
        case (.compact, .compact):
            // iPhone横向き - 3列
            return Array(repeating: GridItem(.flexible(minimum: 160, maximum: 200), spacing: spacing), count: 3)
        case (.regular, .regular):
            // iPad縦向き - 3列
            return Array(repeating: GridItem(.flexible(minimum: 200, maximum: 300), spacing: spacing), count: 3)
        case (.regular, .compact):
            // iPad横向き - 4列
            return Array(repeating: GridItem(.flexible(minimum: 240, maximum: 300), spacing: spacing), count: 4)
        default:
            // デフォルト - 2列
            return Array(repeating: GridItem(.flexible(minimum: 160, maximum: 200), spacing: spacing), count: 2)
        }
    }
    
    var groupedImages: [ImageGroup] {
        var filtered = images
        
        if let tag = selectedTag {
            filtered = filtered.filter { $0.tags.contains(tag) }
        }
        
        if let task = selectedTask {
            filtered = filtered.filter { $0.taskName == task }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { imageData in
                imageData.taskName?.name.localizedCaseInsensitiveContains(searchText) ?? false ||
                imageData.tags.contains { $0.displayName.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        let sortedImages = filtered.sorted { $0.createdAt > $1.createdAt }
        
        var groups: [String: [ImageData]] = [:]
        
        for image in sortedImages {
            if let groupId = image.groupId {
                let key = groupId.uuidString
                if groups[key] == nil {
                    groups[key] = []
                }
                groups[key]?.append(image)
            } else {
                let key = "single_\(image.id.uuidString)"
                groups[key] = [image]
            }
        }
        
        return groups.compactMap { (key, images) in
            guard let firstImage = images.first else { return nil }
            return ImageGroup(
                id: key,
                images: images.sorted { $0.createdAt < $1.createdAt },
                groupId: firstImage.groupId,
                groupCreatedAt: firstImage.groupCreatedAt ?? firstImage.createdAt
            )
        }.sorted { $0.groupCreatedAt > $1.groupCreatedAt }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                    // 検索バー
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // フィルターセクション
                    FilterSection(selectedTag: $selectedTag, selectedTask: $selectedTask)
                        .padding(.horizontal, 16)
                    
                    // 画像グリッド
                    if groupedImages.isEmpty {
                        EmptyStateView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(groupedImages) { group in
                                    NavigationLink(destination: GroupDetailView(group: group)) {
                                        GroupGridItemView(group: group)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteGroup(group)
                                        } label: {
                                            Label("図面を削除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("図面一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView()
        }
        .alert("削除の確認", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) {
                groupToDelete = nil
                imageToDelete = nil
            }
            Button("削除", role: .destructive) {
                if let group = groupToDelete {
                    performDeleteGroup(group)
                } else if let image = imageToDelete {
                    performDeleteImage(image)
                }
                groupToDelete = nil
                imageToDelete = nil
            }
        } message: {
            if let group = groupToDelete {
                Text("このグループ（\(group.images.count)枚の画像）を削除しますか？この操作は元に戻せません。")
            } else if let _ = imageToDelete {
                Text("この画像を削除しますか？この操作は元に戻せません。")
            }
        }
    }
    
    private func deleteGroup(_ group: ImageGroup) {
        groupToDelete = group
        showingDeleteAlert = true
    }
    
    private func deleteImage(_ image: ImageData) {
        imageToDelete = image
        showingDeleteAlert = true
    }
    
    private func performDeleteGroup(_ group: ImageGroup) {
        do {
            for imageData in group.images {
                deleteImageFile(imageData)
                modelContext.delete(imageData)
            }
            try modelContext.save()
        } catch {
            print("グループ削除エラー: \(error)")
        }
    }
    
    private func performDeleteImage(_ imageData: ImageData) {
        do {
            deleteImageFile(imageData)
            modelContext.delete(imageData)
            try modelContext.save()
        } catch {
            print("画像削除エラー: \(error)")
        }
    }
    
    private func deleteImageFile(_ imageData: ImageData) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsPath.appendingPathComponent(imageData.filePath)
        
        do {
            if FileManager.default.fileExists(atPath: imageURL.path) {
                try FileManager.default.removeItem(at: imageURL)
            }
        } catch {
            print("ファイル削除エラー: \(error)")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
            
            TextField("画像を検索...", text: $text)
                .font(.system(size: 16))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
        .padding(.horizontal, 4)
    }
}

struct FilterSection: View {
    @Binding var selectedTag: TagType?
    @Binding var selectedTask: TaskName?
    @Query private var taskNames: [TaskName]
    
    var body: some View {
        VStack(spacing: 10) {
            // タグフィルター
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "すべて", isSelected: selectedTag == nil) {
                        selectedTag = nil
                    }
                    
                    ForEach(TagType.allCases, id: \.self) { tag in
                        FilterChip(title: tag.displayName, isSelected: selectedTag == tag) {
                            selectedTag = selectedTag == tag ? nil : tag
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ImageGridItemView: View {
    let imageData: ImageData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 画像
            if let image = imageData.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 140)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            
            // メタデータ
            VStack(alignment: .leading, spacing: 6) {
                if !imageData.tags.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(imageData.tags.map { $0.displayName }.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                            .tracking(0.3)
                    }
                }
                
                if let taskName = imageData.taskName {
                    Text(taskName.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .tracking(0.2)
                        .lineSpacing(2)
                }
                
                if imageData.hasAnnotations {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("編集済み")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .tracking(0.2)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct GroupGridItemView: View {
    let group: ImageGroup
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 画像スタック
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                        )
                }
                
                // 重なり効果（複数画像の場合のみ）
                if group.images.count > 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .cornerRadius(8)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                                .cornerRadius(8)
                                .offset(x: -3, y: -3)
                        )
                        .offset(x: 3, y: 3)
                }
                
                // 枚数バッジ（最前面に配置）
                if group.images.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(group.images.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(12)
                                .padding(8)
                        }
                        Spacer()
                    }
                    .zIndex(1)
                }
            }
            .task {
                await loadThumbnail()
            }

            // メタデータ（「グループ」表示なし）
            VStack(alignment: .leading, spacing: 6) {
                if !group.representativeImage.tags.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(group.representativeImage.tags.map { $0.displayName }.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                            .tracking(0.3)
                    }
                }
                
                if let taskName = group.representativeImage.taskName {
                    Text(taskName.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .tracking(0.2)
                        .lineSpacing(2)
                }
                
                if group.representativeImage.hasAnnotations {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("編集済み")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .tracking(0.2)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func loadThumbnail() async {
        let storageStrategy = ServiceLocator.shared.imageStorageStrategy
        thumbnail = try? await storageStrategy.getImage(for: group.representativeImage, size: .thumbnail)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("画像がありません")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("右上の + ボタンから画像を追加してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
