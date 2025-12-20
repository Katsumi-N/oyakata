//
//  ImageCacheManager.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import UIKit

protocol ImageCacheManagerProtocol {
    func saveThumbnail(_ data: Data, for imageId: UUID) async
    func loadThumbnail(for imageId: UUID) async -> UIImage?
    func saveImage(_ data: Data, imageId: String, size: ImageSize) async
    func loadImage(imageId: String, size: ImageSize) async -> UIImage?
    func clearCache() async
    func invalidateCache(for imageId: UUID) async
    func invalidateCache(for imageId: UUID, size: ImageSize) async
}

final class ImageCacheManager: ImageCacheManagerProtocol {
    private let fileManager = FileManager.default
    private let memoryCache = NSCache<NSString, UIImage>()

    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ImageCache")
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }

    private var thumbnailDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let thumbDir = paths[0].appendingPathComponent("Thumbnails")
        try? fileManager.createDirectory(at: thumbDir, withIntermediateDirectories: true)
        return thumbDir
    }

    func saveThumbnail(_ data: Data, for imageId: UUID) async {
        let url = thumbnailDirectory.appendingPathComponent("\(imageId.uuidString)_thumbnail.jpg")
        try? data.write(to: url)

        // メモリキャッシュにも保存
        if let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: imageId.uuidString as NSString)
        }
    }

    func loadThumbnail(for imageId: UUID) async -> UIImage? {
        // メモリキャッシュから取得
        if let cached = memoryCache.object(forKey: imageId.uuidString as NSString) {
            return cached
        }

        // ディスクから取得
        let url = thumbnailDirectory.appendingPathComponent("\(imageId.uuidString)_thumbnail.jpg")
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        // メモリキャッシュに保存
        memoryCache.setObject(image, forKey: imageId.uuidString as NSString)
        return image
    }

    func saveImage(_ data: Data, imageId: String, size: ImageSize) async {
        let url = cacheDirectory.appendingPathComponent("\(imageId)_\(size.rawValue).jpg")
        try? data.write(to: url)

        // メモリキャッシュにも保存
        if let image = UIImage(data: data) {
            let cacheKey = "\(imageId)_\(size.rawValue)" as NSString
            memoryCache.setObject(image, forKey: cacheKey)
        }
    }

    func loadImage(imageId: String, size: ImageSize) async -> UIImage? {
        let cacheKey = "\(imageId)_\(size.rawValue)" as NSString

        // メモリキャッシュから取得
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        // ディスクキャッシュから取得
        let diskPath = cacheDirectory.appendingPathComponent("\(imageId)_\(size.rawValue).jpg")
        guard let data = try? Data(contentsOf: diskPath),
              let image = UIImage(data: data) else {
            return nil
        }

        memoryCache.setObject(image, forKey: cacheKey)
        return image
    }

    func clearCache() async {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
    }

    func invalidateCache(for imageId: UUID) async {
        let imageIdString = imageId.uuidString

        // メモリキャッシュから削除
        memoryCache.removeObject(forKey: imageIdString as NSString) // thumbnail
        for size in ImageSize.allCases {
            let cacheKey = "\(imageIdString)_\(size.rawValue)" as NSString
            memoryCache.removeObject(forKey: cacheKey)
        }

        // ディスクキャッシュから削除
        // サムネイル
        let thumbnailURL = thumbnailDirectory.appendingPathComponent("\(imageIdString)_thumbnail.jpg")
        try? fileManager.removeItem(at: thumbnailURL)

        // その他のサイズ
        for size in ImageSize.allCases {
            let diskPath = cacheDirectory.appendingPathComponent("\(imageIdString)_\(size.rawValue).jpg")
            try? fileManager.removeItem(at: diskPath)
        }
    }

    func invalidateCache(for imageId: UUID, size: ImageSize) async {
        let imageIdString = imageId.uuidString
        let cacheKey = "\(imageIdString)_\(size.rawValue)" as NSString

        // メモリキャッシュから削除
        memoryCache.removeObject(forKey: cacheKey)

        // ディスクキャッシュから削除
        if size == .thumbnail {
            let url = thumbnailDirectory.appendingPathComponent("\(imageIdString)_thumbnail.jpg")
            try? fileManager.removeItem(at: url)
        } else {
            let diskPath = cacheDirectory.appendingPathComponent("\(imageIdString)_\(size.rawValue).jpg")
            try? fileManager.removeItem(at: diskPath)
        }
    }
}
