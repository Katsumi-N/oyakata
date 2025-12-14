//
//  KeychainManager.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import Foundation
import Security

protocol KeychainManagerProtocol {
    func save(deviceId: String, deviceSecret: String) throws
    func load() throws -> (deviceId: String, deviceSecret: String)?
    func delete() throws
    func saveTokenExpiry(_ date: Date) throws
    func loadTokenExpiry() throws -> Date?
}

final class KeychainManager: KeychainManagerProtocol {
    private let service = "com.oyakata.app"
    private let deviceIdKey = "deviceId"
    private let deviceSecretKey = "deviceSecret"
    private let tokenExpiryKey = "tokenExpiry"

    enum KeychainError: Error {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case notFound
        case invalidData
    }

    func save(deviceId: String, deviceSecret: String) throws {
        try saveString(deviceId, forKey: deviceIdKey)
        try saveString(deviceSecret, forKey: deviceSecretKey)
    }

    func load() throws -> (deviceId: String, deviceSecret: String)? {
        guard let deviceId = try? loadString(forKey: deviceIdKey),
              let deviceSecret = try? loadString(forKey: deviceSecretKey) else {
            return nil
        }
        return (deviceId, deviceSecret)
    }

    func delete() throws {
        try deleteItem(forKey: deviceIdKey)
        try deleteItem(forKey: deviceSecretKey)
        try? deleteItem(forKey: tokenExpiryKey)
    }

    func saveTokenExpiry(_ date: Date) throws {
        let data = try JSONEncoder().encode(date)
        try saveData(data, forKey: tokenExpiryKey)
    }

    func loadTokenExpiry() throws -> Date? {
        guard let data = try? loadData(forKey: tokenExpiryKey) else {
            return nil
        }
        return try JSONDecoder().decode(Date.self, from: data)
    }

    // MARK: - Private Helper Methods

    private func saveString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try saveData(data, forKey: key)
    }

    private func loadString(forKey key: String) throws -> String? {
        guard let data = try? loadData(forKey: key),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func saveData(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // 既存アイテムを削除
        SecItemDelete(query as CFDictionary)

        // 新規追加
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func loadData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    private func deleteItem(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
