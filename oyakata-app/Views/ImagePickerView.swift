//
//  ImagePickerView.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit

struct ImagePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedTags: Set<TagType> = []
    @State private var taskNameInput: String = ""
    @State private var showingDocumentPicker = false
    @State private var selectedDocuments: [URL] = []
    
    @Query private var taskNames: [TaskName]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // タグ選択セクション
                    VStack(alignment: .leading, spacing: 12) {
                        Text("タグを選択（複数選択可）")
                            .font(.headline)
                            .tracking(0.3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(TagType.allCases, id: \.self) { tag in
                                Button(action: {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
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
                                    .background(selectedTags.contains(tag) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                
                    // 課題名入力セクション
                    VStack(alignment: .leading, spacing: 12) {
                        Text("課題名を入力（必須）")
                            .font(.headline)
                            .tracking(0.3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("課題名を入力してください", text: $taskNameInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    
                    // 画像選択セクション
                    VStack(spacing: 16) {
                        Text("画像を選択")
                            .font(.headline)
                            .tracking(0.3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: 10,
                                matching: .images
                            ) {
                                Label("フォトライブラリから選択", systemImage: "photo.on.rectangle")
                                    .font(.body)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button("ファイルから選択（画像・PDF）") {
                                showingDocumentPicker = true
                            }
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        let totalSelected = selectedItems.count + selectedDocuments.count
                        if totalSelected > 0 {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(totalSelected)枚の画像が選択されています")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
                    .disabled(selectedItems.isEmpty && selectedDocuments.isEmpty || taskNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            handleDocumentPickerResult(result)
        }
    }
    
    private func handleDocumentPickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedDocuments = urls
        case .failure(let error):
            print("ファイル選択エラー: \(error)")
        }
    }
    
    private func getOrCreateTaskName() -> TaskName {
        let trimmedName = taskNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 既存の課題名をチェック
        if let existingTaskName = taskNames.first(where: { $0.name == trimmedName }) {
            // 既存の課題名が見つかった場合はそれを使用
            return existingTaskName
        } else {
            // 新しい課題名を作成
            let taskName = TaskName(name: trimmedName)
            modelContext.insert(taskName)
            return taskName
        }
    }
    
    private func saveImages() {
        Task {
            let totalCount = selectedItems.count + selectedDocuments.count
            let groupId = totalCount > 1 ? UUID() : nil
            let groupCreatedAt = totalCount > 1 ? Date() : nil
            
            // PhotosPickerの画像を処理
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await saveImageToDocuments(uiImage, groupId: groupId, groupCreatedAt: groupCreatedAt)
                }
            }
            
            // DocumentPickerの画像・PDFを処理
            for documentURL in selectedDocuments {
                if documentURL.startAccessingSecurityScopedResource() {
                    defer { documentURL.stopAccessingSecurityScopedResource() }
                    
                    do {
                        if documentURL.pathExtension.lowercased() == "pdf" {
                            // PDFを画像に変換
                            if let uiImage = await convertPDFToImage(url: documentURL) {
                                await saveImageToDocuments(uiImage, groupId: groupId, groupCreatedAt: groupCreatedAt)
                            }
                        } else {
                            // 通常の画像ファイル
                            let data = try Data(contentsOf: documentURL)
                            if let uiImage = UIImage(data: data) {
                                await saveImageToDocuments(uiImage, groupId: groupId, groupCreatedAt: groupCreatedAt)
                            }
                        }
                    } catch {
                        print("ファイル読み込みエラー: \(error)")
                    }
                }
            }
            
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func saveImageToDocuments(_ image: UIImage, groupId: UUID? = nil, groupCreatedAt: Date? = nil) async {
        // 画像をメモリ効率的にリサイズ（元画像用）
        let optimizedImage = await optimizeImage(image)

        let fileName = "\(UUID().uuidString).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            // ImageDataモデルを先に作成
            let imageDataModel = await MainActor.run { () -> ImageData in
                let taskName = getOrCreateTaskName()
                let imageDataModel = ImageData(
                    fileName: fileName,
                    filePath: fileName,
                    tags: Array(selectedTags),
                    taskName: taskName,
                    groupId: groupId,
                    groupCreatedAt: groupCreatedAt
                )
                modelContext.insert(imageDataModel)
                return imageDataModel
            }

            // バックグラウンドでアップロードと画像生成
            Task.detached {
                do {
                    let uploadManager = ServiceLocator.shared.imageUploadManager
                    let cacheManager = ServiceLocator.shared.imageCacheManager

                    // ImageUploadManagerで3サイズ生成・保存・アップロード
                    try await uploadManager.uploadImage(imageDataModel, image: optimizedImage)

                    // thumbnail (300px)をfilePathにも保存（後方互換性のため）
                    if let thumbnailData = try? await cacheManager.loadThumbnail(for: imageDataModel.id),
                       let jpegData = thumbnailData.jpegData(compressionQuality: 0.7) {
                        try? jpegData.write(to: fileURL)
                    }
                } catch {
                    print("画像のアップロードに失敗しました: \(error)")
                    // エラー時はローカルにフルサイズを保存（フォールバック）
                    if let fallbackData = optimizedImage.jpegData(compressionQuality: 0.7) {
                        try? fallbackData.write(to: fileURL)
                    }
                }
            }
        } catch {
            print("画像の保存に失敗しました: \(error)")
        }
    }
    
    private func convertPDFToImage(url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let pdfDocument = PDFDocument(url: url),
                      let firstPage = pdfDocument.page(at: 0) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let pageRect = firstPage.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                
                let image = renderer.image { context in
                    UIColor.white.set()
                    context.fill(pageRect)
                    
                    context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                    context.cgContext.scaleBy(x: 1.0, y: -1.0)
                    
                    firstPage.draw(with: .mediaBox, to: context.cgContext)
                }
                
                continuation.resume(returning: image)
            }
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