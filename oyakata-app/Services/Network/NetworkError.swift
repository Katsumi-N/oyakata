//
//  NetworkError.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(statusCode: Int, message: String?)
    case unauthorized
    case tokenExpired
    case nonceReused
    case notFound
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .noData:
            return "データが取得できませんでした"
        case .decodingError(let error):
            return "データの解析に失敗しました: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTPエラー(\(statusCode)): \(message ?? "不明なエラー")"
        case .unauthorized:
            return "認証に失敗しました"
        case .tokenExpired:
            return "トークンの有効期限が切れています"
        case .nonceReused:
            return "Nonceが再利用されました"
        case .notFound:
            return "リソースが見つかりません"
        case .unknown(let error):
            return "不明なエラー: \(error.localizedDescription)"
        }
    }
}

struct APIErrorResponse: Codable {
    let ok: Bool
    let error: String
    let message: String?
}
