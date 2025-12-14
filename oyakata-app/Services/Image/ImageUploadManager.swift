//
//  ImageUploadManager.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import UIKit
import SwiftData

enum ImageUploadStatus: String, Codable {
    case localOnly
    case uploading
    case completed
    case failed
    case retryScheduled
}

protocol ImageUploadManagerProtocol {
    func uploadImage(_ imageData: ImageData, image: UIImage) async throws
    func retryFailedUploads(modelContext: ModelContext) async
}

final class ImageUploadManager: ImageUploadManagerProtocol {
    private let authManager: AuthManagerProtocol
    private let apiClient: APIClientProtocol
    private let sizeGenerator: ImageSizeGeneratorProtocol
    private let cacheManager: ImageCacheManagerProtocol

    init(
        authManager: AuthManagerProtocol,
        apiClient: APIClientProtocol,
        sizeGenerator: ImageSizeGeneratorProtocol,
        cacheManager: ImageCacheManagerProtocol
    ) {
        self.authManager = authManager
        self.apiClient = apiClient
        self.sizeGenerator = sizeGenerator
        self.cacheManager = cacheManager
    }

    func uploadImage(_ imageData: ImageData, image: UIImage) async throws {
        // ステータスを更新
        await updateStatus(imageData, to: .uploading)

        do {
            // 3サイズを生成
            let sizes = await sizeGenerator.generateSizes(from: image)

            // thumbnail（300px）をローカル保存 - サムネイル表示用
            if let thumbnailData = sizes[.thumbnail] {
                await cacheManager.saveThumbnail(thumbnailData, for: imageData.id)
                await updateStoredSizes(imageData, add: .thumbnail)
            }

            // medium（1024px）をローカル保存 - 詳細画面表示用
            if let mediumData = sizes[.medium] {
                await cacheManager.saveImage(mediumData, imageId: imageData.id.uuidString, size: .medium)
                await updateStoredSizes(imageData, add: .medium)
            }

            // large（2048px）のみをR2にアップロード - Apple Pencil編集用
            if let largeData = sizes[.large] {
                try await uploadSize(largeData, size: .large, imageData: imageData)
            }

            // 成功
            await updateStatus(imageData, to: .completed)
            await updateUploadedAt(imageData)

        } catch {
            // 失敗
            await updateStatus(imageData, to: .failed)
            await incrementRetryCount(imageData)
            throw error
        }
    }

    private func uploadSize(_ data: Data, size: ImageSize, imageData: ImageData) async throws {
        let token = try await authManager.ensureAuthenticated()
        let nonce = UUID().uuidString

        // アップロードURL取得
        let uploadResponse: UploadURLResponse = try await apiClient.request(
            endpoint: .uploadURL(
                contentType: "image/jpeg",
                sizeBytes: data.count,
                nonce: nonce
            ),
            bearerToken: token
        )

        // 初回のみimageIdを保存
        if imageData.remoteImageId == nil {
            await updateRemoteImageId(imageData, id: uploadResponse.imageId)
        }

        // R2に直接PUT
        try await apiClient.uploadImage(
            to: uploadResponse.uploadUrl,
            imageData: data,
            contentType: "image/jpeg",
            requiredHeaders: uploadResponse.requiredHeaders
        )
    }

    func retryFailedUploads(modelContext: ModelContext) async {
        // 失敗したアップロードを検索（Predicateマクロでは列挙型の比較ができないため、全件取得してフィルタリング）
        let descriptor = FetchDescriptor<ImageData>()

        guard let allImages = try? modelContext.fetch(descriptor) else {
            return
        }

        let failedUploads = allImages.filter { $0.uploadStatus == .failed }

        // 最大3回まで再試行
        for imageData in failedUploads {
            guard imageData.uploadRetryCount < 3 else {
                continue
            }

            // 指数バックオフ: 1分、5分、15分
            let backoffIntervals: [TimeInterval] = [60, 300, 900]
            let backoffInterval = backoffIntervals[min(imageData.uploadRetryCount, 2)]

            if let lastAttempt = imageData.lastUploadAttempt,
               Date().timeIntervalSince(lastAttempt) < backoffInterval {
                continue // まだ待機中
            }

            // 画像を読み込んで再試行
            if let image = imageData.image {
                do {
                    try await uploadImage(imageData, image: image)
                } catch {
                    print("再アップロード失敗: \(error)")
                }
            }
        }
    }

    // MARK: - MainActor Helper Methods

    @MainActor
    private func updateStatus(_ imageData: ImageData, to status: ImageUploadStatus) {
        imageData.uploadStatus = status
    }

    @MainActor
    private func updateStoredSizes(_ imageData: ImageData, add size: ImageSize) {
        if !imageData.storedSizes.contains(size) {
            imageData.storedSizes.append(size)
        }
    }

    @MainActor
    private func updateRemoteImageId(_ imageData: ImageData, id: String) {
        imageData.remoteImageId = id
    }

    @MainActor
    private func updateUploadedAt(_ imageData: ImageData) {
        imageData.uploadedAt = Date()
    }

    @MainActor
    private func incrementRetryCount(_ imageData: ImageData) {
        imageData.uploadRetryCount += 1
        imageData.lastUploadAttempt = Date()
    }
}

struct UploadURLResponse: Codable {
    let imageId: String
    let uploadUrl: URL
    let expiresAt: Int
    let requiredHeaders: [String: String]
}
