//
//  APIEndpoint.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/14.
//

import Foundation

enum APIEndpoint {
    case register
    case refresh
    case uploadURL(contentType: String, sizeBytes: Int?, nonce: String)
    case getImage(imageId: String, width: Int?)
    case deleteImage(imageId: String)

    var path: String {
        switch self {
        case .register:
            return "/v1/anonymous/register"
        case .refresh:
            return "/v1/auth/refresh"
        case .uploadURL:
            return "/v1/images/upload-url"
        case .getImage(let imageId, _):
            return "/v1/images/\(imageId)"
        case .deleteImage(let imageId):
            return "/v1/images/\(imageId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .refresh, .uploadURL:
            return .post
        case .getImage:
            return .get
        case .deleteImage:
            return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .getImage(_, let width):
            if let width = width {
                return [URLQueryItem(name: "w", value: "\(width)")]
            }
            return nil
        default:
            return nil
        }
    }

    func body() throws -> Data? {
        switch self {
        case .uploadURL(let contentType, let sizeBytes, let nonce):
            var dict: [String: Any] = [
                "contentType": contentType,
                "nonce": nonce
            ]
            if let sizeBytes = sizeBytes {
                dict["sizeBytes"] = sizeBytes
            }
            return try JSONSerialization.data(withJSONObject: dict)
        default:
            return nil
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
