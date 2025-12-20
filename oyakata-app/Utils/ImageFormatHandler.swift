//
//  ImageFormatHandler.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/20.
//

import UIKit
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

enum ImageFormat {
    case heic
    case jpeg
    case png
    case gif
    case pdf
    case unknown

    var mimeType: String {
        switch self {
        case .heic: return "image/heic"
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        case .gif: return "image/gif"
        case .pdf: return "application/pdf"
        case .unknown: return "image/jpeg" // フォールバック
        }
    }

    var fileExtension: String {
        switch self {
        case .heic: return "heic"
        case .jpeg: return "jpg"
        case .png: return "png"
        case .gif: return "gif"
        case .pdf: return "pdf"
        case .unknown: return "jpg" // フォールバック
        }
    }

    var utType: UTType {
        switch self {
        case .heic: return .heic
        case .jpeg: return .jpeg
        case .png: return .png
        case .gif: return .gif
        case .pdf: return .pdf
        case .unknown: return .jpeg // フォールバック
        }
    }

    static func fromMimeType(_ mimeType: String) -> ImageFormat {
        switch mimeType.lowercased() {
        case "image/heic", "image/heif":
            return .heic
        case "image/jpeg", "image/jpg":
            return .jpeg
        case "image/png":
            return .png
        case "image/gif":
            return .gif
        case "application/pdf":
            return .pdf
        default:
            return .unknown
        }
    }
}

struct ImageFormatHandler {

    /// データのマジックバイトから画像フォーマットを検出
    static func detectFormat(from data: Data) -> ImageFormat {
        // CGImageSourceを使って正確なフォーマット検出
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(imageSource) else {
            print("⚠️ CGImageSource取得失敗、マジックバイトで検出します")
            return detectFormatFromMagicBytes(data)
        }

        let typeString = type as String
        print("🔍 検出されたUTType: \(typeString)")

        if typeString == UTType.heic.identifier || typeString == UTType.heif.identifier {
            print("✅ HEIC形式として検出")
            return .heic
        } else if typeString == UTType.jpeg.identifier {
            print("✅ JPEG形式として検出")
            return .jpeg
        } else if typeString == UTType.png.identifier {
            print("✅ PNG形式として検出")
            return .png
        } else if typeString == UTType.gif.identifier {
            print("✅ GIF形式として検出")
            return .gif
        }

        print("⚠️ 未知のフォーマット、マジックバイトで検出します")
        // フォールバック: マジックバイトで検出
        return detectFormatFromMagicBytes(data)
    }

    /// PhotosPickerItemから画像フォーマットを検出
    static func detectFormat(from item: PhotosPickerItem) -> ImageFormat {
        // supportedContentTypesから元の形式を優先的に検出
        // JPEGは変換形式なので最後にチェック
        print("📸 PhotosPickerItem: supportedContentTypes = \(item.supportedContentTypes.map { $0.identifier })")

        // HEICを優先的に検出（元の形式の可能性が高い）
        for type in item.supportedContentTypes {
            if type.conforms(to: .heic) || type.conforms(to: .heif) {
                print("✅ PhotosPickerItem: HEIC形式として検出")
                return .heic
            }
        }

        // PNG形式を検出
        for type in item.supportedContentTypes {
            if type.conforms(to: .png) {
                print("✅ PhotosPickerItem: PNG形式として検出")
                return .png
            }
        }

        // GIF形式を検出
        for type in item.supportedContentTypes {
            if type.conforms(to: .gif) {
                print("✅ PhotosPickerItem: GIF形式として検出")
                return .gif
            }
        }

        // JPEG形式を検出（フォールバック）
        for type in item.supportedContentTypes {
            if type.conforms(to: .jpeg) {
                print("✅ PhotosPickerItem: JPEG形式として検出（フォールバック）")
                return .jpeg
            }
        }

        print("⚠️ PhotosPickerItem: 未知のフォーマット、unknownを返します")
        return .unknown
    }

    /// URLから画像フォーマットを検出
    static func detectFormat(from url: URL) -> ImageFormat {
        // UTTypeから検出
        if let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
           let utType = UTType(typeIdentifier) {
            if utType.conforms(to: .heic) || utType.conforms(to: .heif) {
                return .heic
            } else if utType.conforms(to: .jpeg) {
                return .jpeg
            } else if utType.conforms(to: .png) {
                return .png
            } else if utType.conforms(to: .gif) {
                return .gif
            } else if utType.conforms(to: .pdf) {
                return .pdf
            }
        }

        // フォールバック: 拡張子から検出
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "heic", "heif":
            return .heic
        case "jpg", "jpeg":
            return .jpeg
        case "png":
            return .png
        case "gif":
            return .gif
        case "pdf":
            return .pdf
        default:
            return .unknown
        }
    }

    /// UIImageを指定されたフォーマットでエンコード
    static func encode(_ image: UIImage, as format: ImageFormat, quality: CGFloat) -> Data? {
        switch format {
        case .jpeg:
            return image.jpegData(compressionQuality: quality)

        case .png:
            return image.pngData()

        case .heic, .gif:
            // HEIC/GIFの場合はCGImageDestinationを使用
            return encodeUsingImageIO(image, format: format, quality: quality)
        case .unknown:
            // フォールバック: JPEG
            return image.jpegData(compressionQuality: quality)
        case .pdf:
            return image.jpegData(compressionQuality: quality)
        }
    }

    // MARK: - Private Helpers

    /// マジックバイトから画像フォーマットを検出（フォールバック用）
    private static func detectFormatFromMagicBytes(_ data: Data) -> ImageFormat {
        guard data.count >= 12 else { return .unknown }

        // JPEG: FF D8 FF
        if data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
            return .jpeg
        }

        // PNG: 89 50 4E 47
        if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
            return .png
        }

        // GIF: 47 49 46 38
        if data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x38 {
            return .gif
        }

        // HEIC: ftypheic または ftyphevc
        if data.count >= 12 {
            let ftypRange = 4..<8
            let ftyp = data.subdata(in: ftypRange)
            if let ftypString = String(data: ftyp, encoding: .ascii),
               ftypString == "ftyp" {
                let brandRange = 8..<12
                let brand = data.subdata(in: brandRange)
                if let brandString = String(data: brand, encoding: .ascii),
                   brandString.starts(with: "hei") || brandString.starts(with: "hev") {
                    return .heic
                }
            }
        }

        return .unknown
    }

    /// CGImageDestinationを使用した画像エンコード（HEIC/GIF用）
    private static func encodeUsingImageIO(_ image: UIImage, format: ImageFormat, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}
