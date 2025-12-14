//
//  ServiceLocator.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import Foundation

final class ServiceLocator {
    static let shared = ServiceLocator()

    // シングルトン
    let keychainManager: KeychainManagerProtocol
    let apiClient: APIClientProtocol
    let authManager: AuthManagerProtocol
    let imageSizeGenerator: ImageSizeGeneratorProtocol
    let imageCacheManager: ImageCacheManagerProtocol
    let imageUploadManager: ImageUploadManagerProtocol
    let imageStorageStrategy: ImageStorageStrategyProtocol

    private init() {
        self.keychainManager = KeychainManager()
        self.apiClient = APIClient()
        self.authManager = AuthManager(
            apiClient: apiClient,
            keychainManager: keychainManager
        )
        self.imageSizeGenerator = ImageSizeGenerator()
        self.imageCacheManager = ImageCacheManager()
        self.imageUploadManager = ImageUploadManager(
            authManager: authManager,
            apiClient: apiClient,
            sizeGenerator: imageSizeGenerator,
            cacheManager: imageCacheManager
        )
        self.imageStorageStrategy = ImageStorageStrategy(
            authManager: authManager,
            apiClient: apiClient,
            cacheManager: imageCacheManager
        )
    }
}
