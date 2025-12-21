//
//  PHPickerResultHandler.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/21.
//

import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct PHPickerResultHandler {

    /// PHPickerResultから元のフォーマットで画像データを抽出
    /// 返り値: (originalData, format, uiImage)
    static func extractImageData(from result: PHPickerResult) async -> (Data, ImageFormat, UIImage)? {
        let itemProvider = result.itemProvider

        // 優先順位: HEIC → PNG → GIF → JPEG

        // 1. HEIC（iPhoneカメラのデフォルト形式）
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.heic.identifier) {
            if let data = await loadFileRepresentation(from: itemProvider, typeIdentifier: UTType.heic.identifier),
               let image = UIImage(data: data) {
                print("✅ PHPicker: Loaded HEIC (\(data.count) bytes)")
                return (data, .heic, image)
            }
        }

        // 2. PNG
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
            if let data = await loadFileRepresentation(from: itemProvider, typeIdentifier: UTType.png.identifier),
               let image = UIImage(data: data) {
                print("✅ PHPicker: Loaded PNG (\(data.count) bytes)")
                return (data, .png, image)
            }
        }

        // 3. GIF
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
            if let data = await loadFileRepresentation(from: itemProvider, typeIdentifier: UTType.gif.identifier),
               let image = UIImage(data: data) {
                print("✅ PHPicker: Loaded GIF (\(data.count) bytes)")
                return (data, .gif, image)
            }
        }

        // 4. JPEG（フォールバック）
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) {
            if let data = await loadFileRepresentation(from: itemProvider, typeIdentifier: UTType.jpeg.identifier),
               let image = UIImage(data: data) {
                print("✅ PHPicker: Loaded JPEG (\(data.count) bytes)")
                return (data, .jpeg, image)
            }
        }

        print("⚠️ PHPicker: 対応フォーマットが見つかりません")
        return nil
    }

    /// itemProviderからファイル表現を読み込む
    private static func loadFileRepresentation(from itemProvider: NSItemProvider, typeIdentifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error = error {
                    print("❌ loadFileRepresentation error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let url = url else {
                    continuation.resume(returning: nil)
                    return
                }

                // 一時ファイルからデータを即座に読み込む
                let data = try? Data(contentsOf: url)
                continuation.resume(returning: data)
            }
        }
    }
}
