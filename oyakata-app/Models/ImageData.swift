//
//  ImageData.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import Foundation
import SwiftData
import UIKit

@Model
final class ImageData {
    var id: UUID
    var fileName: String
    var filePath: String
    var tags: [TagType]
    var createdAt: Date
    var updatedAt: Date
    var hasAnnotations: Bool
    var groupId: UUID?
    var groupCreatedAt: Date?
    
    @Relationship(deleteRule: .nullify)
    var taskName: TaskName?
    
    @Relationship(deleteRule: .cascade, inverse: \MissListItem.imageData)
    var missListItems: [MissListItem] = []
    
    @Relationship(deleteRule: .cascade)
    var timeRecord: TimeRecord?
    
    init(fileName: String, filePath: String, tags: [TagType] = [], taskName: TaskName? = nil, groupId: UUID? = nil, groupCreatedAt: Date? = nil) {
        self.id = UUID()
        self.fileName = fileName
        self.filePath = filePath
        self.tags = tags
        self.taskName = taskName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.hasAnnotations = false
        self.groupId = groupId
        self.groupCreatedAt = groupCreatedAt
    }
    
    var image: UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsPath.appendingPathComponent(filePath)
        return loadOptimizedImage(from: imageURL)
    }
    
    private func loadOptimizedImage(from url: URL) -> UIImage? {
        // PDFファイルの場合は既に画像として保存されているため、通常の画像読み込みを行う
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        // 画像のプロパティを取得
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return UIImage(contentsOfFile: url.path)
        }
        
        let imageSize = CGSize(width: width.doubleValue, height: height.doubleValue)
        let maxDimension: CGFloat = 2048 // 最大解像度を制限
        
        // リサイズが必要かチェック
        if max(imageSize.width, imageSize.height) <= maxDimension {
            return UIImage(contentsOfFile: url.path)
        }
        
        // ダウンサンプリングオプション
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return UIImage(contentsOfFile: url.path)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    func updateAnnotationStatus(_ hasAnnotations: Bool) {
        self.hasAnnotations = hasAnnotations
        self.updatedAt = Date()
    }
    
    // MARK: - グループ関連のヘルパーメソッド（UIには露出せず、バックエンド処理用）
    
    /// 同じグループに属する画像かどうかを判定
    func belongsToSameGroup(as other: ImageData) -> Bool {
        guard let thisGroupId = self.groupId,
              let otherGroupId = other.groupId else {
            return false
        }
        return thisGroupId == otherGroupId
    }
    
    /// グループ化された画像かどうかを判定
    var isGrouped: Bool {
        return groupId != nil
    }
    
    /// 無効なタグを除去して有効なタグのみを返す
    var validTags: [TagType] {
        return tags.filter { tag in
            TagType.allCases.contains(tag)
        }
    }
    
    /// 無効なタグがある場合にクリーンアップする
    func cleanupInvalidTags() {
        let validTagsArray = validTags
        if validTagsArray.count != tags.count {
            tags = validTagsArray
            updateAnnotationStatus(hasAnnotations)
        }
    }
    
    /// 時間記録があるかどうか
    var hasTimeRecord: Bool {
        return timeRecord?.hasTimeRecorded ?? false
    }
}