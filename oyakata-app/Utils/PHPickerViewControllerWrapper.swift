//
//  PHPickerViewControllerWrapper.swift
//  oyakata-app
//
//  Created by Claude on 2025/12/21.
//

import SwiftUI
import PhotosUI

struct PHPickerViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let maxSelectionCount: Int
    let onSelection: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = maxSelectionCount
        config.filter = .images
        config.preferredAssetRepresentationMode = .current // 元のフォーマット保持

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // PHPickerViewControllerは設定変更をサポートしないため、何もしない
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerViewControllerWrapper

        init(parent: PHPickerViewControllerWrapper) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.onSelection(results)
            parent.isPresented = false
        }
    }
}
