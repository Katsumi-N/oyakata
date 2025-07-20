//
//  ContentView.swift
//  oyakata-app
//
//  Created by 納谷克海 on 2025/06/13.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingMigrationAlert = false
    
    var body: some View {
        TabView {
            NavigationView {
                ImageGridView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Image(systemName: "doc.on.doc")
                    Text("図面一覧")
                }
            
            NavigationView {
                MissListView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("ミスリスト")
                }
        }
        .onAppear {
            // マイグレーションの確認
            checkForMigration()
        }
        .alert("データベース更新", isPresented: $showingMigrationAlert) {
            Button("OK") { }
        } message: {
            Text("アプリが更新されました。古いデータとの互換性のため、データベースがリセットされています。")
        }
    }
    
    private func checkForMigration() {
        // UserDefaultsを使用してマイグレーションの実行を記録
        let migrationKey = "database_migration_v2_completed"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            showingMigrationAlert = true
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(for: ImageData.self, inMemory: true)
}
