//
//  AuthManager.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import Foundation

protocol AuthManagerProtocol {
    func ensureAuthenticated() async throws -> String
    func register() async throws
    func refreshToken() async throws
    func isTokenExpired() -> Bool
}

final class AuthManager: AuthManagerProtocol {
    private let apiClient: APIClientProtocol
    private let keychainManager: KeychainManagerProtocol

    private var cachedToken: String?
    private let tokenExpiryBuffer: TimeInterval = 300 // 5分前に更新

    init(apiClient: APIClientProtocol, keychainManager: KeychainManagerProtocol) {
        self.apiClient = apiClient
        self.keychainManager = keychainManager
    }

    func ensureAuthenticated() async throws -> String {
        // トークンが有効ならそれを返す
        if let token = cachedToken, !isTokenExpired() {
            return token
        }

        // Keychainから読み込み
        if let (deviceId, deviceSecret) = try? keychainManager.load() {
            let token = "\(deviceId).\(deviceSecret)"

            // 期限チェック
            if isTokenExpired() {
                // 期限切れなのでリフレッシュ
                try await refreshToken()
                return try await ensureAuthenticated() // 再帰呼び出し
            } else {
                cachedToken = token
                return token
            }
        }

        // デバイス登録がまだなので登録
        try await register()
        return try await ensureAuthenticated() // 再帰呼び出し
    }

    func register() async throws {
        let response: RegisterResponse = try await apiClient.request(
            endpoint: .register,
            bearerToken: nil
        )

        // Keychainに保存
        try keychainManager.save(
            deviceId: response.deviceId,
            deviceSecret: response.deviceSecret
        )
        try keychainManager.saveTokenExpiry(response.expiresAt)

        // キャッシュ更新
        cachedToken = "\(response.deviceId).\(response.deviceSecret)"
    }

    func refreshToken() async throws {
        guard let (deviceId, deviceSecret) = try? keychainManager.load() else {
            throw AuthError.notRegistered
        }

        let oldToken = "\(deviceId).\(deviceSecret)"
        let response: RefreshResponse = try await apiClient.request(
            endpoint: .refresh,
            bearerToken: oldToken
        )

        // Keychainに保存
        try keychainManager.save(
            deviceId: response.deviceId,
            deviceSecret: response.deviceSecret
        )
        try keychainManager.saveTokenExpiry(response.expiresAt)

        // キャッシュ更新
        cachedToken = "\(response.deviceId).\(response.deviceSecret)"
    }

    func isTokenExpired() -> Bool {
        guard let expiry = try? keychainManager.loadTokenExpiry() else {
            return true
        }
        // バッファを考慮して判定
        return Date().addingTimeInterval(tokenExpiryBuffer) >= expiry
    }
}

enum AuthError: Error {
    case notRegistered
    case tokenExpired
    case refreshFailed
}

struct RegisterResponse: Codable {
    let deviceId: String
    let deviceSecret: String
    let expiresAt: Date
}

struct RefreshResponse: Codable {
    let deviceId: String
    let deviceSecret: String
    let expiresAt: Date
}
