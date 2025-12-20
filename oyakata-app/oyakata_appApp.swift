//
//  oyakata_appApp.swift
//  oyakata-app
//
//  Created by 納谷克海 on 2025/06/13.
//

import SwiftUI
import SwiftData

@main
struct oyakata_appApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ImageData.self,
            TaskName.self,
            MissListItem.self,
            TimeRecord.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // データベースが破損している場合、マイグレーションを実行
            print("ModelContainer作成エラー: \(error)")
            print("データベースマイグレーションを実行しています...")
            
            // マイグレーションマネージャーを使用してクリーンアップ
            MigrationManager.handleMigration()
            
            // 新しいコンテナを作成
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("マイグレーション後もModelContainer作成に失敗: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // アプリ起動時に失敗したアップロードを再試行
                    let uploadManager = ServiceLocator.shared.imageUploadManager
                    let modelContext = ModelContext(sharedModelContainer)
                    await uploadManager.retryFailedUploads(modelContext: modelContext)

                    // アプリ起動時に削除キューを処理
                    let deletionManager = ServiceLocator.shared.imageDeletionManager
                    await deletionManager.processQueuedDeletions(modelContext: modelContext)
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                startNetworkMonitoring()
            } else if newPhase == .background {
                stopNetworkMonitoring()
            }
        }
    }

    private func startNetworkMonitoring() {
        let networkMonitor = ServiceLocator.shared.networkMonitor
        let deletionManager = ServiceLocator.shared.imageDeletionManager

        networkMonitor.startMonitoring { isConnected in
            if isConnected {
                // オンライン復帰時に削除キューを処理
                Task { @MainActor in
                    let modelContext = ModelContext(sharedModelContainer)
                    await deletionManager.processQueuedDeletions(modelContext: modelContext)
                }
            }
        }
    }

    private func stopNetworkMonitoring() {
        ServiceLocator.shared.networkMonitor.stopMonitoring()
    }
}
