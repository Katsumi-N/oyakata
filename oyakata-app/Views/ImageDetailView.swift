//
//  ImageDetailView.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import SwiftUI
import SwiftData

struct ImageDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let imageData: ImageData
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var showingAddMissView = false
    @State private var showingTimeRecordView = false
    @State private var displayImage: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                // iPhone と同じ 1カラムレイアウトを使用
                VStack(alignment: .leading, spacing: 20) {
                    imageSection(geometry: geometry)
                    metadataSection
                    timeRecordSection
                    missListSection
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("画像詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingEditView = true
                    }) {
                        Label("編集", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        showingTimeRecordView = true
                    }) {
                        Label("時間記録", systemImage: "clock")
                    }
                    
                    Button(action: {
                        showingAddMissView = true
                    }) {
                        Label("ミスリスト追加", systemImage: "list.bullet.clipboard")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            NavigationView {
                ImageEditView(imageData: imageData)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTimeRecordView) {
            TimeRecordEditView(imageData: imageData)
        }
        .sheet(isPresented: $showingAddMissView) {
            AddMissFromImageView(imageData: imageData)
        }
        .alert("画像を削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                deleteImage()
            }
        } message: {
            Text("この画像を削除しますか？この操作は元に戻せません。")
        }
    }
    
    @ViewBuilder
    private func imageSection(geometry: GeometryProxy) -> some View {
        ZStack {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width - 32,
                           maxHeight: geometry.size.height * 0.6)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width - 32,
                           height: geometry.size.height * 0.4)
                    .cornerRadius(12)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .task {
            await loadDisplayImage()
        }
    }

    private func loadDisplayImage() async {
        // 詳細画面用にmediumサイズ（1024px）を取得
        let storageStrategy = ServiceLocator.shared.imageStorageStrategy

        do {
            if let mediumImage = try await storageStrategy.getImage(for: imageData, size: .medium) {
                await MainActor.run {
                    displayImage = mediumImage
                }
                return
            }
        } catch {
            print("Medium画像取得失敗: \(error)")
        }

        // フォールバック: ローカル画像を使用（既存データの場合）
        await MainActor.run {
            displayImage = imageData.image
        }
    }
    
    @ViewBuilder
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("詳細情報")
                .font(.headline)
                .tracking(0.3)
            
            VStack(spacing: 12) {
                if !imageData.tags.isEmpty {
                    MetadataRow(title: "タグ", value: imageData.tags.map { $0.displayName }.joined(separator: ", "), icon: "tag")
                }
                
                if let taskName = imageData.taskName {
                    MetadataRow(title: "課題名", value: taskName.name, icon: "doc.text")
                }
                
                MetadataRow(title: "作成日", value: DateFormatter.localizedString(from: imageData.createdAt, dateStyle: .medium, timeStyle: .short), icon: "calendar")
                
                if imageData.hasAnnotations {
                    MetadataRow(title: "編集状態", value: "編集済み", icon: "pencil", valueColor: .orange)
                }
                
                if imageData.updatedAt != imageData.createdAt {
                    MetadataRow(title: "更新日", value: DateFormatter.localizedString(from: imageData.updatedAt, dateStyle: .medium, timeStyle: .short), icon: "clock")
                }
            }
        }
    }
    
    @ViewBuilder
    private var timeRecordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("時間記録")
                    .font(.headline)
                    .tracking(0.3)
                
                Spacer()
                
                Button(action: {
                    showingTimeRecordView = true
                }) {
                    Image(systemName: imageData.hasTimeRecord ? "pencil.circle.fill" : "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            
            if let timeRecord = imageData.timeRecord, timeRecord.hasTimeRecorded {
                VStack(spacing: 16) {
                    // 時間記録項目
                    VStack(spacing: 8) {
                        if timeRecord.sketchTime > 0 {
                            ModernTimeDisplayRow(
                                title: "エスキス", 
                                time: timeRecord.sketchTimeFormatted, 
                                icon: "pencil",
                                color: .orange
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        if timeRecord.descriptionTime > 0 {
                            ModernTimeDisplayRow(
                                title: "記述", 
                                time: timeRecord.descriptionTimeFormatted, 
                                icon: "doc.text",
                                color: .green
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        if timeRecord.drawingTime > 0 {
                            ModernTimeDisplayRow(
                                title: "製図", 
                                time: timeRecord.drawingTimeFormatted, 
                                icon: "ruler",
                                color: .blue
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    
                    // 合計時間セクション
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("合計時間")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(timeRecord.totalTimeFormatted)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("時間記録がありません")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("時間を記録する") {
                        showingTimeRecordView = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private var missListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("関連するミスリスト")
                    .font(.headline)
                    .tracking(0.3)
                
                Spacer()
                
                Button(action: {
                    showingAddMissView = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            
            if imageData.missListItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("この画像に関連するミスリストはありません")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("ミスリストを追加") {
                        showingAddMissView = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                ForEach(imageData.missListItems, id: \.id) { missItem in
                    NavigationLink(destination: EditMissListItemView(missItem: missItem)) {
                        MissListItemCard(missItem: missItem)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func deleteImage() {
        // ファイルシステムから画像を削除
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsPath.appendingPathComponent(imageData.filePath)
        
        try? FileManager.default.removeItem(at: imageURL)
        
        // データベースから削除
        modelContext.delete(imageData)
        
        dismiss()
    }
}

struct MetadataRow: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
                .font(.subheadline)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .tracking(0.2)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(valueColor)
                .tracking(0.2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }
}

struct TimeRecordRow: View {
    let title: String
    let time: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
                .font(.subheadline)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .tracking(0.2)
            
            Spacer()
            
            Text(time)
                .font(.subheadline)
                .foregroundColor(.primary)
                .tracking(0.2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }
}

struct ModernTimeDisplayRow: View {
    let title: String
    let time: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(time)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct MissListItemCard: View {
    let missItem: MissListItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(missItem.title)
                    .font(.headline)
                    .lineLimit(1)
                    .tracking(0.3)
                
                Spacer()
                
                if missItem.isResolved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            Text(missItem.content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .tracking(0.2)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct AddMissFromImageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let imageData: ImageData
    @State private var title = ""
    @State private var content = ""
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        NavigationView {
            Form {
                Section("ミスの内容") {
                    TextField("タイトル", text: $title)
                    TextField("詳細説明", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("関連する画像") {
                    HStack {
                        if let image = thumbnailImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(8)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.7)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(imageData.tags.map { $0.displayName }.joined(separator: ", "))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let taskName = imageData.taskName {
                                Text(taskName.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("新しいミス記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveMissItem()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
            .task {
                await loadThumbnail()
            }
        }
    }

    private func loadThumbnail() async {
        let storageStrategy = ServiceLocator.shared.imageStorageStrategy
        if let thumbnail = try? await storageStrategy.getImage(for: imageData, size: .thumbnail) {
            await MainActor.run {
                thumbnailImage = thumbnail
            }
        }
    }
    
    private func saveMissItem() {
        let missItem = MissListItem(title: title, content: content, imageData: imageData)
        modelContext.insert(missItem)
        dismiss()
    }
}