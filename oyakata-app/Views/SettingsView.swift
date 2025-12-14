//
//  SettingsView.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/13.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var deviceId: String = "読み込み中..."
    @State private var showCopiedAlert = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.gray)
                }

                HStack {
                    Text("ビルド")
                    Spacer()
                    Text(buildVersion)
                        .foregroundColor(.gray)
                }

                HStack {
                    Text("Device ID")
                    Spacer()
                    Text(deviceId)
                        .foregroundColor(.gray)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .onTapGesture {
                    UIPasteboard.general.string = deviceId
                    showCopiedAlert = true
                }
            } header: {
                Text("アプリ情報")
            } footer: {
                Text("Device IDをタップするとコピーできます。")
            }
        }
        .navigationTitle("設定")
        .task {
            await loadDeviceId()
        }
        .alert("コピーしました", isPresented: $showCopiedAlert) {
            Button("OK") { }
        } message: {
            Text("Device IDをクリップボードにコピーしました。")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明"
    }

    private var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明"
    }

    @MainActor
    private func loadDeviceId() async {
        let credentials = await services.authManager.getCurrentCredentials()
        if let credentials = credentials {
            deviceId = credentials.deviceId
        } else {
            deviceId = "未登録"
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(ServiceContainer.shared)
    }
}
