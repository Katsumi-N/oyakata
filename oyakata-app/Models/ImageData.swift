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
    var tagType: TagType
    var createdAt: Date
    var updatedAt: Date
    var hasAnnotations: Bool
    
    @Relationship(deleteRule: .nullify)
    var taskName: TaskName?
    
    @Relationship(deleteRule: .cascade, inverse: \MissListItem.imageData)
    var missListItems: [MissListItem] = []
    
    init(fileName: String, filePath: String, tagType: TagType, taskName: TaskName? = nil) {
        self.id = UUID()
        self.fileName = fileName
        self.filePath = filePath
        self.tagType = tagType
        self.taskName = taskName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.hasAnnotations = false
    }
    
    var image: UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsPath.appendingPathComponent(filePath)
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    func updateAnnotationStatus(_ hasAnnotations: Bool) {
        self.hasAnnotations = hasAnnotations
        self.updatedAt = Date()
    }
}