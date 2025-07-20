//
//  TimeRecord.swift
//  oyakata-app
//
//  Created by Claude on 2025/07/20.
//

import Foundation
import SwiftData

@Model
final class TimeRecord {
    var id: UUID
    var sketchTime: Int // エスキス時間（分）
    var descriptionTime: Int // 記述時間（分）
    var drawingTime: Int // 製図時間（分）
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .nullify, inverse: \ImageData.timeRecord)
    var imageData: ImageData?
    
    init(sketchTime: Int = 0, descriptionTime: Int = 0, drawingTime: Int = 0, imageData: ImageData? = nil) {
        self.id = UUID()
        self.sketchTime = sketchTime
        self.descriptionTime = descriptionTime
        self.drawingTime = drawingTime
        self.imageData = imageData
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 合計時間（分）を計算
    var totalTime: Int {
        return sketchTime + descriptionTime + drawingTime
    }
    
    /// 合計時間を時間と分の形式で返す
    var totalTimeFormatted: String {
        let hours = totalTime / 60
        let minutes = totalTime % 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    /// エスキス時間を時間と分の形式で返す
    var sketchTimeFormatted: String {
        return formatTime(sketchTime)
    }
    
    /// 記述時間を時間と分の形式で返す
    var descriptionTimeFormatted: String {
        return formatTime(descriptionTime)
    }
    
    /// 製図時間を時間と分の形式で返す
    var drawingTimeFormatted: String {
        return formatTime(drawingTime)
    }
    
    private func formatTime(_ timeInMinutes: Int) -> String {
        let hours = timeInMinutes / 60
        let minutes = timeInMinutes % 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    /// 時間記録を更新
    func updateTimes(sketchTime: Int, descriptionTime: Int, drawingTime: Int) {
        self.sketchTime = sketchTime
        self.descriptionTime = descriptionTime
        self.drawingTime = drawingTime
        self.updatedAt = Date()
    }
    
    /// 時間が記録されているかどうか
    var hasTimeRecorded: Bool {
        return sketchTime > 0 || descriptionTime > 0 || drawingTime > 0
    }
}