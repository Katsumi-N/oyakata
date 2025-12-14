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
    func generateSizes(from image: UIImage) async -> [ImageSize: Data]
}

final class ImageSizeGenerator: ImageSizeGeneratorProtocol {
    func generateSizes(from image: UIImage) async -> [ImageSize: Data] {
        await withTaskGroup(of: (ImageSize, Data?).self) { group in
            var result: [ImageSize: Data] = [:]

            for size in ImageSize.allCases {
                group.addTask {
                    let resized = await self.resize(image, to: size.maxDimension)
                    let data = resized.jpegData(compressionQuality: self.compressionQuality(for: size))
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

    private func compressionQuality(for size: ImageSize) -> CGFloat {
        switch size {
        case .thumbnail: return 0.7
        case .medium: return 0.8
        case .large: return 0.85
        }
    }
}
