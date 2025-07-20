//
//  MigrationManager.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import Foundation
import SwiftData

class MigrationManager {
    static func handleMigration() {
        let fileManager = FileManager.default
        
        // アプリのDocumentsディレクトリとApplication Supportディレクトリを確認
        let directories = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ].compactMap { $0 }
        
        for directory in directories {
            do {
                let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                
                // SwiftData関連のファイルを探して削除
                let dataFiles = contents.filter { url in
                    let fileName = url.lastPathComponent
                    return fileName.contains("default") || 
                           fileName.hasSuffix(".store") ||
                           fileName.hasSuffix(".sqlite") ||
                           fileName.hasSuffix(".sqlite-wal") ||
                           fileName.hasSuffix(".sqlite-shm")
                }
                
                for file in dataFiles {
                    try fileManager.removeItem(at: file)
                    print("マイグレーション: 削除されたファイル - \(file.lastPathComponent)")
                }
                
                if !dataFiles.isEmpty {
                    print("マイグレーション: \(dataFiles.count)個のデータベースファイルを削除しました")
                }
                
            } catch {
                print("マイグレーションエラー: \(directory.path) - \(error)")
            }
        }
    }
    
    static func clearImageCache() {
        let fileManager = FileManager.default
        
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            
            // 画像ファイル（.jpgファイル）を削除
            let imageFiles = contents.filter { $0.pathExtension.lowercased() == "jpg" }
            
            for imageFile in imageFiles {
                try fileManager.removeItem(at: imageFile)
                print("画像キャッシュクリア: \(imageFile.lastPathComponent)")
            }
            
            if !imageFiles.isEmpty {
                print("画像キャッシュクリア: \(imageFiles.count)個の画像ファイルを削除しました")
            }
            
        } catch {
            print("画像キャッシュクリアエラー: \(error)")
        }
    }
}