//
//  ImagePickerView.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ImagePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedTag: TagType = .questionPaper
    @State private var selectedTaskName: TaskName?
    @State private var newTaskName: String = ""
    @State private var showingTaskNameInput = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @Query private var taskNames: [TaskName]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // タグ選択セクション
                    VStack(alignment: .leading, spacing: 12) {
                        Text("タグを選択")
                            .font(.headline)
                            .tracking(0.3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 3 : 2), spacing: 12) {
                            ForEach(TagType.allCases, id: \.self) { tag in
                                Button(action: {
                                    selectedTag = tag
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: tag.systemImage)
                                            .font(.caption)
                                        Text(tag.displayName)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .tracking(0.2)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(selectedTag == tag ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedTag == tag ? .white : .primary)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                
                    // 課題名選択セクション
                    VStack(alignment: .leading, spacing: 12) {
                        Text("課題名を選択（任意）")
                            .font(.headline)
                            .tracking(0.3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            Picker("課題名", selection: $selectedTaskName) {
                                Text("選択なし").tag(TaskName?.none)
                                ForEach(taskNames, id: \.self) { taskName in
                                    Text(taskName.name).tag(taskName as TaskName?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            
                            Button("新規課題を作成") {
                                showingTaskNameInput = true
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // 画像選択セクション
                    VStack(spacing: 16) {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            Label("画像を選択", systemImage: "photo.on.rectangle")
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        if !selectedItems.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(selectedItems.count)枚の画像が選択されています")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 20)
                .padding(.vertical, horizontalSizeClass == .regular ? 24 : 16)
            }
            .navigationTitle("画像を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveImages()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
        }
        .alert("新しい課題名", isPresented: $showingTaskNameInput) {
            TextField("課題名を入力", text: $newTaskName)
            Button("キャンセル", role: .cancel) {
                newTaskName = ""
            }
            Button("作成") {
                createNewTaskName()
            }
        }
    }
    
    private func createNewTaskName() {
        let taskName = TaskName(name: newTaskName)
        modelContext.insert(taskName)
        selectedTaskName = taskName
        newTaskName = ""
    }
    
    private func saveImages() {
        Task {
            let groupId = selectedItems.count > 1 ? UUID() : nil
            let groupCreatedAt = selectedItems.count > 1 ? Date() : nil
            
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await saveImageToDocuments(uiImage, groupId: groupId, groupCreatedAt: groupCreatedAt)
                }
            }
            
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func saveImageToDocuments(_ image: UIImage, groupId: UUID? = nil, groupCreatedAt: Date? = nil) async {
        // 画像をメモリ効率的にリサイズ
        let optimizedImage = await optimizeImage(image)
        guard let imageData = optimizedImage.jpegData(compressionQuality: 0.7) else { return }
        
        let fileName = "\(UUID().uuidString).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            
            await MainActor.run {
                let imageDataModel = ImageData(
                    fileName: fileName,
                    filePath: fileName,
                    tagType: selectedTag,
                    taskName: selectedTaskName,
                    groupId: groupId,
                    groupCreatedAt: groupCreatedAt
                )
                modelContext.insert(imageDataModel)
            }
        } catch {
            print("画像の保存に失敗しました: \(error)")
        }
    }
    
    private func optimizeImage(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let maxDimension: CGFloat = 2048
                let size = image.size
                
                // リサイズが不要な場合はそのまま返す
                if max(size.width, size.height) <= maxDimension {
                    continuation.resume(returning: image)
                    return
                }
                
                // アスペクト比を保持してリサイズ
                let aspectRatio = size.width / size.height
                let newSize: CGSize
                
                if size.width > size.height {
                    newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
                } else {
                    newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
                }
                
                // メモリ効率的なリサイズ
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resizedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }
                
                continuation.resume(returning: resizedImage)
            }
        }
    }
}