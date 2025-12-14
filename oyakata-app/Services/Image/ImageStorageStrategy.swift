//
//  ImageStorageStrategy.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import UIKit

protocol ImageStorageStrategyProtocol {
    func getImage(for imageData: ImageData, size: ImageSize) async throws -> UIImage?
    func deleteRemoteImage(for imageData: ImageData) async throws
}

final class ImageStorageStrategy: ImageStorageStrategyProtocol {
    private let authManager: AuthManagerProtocol
    private let apiClient: APIClientProtocol
    private let cacheManager: ImageCacheManagerProtocol

    init(
        authManager: AuthManagerProtocol,
        apiClient: APIClientProtocol,
        cacheManager: ImageCacheManagerProtocol
    ) {
        self.authManager = authManager
        self.apiClient = apiClient
        self.cacheManager = cacheManager
    }

    func getImage(for imageData: ImageData, size: ImageSize) async throws -> UIImage? {
        // thumbnail（300px）とmedium（1024px）はローカルのみ
        if size == .thumbnail {
            if let thumbnail = await cacheManager.loadThumbnail(for: imageData.id) {
                return thumbnail
            }
        }

        if size == .medium {
            if let medium = await cacheManager.loadImage(imageId: imageData.id.uuidString, size: .medium) {
                return medium
            }
        }

        // ローカルファイルが存在する場合（旧データ）
        if imageData.remoteImageId == nil {
            return imageData.image // 既存の実装を使用
        }

        // large（2048px）のみリモートから取得
        guard size == .large else {
            return nil // thumbnail/mediumでローカルになければnil
        }

        guard let remoteImageId = imageData.remoteImageId else {
            return nil
        }

        // キャッシュチェック
        if let cached = await cacheManager.loadImage(imageId: remoteImageId, size: size) {
            return cached
        }

        // リモートからダウンロード
        let token = try await authManager.ensureAuthenticated()
        let width = Int(size.maxDimension)

        let data = try await apiClient.downloadImage(
            endpoint: .getImage(imageId: remoteImageId, width: width),
            bearerToken: token
        )

        guard let image = UIImage(data: data) else {
            return nil
        }

        // キャッシュに保存
        await cacheManager.saveImage(data, imageId: remoteImageId, size: size)

        return image
    }

    func deleteRemoteImage(for imageData: ImageData) async throws {
        guard let remoteImageId = imageData.remoteImageId else {
            return // ローカルのみなので何もしない
        }

        let token = try await authManager.ensureAuthenticated()
        let _: DeleteResponse = try await apiClient.request(
            endpoint: .deleteImage(imageId: remoteImageId),
            bearerToken: token
        )
    }
}

struct DeleteResponse: Codable {
    let ok: Bool
}
