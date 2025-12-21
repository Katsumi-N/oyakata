//
//  ImageSizeGenerator.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import UIKit

enum ImageSize: String, Codable, CaseIterable {
    case thumbnail = "thumbnail"
    case medium = "medium"
    case large = "large"

    var maxDimension: CGFloat {
        switch self {
        case .thumbnail: return 300
        case .medium: return 1024
        case .large: return 2048
        }
    }

    var fileName: String {
        return self.rawValue
    }
}

protocol ImageSizeGeneratorProtocol {
    func generateSizes(from image: UIImage, preserveFormat: ImageFormat) async -> [ImageSize: Data]
    func generateSizes(from image: UIImage, preserveFormat: ImageFormat, originalData: Data?) async -> [ImageSize: Data]
}

final class ImageSizeGenerator: ImageSizeGeneratorProtocol {
    func generateSizes(from image: UIImage, preserveFormat: ImageFormat) async -> [ImageSize: Data] {
        await generateSizes(from: image, preserveFormat: preserveFormat, originalData: nil)
    }

    func generateSizes(from image: UIImage, preserveFormat: ImageFormat, originalData: Data?) async -> [ImageSize: Data] {
        await withTaskGroup(of: (ImageSize, Data?).self) { group in
            var result: [ImageSize: Data] = [:]

            for size in ImageSize.allCases {
                group.addTask {
                    // Largeサイズで元データがある場合は、リサイズせずに元データをそのまま使用
                    if size == .large, let originalData = originalData {
                        print("✅ Large: 元の画像データをそのまま使用（\(originalData.count) bytes）")
                        return (size, originalData)
                    }

                    // Thumbnail/Mediumはリサイズして生成
                    let resized = await self.resize(image, to: size.maxDimension)

                    // Largeサイズのみ元の形式を保持、Thumbnail/MediumはJPEG
                    let format: ImageFormat = (size == .large) ? preserveFormat : .jpeg
                    let quality = self.compressionQuality(for: size, format: format)
                    let data = ImageFormatHandler.encode(resized, as: format, quality: quality)

                    if let data = data {
                        print("📦 \(size.rawValue) (\(format.mimeType)): \(data.count) bytes (quality: \(quality))")
                    }

                    return (size, data)
                }
            }

            for await (size, data) in group {
                if let data = data {
                    result[size] = data
                }
            }

            return result
        }
    }

    private func resize(_ image: UIImage, to maxDimension: CGFloat) async -> UIImage {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let size = image.size

                // 実際のピクセルサイズを計算（scale考慮）
                let actualWidth = size.width * image.scale
                let actualHeight = size.height * image.scale

                // リサイズが不要な場合はそのまま返す
                if max(actualWidth, actualHeight) <= maxDimension {
                    continuation.resume(returning: image)
                    return
                }

                // アスペクト比を保持してリサイズ
                let aspectRatio = actualWidth / actualHeight
                let newSize: CGSize

                if actualWidth > actualHeight {
                    newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
                } else {
                    newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
                }

                // メモリ効率的なリサイズ（scale = 1.0で作成）
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resizedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }

                continuation.resume(returning: resizedImage)
            }
        }
    }

    private func compressionQuality(for size: ImageSize, format: ImageFormat) -> CGFloat {
        switch size {
        case .thumbnail:
            return 0.6
        case .medium:
            return 0.7
        case .large:
            // HEICは高圧縮なので品質を下げる
            return format == .heic ? 0.6 : 0.8
        }
    }
}
