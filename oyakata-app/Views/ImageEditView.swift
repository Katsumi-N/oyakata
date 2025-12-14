//
//  ImageEditView.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import SwiftUI
import PencilKit
import SwiftData

struct ImageEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let imageData: ImageData
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var showingSaveAlert = false
    @State private var optimizedImage: UIImage?
    
    var body: some View {
        VStack {
            if let image = optimizedImage {
                DrawingCanvasView(
                    canvasView: $canvasView,
                    toolPicker: $toolPicker,
                    backgroundImage: image
                )
            } else {
                ProgressView("画像を読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("画像編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    showingSaveAlert = true
                }
            }
        }
        .alert("編集内容を保存", isPresented: $showingSaveAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                saveEditedImage()
            }
        } message: {
            Text("編集内容を保存しますか？")
        }
        .task {
            await loadOptimizedImage()
        }
    }
    
    private func saveEditedImage() {
        Task {
            await performSave()
        }
    }
    
    private func loadOptimizedImage() async {
        // Apple Pencil編集用にlargeサイズ（2048px）をCDNから取得
        let storageStrategy = ServiceLocator.shared.imageStorageStrategy

        do {
            if let largeImage = try await storageStrategy.getImage(for: imageData, size: .large) {
                optimizedImage = largeImage
                return
            }
        } catch {
            print("CDNから画像取得失敗: \(error)")
        }

        // フォールバック: ローカル画像を使用（既存データの場合）
        guard let originalImage = imageData.image else { return }

        let optimized = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let maxDimension: CGFloat = 2048 // largeサイズと同じ
                let size = originalImage.size

                if max(size.width, size.height) <= maxDimension {
                    continuation.resume(returning: originalImage)
                    return
                }
                
                let aspectRatio = size.width / size.height
                let newSize: CGSize
                
                if size.width > size.height {
                    newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
                } else {
                    newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
                }
                
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resizedImage = renderer.image { _ in
                    originalImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
                
                continuation.resume(returning: resizedImage)
            }
        }
        
        await MainActor.run {
            self.optimizedImage = optimized
        }
    }
    
    @MainActor
    private func performSave() async {
        guard let originalImage = imageData.image,
              let displayImage = optimizedImage else { return }
        
        // 背景で画像合成を実行
        let editedImage = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // キャンバスの描画内容を取得
                let drawing = self.canvasView.drawing
                let canvasSize = self.canvasView.bounds.size
                let displaySize = displayImage.size
                let originalSize = originalImage.size
                
                // キャンバスサイズでの描画を取得（contentSize = canvasSize）
                let drawingImage = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: 1.0)
                
                // 背景画像の表示領域を計算（scaleAspectFit）
                let imageAspectRatio = displaySize.width / displaySize.height
                let canvasAspectRatio = canvasSize.width / canvasSize.height
                
                let scale: CGFloat
                let scaledImageSize: CGSize
                let offsetX: CGFloat
                let offsetY: CGFloat
                
                if imageAspectRatio > canvasAspectRatio {
                    // 画像の方が横長
                    scale = canvasSize.width / displaySize.width
                    scaledImageSize = CGSize(width: canvasSize.width, height: displaySize.height * scale)
                    offsetX = 0
                    offsetY = (canvasSize.height - scaledImageSize.height) / 2
                } else {
                    // 画像の方が縦長
                    scale = canvasSize.height / displaySize.height
                    scaledImageSize = CGSize(width: displaySize.width * scale, height: canvasSize.height)
                    offsetX = (canvasSize.width - scaledImageSize.width) / 2
                    offsetY = 0
                }
                
                // 元画像サイズで合成
                let renderer = UIGraphicsImageRenderer(size: originalSize)
                let result = renderer.image { context in
                    // 元の画像を描画
                    originalImage.draw(in: CGRect(origin: .zero, size: originalSize))
                    
                    // 描画エリアを切り出して元画像サイズにスケール
                    let drawingRect = CGRect(x: offsetX, y: offsetY, width: scaledImageSize.width, height: scaledImageSize.height)
                    
                    if let croppedDrawing = drawingImage.cgImage?.cropping(to: drawingRect) {
                        let croppedUIImage = UIImage(cgImage: croppedDrawing)
                        croppedUIImage.draw(in: CGRect(origin: .zero, size: originalSize))
                    }
                }
                continuation.resume(returning: result)
            }
        }
        
        // 編集済み画像を保存（圧縮強化）
        guard let processedImageData = editedImage.jpegData(compressionQuality: 0.6) else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(self.imageData.filePath)
        
        do {
            try processedImageData.write(to: fileURL)
            
            // データベースの情報を更新
            self.imageData.updateAnnotationStatus(true)
            
            dismiss()
        } catch {
            print("編集済み画像の保存に失敗しました: \(error)")
        }
    }
}

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    let backgroundImage: UIImage
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemBackground
        
        // 背景画像ビューを作成
        let imageView = UIImageView(image: backgroundImage)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.systemBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        
        // PKCanvasViewを設定
        canvasView.backgroundColor = UIColor.clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.isScrollEnabled = false  // スクロールを無効化
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        
        // コンテナビューに追加（背景画像が下、キャンバスが上）
        containerView.addSubview(imageView)
        containerView.addSubview(canvasView)
        
        // 制約を設定
        NSLayoutConstraint.activate([
            // 画像ビューの制約（コンテナ全体に配置）
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // キャンバスビューの制約（コンテナ全体に配置）
            canvasView.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        // ツールピッカーを設定
        setupToolPicker()
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // レイアウト更新時にキャンバスのコンテンツスケールを調整
        DispatchQueue.main.async {
            if self.canvasView.bounds != .zero {
                self.adjustCanvasScale()
            }
        }
    }
    
    private func setupToolPicker() {
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        
        DispatchQueue.main.async {
            self.canvasView.becomeFirstResponder()
        }
    }
    
    private func adjustCanvasScale() {
        guard canvasView.bounds.width > 0 && canvasView.bounds.height > 0 else { return }
        
        let imageSize = backgroundImage.size
        let canvasSize = canvasView.bounds.size
        
        // シンプルなアプローチ: キャンバスのコンテンツサイズをキャンバスサイズと同じにする
        canvasView.contentSize = canvasSize
        
        // 変換行列をリセット（アイデンティティ行列にする）
        canvasView.transform = CGAffineTransform.identity
        
        // この設定により、描画座標とキャンバス座標が1:1で対応し、
        // 背景画像の表示位置と描画位置が正確に一致する
    }
}