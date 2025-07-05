//
//  ContentView.swift
//  oyakata-app
//
//  Created by 納谷克海 on 2025/06/13.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationView {
                ImageGridView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("画像管理")
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
    }
}


#Preview {
    ContentView()
        .modelContainer(for: ImageData.self, inMemory: true)
}
