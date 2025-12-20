//
//  ImageDeletionManager.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/20.
//

import Foundation
import SwiftData
import UIKit

protocol ImageDeletionManagerProtocol {
    func deleteImage(_ imageData: ImageData, modelContext: ModelContext) async throws
    func processQueuedDeletions(modelContext: ModelContext) async
}

final class ImageDeletionManager: ImageDeletionManagerProtocol {
    private let storageStrategy: ImageStorageStrategyProtocol
    private let cacheManager: ImageCacheManagerProtocol
    private let networkMonitor: NetworkMonitorProtocol

    init(
        storageStrategy: ImageStorageStrategyProtocol,
        cacheManager: ImageCacheManagerProtocol,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.storageStrategy = storageStrategy
        self.cacheManager = cacheManager
        self.networkMonitor = networkMonitor
    }

    // MARK: - Public Methods

    @MainActor
    func deleteImage(_ imageData: ImageData, modelContext: ModelContext) async throws {
        // ケース1: リモート画像あり
        if let remoteImageId = imageData.remoteImageId, !remoteImageId.isEmpty {
            // オンラインかチェック
            if networkMonitor.isConnected {
                // オンライン: リモート削除を試行
                updateDeletionStatus(imageData, to: .deletingRemote, modelContext: modelContext)

                do {
                    // リモート削除を実行
                    try await storageStrategy.deleteRemoteImage(for: imageData)

                    // 成功: すべてのローカルファイルをクリーンアップ
                    // 必要な値を事前に取得
                    let filePath = imageData.filePath
                    let imageId = imageData.id
                    let remoteId = imageData.remoteImageId
                    await cleanupLocalFiles(filePath: filePath, imageId: imageId, remoteImageId: remoteId)

                    // SwiftDataから削除
                    modelContext.delete(imageData)
                    try? modelContext.save()
                } catch {
                    // 失敗: リトライのためにマーク
                    handleDeletionFailure(imageData, error: error, modelContext: modelContext)
                    throw error  // エラーを伝播してUIに通知
                }
            } else {
                // オフライン: 削除を保留
                updateDeletionStatus(imageData, to: .pendingDeletion, modelContext: modelContext)
                throw NetworkError.offline
            }
        } else {
            // ケース2: ローカルのみの画像 - 直接削除
            // 必要な値を事前に取得
            let filePath = imageData.filePath
            let imageId = imageData.id
            let remoteId = imageData.remoteImageId
            await cleanupLocalFiles(filePath: filePath, imageId: imageId, remoteImageId: remoteId)

            modelContext.delete(imageData)
            try? modelContext.save()
        }
    }

    @MainActor
    func processQueuedDeletions(modelContext: ModelContext) async {
        guard networkMonitor.isConnected else { return }

        // 保留中と失敗したもののリストを取得
        let descriptor = FetchDescriptor<ImageData>()
        guard let allImages = try? modelContext.fetch(descriptor) else { return }

        let queuedDeletions = allImages.filter { imageData in
            guard let status = imageData.deletionStatus else { return false }

            // 最大リトライを超えた画像はスキップ
            if imageData.deletionRetryCount >= 3 {
                return false
            }

            // pendingDeletionまたはremoteFailedのみ処理
            return status == .pendingDeletion || status == .remoteFailed
        }

        // エクスポネンシャルバックオフのインターバル
        let backoffIntervals: [TimeInterval] = [60, 300, 900] // 1分、5分、15分

        for imageData in queuedDeletions {
            // バックオフチェック
            if let lastAttempt = imageData.lastDeletionAttempt {
                let retryCount = min(imageData.deletionRetryCount, backoffIntervals.count - 1)
                let backoffInterval = backoffIntervals[retryCount]

                // まだバックオフ期間中ならスキップ
                if Date().timeIntervalSince(lastAttempt) < backoffInterval {
                    continue
                }
            }

            // 削除を再試行
            do {
                try await deleteImage(imageData, modelContext: modelContext)
            } catch {
                print("キューの削除に失敗しました: \(error)")
                // エラーは既にhandleDeletionFailureで処理済み
            }
        }
    }

    // MARK: - Private Methods

    private func cleanupLocalFiles(filePath: String, imageId: UUID, remoteImageId: String?) async {
        let fileManager = FileManager.default

        // 1. オリジナルファイルを削除（Documents/）
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imageURL = documentsPath.appendingPathComponent(filePath)
            try? fileManager.removeItem(at: imageURL)

            // 2. サムネイルを削除（Documents/Thumbnails/）
            let thumbnailDir = documentsPath.appendingPathComponent("Thumbnails")
            let thumbnailURL = thumbnailDir.appendingPathComponent("\(imageId.uuidString)_thumbnail.jpg")
            try? fileManager.removeItem(at: thumbnailURL)
        }

        // 3. キャッシュされた画像を削除（medium, large）
        if let remoteImageId = remoteImageId,
           let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cacheDir = cachesPath.appendingPathComponent("ImageCache")
            let mediumURL = cacheDir.appendingPathComponent("\(remoteImageId)_medium.jpg")
            let largeURL = cacheDir.appendingPathComponent("\(remoteImageId)_large.jpg")

            try? fileManager.removeItem(at: mediumURL)
            try? fileManager.removeItem(at: largeURL)
        }

        // 4. メモリキャッシュからも削除（可能なら）
        // ImageCacheManagerのAPIに依存
    }

    @MainActor
    private func updateDeletionStatus(_ imageData: ImageData, to status: DeletionStatus, modelContext: ModelContext) {
        imageData.deletionStatus = status
        imageData.lastDeletionAttempt = Date()
        try? modelContext.save()
    }

    @MainActor
    private func handleDeletionFailure(_ imageData: ImageData, error: Error, modelContext: ModelContext) {
        imageData.deletionRetryCount += 1

        // 最大リトライを超えたか確認
        if imageData.deletionRetryCount >= 3 {
            imageData.deletionStatus = .failed
        } else {
            imageData.deletionStatus = .remoteFailed
        }

        imageData.lastDeletionAttempt = Date()
        try? modelContext.save()
    }
}
