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
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = imageData.image {
                    DrawingCanvasView(
                        canvasView: $canvasView,
                        toolPicker: $toolPicker,
                        backgroundImage: image
                    )
                } else {
                    Text("画像を読み込めません")
                        .foregroundColor(.secondary)
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
        }
        .alert("編集内容を保存", isPresented: $showingSaveAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                saveEditedImage()
            }
        } message: {
            Text("編集内容を保存しますか？")
        }
    }
    
    private func saveEditedImage() {
        guard let originalImage = imageData.image else { return }
        
        // キャンバスの描画内容を画像に合成
        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        let editedImage = renderer.image { context in
            // 元の画像を描画
            originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
            
            // PencilKitの描画内容を合成
            let drawing = canvasView.drawing
            drawing.image(from: CGRect(origin: .zero, size: originalImage.size), scale: 1.0).draw(in: CGRect(origin: .zero, size: originalImage.size))
        }
        
        // 編集済み画像を保存
        guard let imageData = editedImage.jpegData(compressionQuality: 0.8) else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(self.imageData.filePath)
        
        do {
            try imageData.write(to: fileURL)
            
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
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = UIColor.systemBackground
        canvasView.isOpaque = false
        canvasView.allowsFingerDrawing = true
        
        // 背景画像を設定
        setupBackgroundImage()
        
        // ツールピッカーを表示
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 必要に応じて更新処理を追加
    }
    
    private func setupBackgroundImage() {
        // 背景画像をキャンバスのサイズに合わせて調整
        let imageView = UIImageView(image: backgroundImage)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = canvasView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        canvasView.subviews.forEach { $0.removeFromSuperview() }
        canvasView.insertSubview(imageView, at: 0)
    }
}