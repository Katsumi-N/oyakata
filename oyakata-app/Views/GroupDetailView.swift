//
//  GroupDetailView.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/22.
//

import SwiftUI
import SwiftData

struct GroupDetailView: View {
    let group: ImageGroup
    
    var imageWidth: CGFloat {
        // iPhone と同じサイズを使用
        return 160
    }
    
    // グループに関連するミスリストを取得
    var groupMissItems: [MissListItem] {
        return group.images.flatMap { $0.missListItems }.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダー情報（「グループ」という表現を避ける）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        if let taskName = group.representativeImage.taskName {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(taskName.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(group.images.count)枚")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // タグと課題名情報
                    VStack(alignment: .leading, spacing: 8) {
                        if !group.representativeImage.tags.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(group.representativeImage.tags.map { $0.displayName }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(formatDate(group.groupCreatedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 画像横スクロール
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(group.images, id: \.id) { imageData in
                            NavigationLink(destination: ImageDetailView(imageData: imageData)) {
                                GroupImageItemView(imageData: imageData, imageWidth: imageWidth)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // ミスリスト一覧セクション
                if !groupMissItems.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("ミスリスト")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(groupMissItems.count)件")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(groupMissItems, id: \.id) { missItem in
                                NavigationLink(destination: EditMissListItemView(missItem: missItem)) {
                                    GroupMissListRowView(missItem: missItem)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
            }
        }
        .navigationTitle("画像詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// ミスリスト行表示用のコンポーネント
struct GroupMissListRowView: View {
    let missItem: MissListItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // アイコン
            Image(systemName: missItem.isResolved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(missItem.isResolved ? .green : .red)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 6) {
                // タイトル
                Text(missItem.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 内容
                if !missItem.content.isEmpty {
                    Text(missItem.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                // 作成日時
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(formatMissItemDate(missItem.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if missItem.isResolved {
                        Text("解決済み")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                }
            }
            
            Spacer()
            
            // 矢印アイコン
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    private func formatMissItemDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct GroupImageItemView: View {
    let imageData: ImageData
    let imageWidth: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 画像
            if let image = imageData.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageWidth, height: imageWidth * 0.75)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: imageWidth, height: imageWidth * 0.75)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            
            // メタデータ
            VStack(alignment: .leading, spacing: 4) {
                if imageData.hasAnnotations {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("編集済み")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Text(formatTime(imageData.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: imageWidth)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
