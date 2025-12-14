//
//  APIClient.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import Foundation

protocol APIClientProtocol {
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        bearerToken: String?
    ) async throws -> T

    func uploadImage(
        to url: URL,
        imageData: Data,
        contentType: String,
        requiredHeaders: [String: String]
    ) async throws

    func downloadImage(
        endpoint: APIEndpoint,
        bearerToken: String?
    ) async throws -> Data
}

final class APIClient: APIClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        // カスタムURLSessionを設定
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfig.timeout
        configuration.timeoutIntervalForResource = APIConfig.timeout * 2
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData


        self.session = URLSession(configuration: configuration)
    }

    func request<T: Decodable>(
        endpoint: APIEndpoint,
        bearerToken: String? = nil
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }

        urlComponents.queryItems = endpoint.queryItems

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        // ボディを設定
        if let body = try endpoint.body() {
            request.httpBody = body
        }

        // 認証ヘッダー
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Content-Type
        if request.httpBody != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // デバッグログ
        print("🌐 API Request: \(endpoint.method.rawValue) \(url)")
        if let token = bearerToken {
            print("🔑 Token: \(token.prefix(20))...")
        }

        let (data, response) = try await session.data(for: request)

        print("📥 API Response: \(data.count) bytes")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "", code: -1, userInfo: nil))
        }

        // エラーレスポンス処理
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                switch errorResponse.error {
                case "unauthorized":
                    throw NetworkError.unauthorized
                case "token_expired":
                    throw NetworkError.tokenExpired
                case "nonce_reused":
                    throw NetworkError.nonceReused
                case "not_found":
                    throw NetworkError.notFound
                default:
                    throw NetworkError.httpError(
                        statusCode: httpResponse.statusCode,
                        message: errorResponse.message
                    )
                }
            }
            throw NetworkError.httpError(
                statusCode: httpResponse.statusCode,
                message: nil
            )
        }

        // デコード
        do {
            let decoder = JSONDecoder()
            // ミリ秒を含むISO8601形式に対応
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // ISO8601DateFormatterでミリ秒を含む形式をパース
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                if let date = formatter.date(from: dateString) {
                    return date
                }

                // ミリ秒なしの形式も試す
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "日付文字列をデコードできませんでした: \(dateString)"
                )
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    func uploadImage(
        to url: URL,
        imageData: Data,
        contentType: String,
        requiredHeaders: [String: String]
    ) async throws {
        var request = URLRequest(url: url, timeoutInterval: APIConfig.uploadTimeout)
        request.httpMethod = "PUT"
        request.httpBody = imageData

        // 必須ヘッダーを設定
        for (key, value) in requiredHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "", code: -1, userInfo: nil))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.httpError(
                statusCode: httpResponse.statusCode,
                message: "R2へのアップロードに失敗しました"
            )
        }
    }

    func downloadImage(
        endpoint: APIEndpoint,
        bearerToken: String?
    ) async throws -> Data {
        guard var urlComponents = URLComponents(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }

        urlComponents.queryItems = endpoint.queryItems

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: APIConfig.timeout)
        request.httpMethod = endpoint.method.rawValue

        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "", code: -1, userInfo: nil))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.httpError(
                statusCode: httpResponse.statusCode,
                message: "画像のダウンロードに失敗しました"
            )
        }

        return data
    }
}
