//
//  NetworkMonitor.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/20.
//

import Foundation
import Network

protocol NetworkMonitorProtocol {
    var isConnected: Bool { get }
    func startMonitoring(onStatusChange: @escaping (Bool) -> Void)
    func stopMonitoring()
}

final class NetworkMonitor: NetworkMonitorProtocol {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private(set) var isConnected: Bool = false
    private var onStatusChange: ((Bool) -> Void)?

    init() {
        // 初期状態を取得
        let currentPath = monitor.currentPath
        self.isConnected = currentPath.status == .satisfied
    }

    func startMonitoring(onStatusChange: @escaping (Bool) -> Void) {
        self.onStatusChange = onStatusChange

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let connected = path.status == .satisfied

            // 状態が変わった場合のみコールバックを呼ぶ
            if self.isConnected != connected {
                self.isConnected = connected
                DispatchQueue.main.async {
                    onStatusChange(connected)
                }
            }
        }

        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
        onStatusChange = nil
    }
}
