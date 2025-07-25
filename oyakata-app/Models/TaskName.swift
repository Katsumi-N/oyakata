//
//  TaskName.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import Foundation
import SwiftData

@Model
final class TaskName: Hashable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \ImageData.taskName)
    var images: [ImageData] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
    
    static var yearSuggestions: [String] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear-10...currentYear+2).map { "令和\($0 - 2018)年" }
    }
    
    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TaskName, rhs: TaskName) -> Bool {
        return lhs.id == rhs.id
    }
}