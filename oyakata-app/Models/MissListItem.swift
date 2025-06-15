//
//  MissListItem.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import Foundation
import SwiftData

@Model
final class MissListItem {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isResolved: Bool
    
    @Relationship(deleteRule: .nullify)
    var imageData: ImageData?
    
    init(title: String, content: String, imageData: ImageData? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.imageData = imageData
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isResolved = false
    }
    
    func toggleResolved() {
        isResolved.toggle()
        updatedAt = Date()
    }
    
    func updateContent(title: String, content: String) {
        self.title = title
        self.content = content
        self.updatedAt = Date()
    }
}