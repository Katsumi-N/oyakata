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
    @State private var selectedTag: TagType = .questionPaper
    @State private var selectedTaskName: TaskName?
    @State private var newTaskName: String = ""
    @State private var showingTaskNameInput = false
    @State private var showingDocumentPicker = false
    @State private var selectedDocuments: [URL] = []
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
                    .disabled(selectedItems.isEmpty && selectedDocuments.isEmpty)
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
    
    private func createNewTaskName() {
        let taskName = TaskName(name: newTaskName)
        modelContext.insert(taskName)
        selectedTaskName = taskName
        newTaskName = ""
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