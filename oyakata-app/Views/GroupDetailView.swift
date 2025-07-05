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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダー情報（「グループ」という表現を避ける）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("画像一覧")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(group.images.count)枚")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // タグと課題名情報
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: group.representativeImage.tagType.systemImage)
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(group.representativeImage.tagType.displayName)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        if let taskName = group.representativeImage.taskName {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(taskName.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
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