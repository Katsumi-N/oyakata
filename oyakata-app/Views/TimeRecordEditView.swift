//
//  TimeRecordEditView.swift
//  oyakata-app
//
//  Created by Claude on 2025/07/20.
//

import SwiftUI
import SwiftData

struct TimeRecordEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let imageData: ImageData
    
    @State private var sketchHours: Int = 0
    @State private var sketchMinutes: Int = 0
    @State private var descriptionHours: Int = 0
    @State private var descriptionMinutes: Int = 0
    @State private var drawingHours: Int = 0
    @State private var drawingMinutes: Int = 0
    
    private var totalMinutes: Int {
        let sketchTotal = sketchHours * 60 + sketchMinutes
        let descriptionTotal = descriptionHours * 60 + descriptionMinutes
        let drawingTotal = drawingHours * 60 + drawingMinutes
        return sketchTotal + descriptionTotal + drawingTotal
    }
    
    private var totalTimeFormatted: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // ヘッダーセクション
                    VStack(alignment: .leading, spacing: 8) {
                        Text("作業時間を記録")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("各工程にかかった時間を入力してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    
                    // 時間入力セクション
                    VStack(spacing: 16) {
                        ModernTimeInputCard(
                            title: "エスキス",
                            icon: "pencil",
                            iconColor: .orange,
                            hours: $sketchHours,
                            minutes: $sketchMinutes
                        )
                        
                        ModernTimeInputCard(
                            title: "記述",
                            icon: "doc.text",
                            iconColor: .green,
                            hours: $descriptionHours,
                            minutes: $descriptionMinutes
                        )
                        
                        ModernTimeInputCard(
                            title: "製図",
                            icon: "ruler",
                            iconColor: .blue,
                            hours: $drawingHours,
                            minutes: $drawingMinutes
                        )
                    }
                    
                    // 合計時間カード
                    TotalTimeCard(totalTime: totalTimeFormatted)
                    
                    // 関連画像カード
                    RelatedImageCard(imageData: imageData)
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("時間記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTimeRecord()
                    }
                }
            }
            .onAppear {
                loadExistingTimeRecord()
            }
        }
    }
    
    private func loadExistingTimeRecord() {
        if let timeRecord = imageData.timeRecord {
            let sketchTotal = timeRecord.sketchTime
            sketchHours = sketchTotal / 60
            sketchMinutes = sketchTotal % 60
            
            let descriptionTotal = timeRecord.descriptionTime
            descriptionHours = descriptionTotal / 60
            descriptionMinutes = descriptionTotal % 60
            
            let drawingTotal = timeRecord.drawingTime
            drawingHours = drawingTotal / 60
            drawingMinutes = drawingTotal % 60
        }
    }
    
    private func saveTimeRecord() {
        let sketchTotal = sketchHours * 60 + sketchMinutes
        let descriptionTotal = descriptionHours * 60 + descriptionMinutes
        let drawingTotal = drawingHours * 60 + drawingMinutes
        
        if let existingRecord = imageData.timeRecord {
            existingRecord.updateTimes(
                sketchTime: sketchTotal,
                descriptionTime: descriptionTotal,
                drawingTime: drawingTotal
            )
        } else {
            let newRecord = TimeRecord(
                sketchTime: sketchTotal,
                descriptionTime: descriptionTotal,
                drawingTime: drawingTotal,
                imageData: imageData
            )
            modelContext.insert(newRecord)
            imageData.timeRecord = newRecord
        }
        
        dismiss()
    }
}

struct ModernTimeInputCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    @Binding var hours: Int
    @Binding var minutes: Int
    
    private var timeFormatted: String {
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else if minutes > 0 {
            return "\(minutes)分"
        } else {
            return "未設定"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(timeFormatted)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("時間")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Picker("時間", selection: $hours) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour)")
                                .font(.title3)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(spacing: 8) {
                    Text("分")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Picker("分", selection: $minutes) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                            Text("\(minute)")
                                .font(.title3)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct TotalTimeCard: View {
    let totalTime: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("合計時間")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(totalTime)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct RelatedImageCard: View {
    let imageData: ImageData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("関連する画像")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                if let image = imageData.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(imageData.tags.map { $0.displayName }.joined(separator: ", "))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    if let taskName = imageData.taskName {
                        Text(taskName.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}