//
//  TagType.swift
//  oyakata-app
//
//  Created by Claude on 2025/06/13.
//

import Foundation

enum TagType: String, CaseIterable, Codable {
    case questionPaper = "問題用紙"
    case redMarkedPaper = "赤入れした問題用紙"
    case sketchExample = "エスキスの例"
    case sketch = "エスキス"
    case drawing = "製図"
    case answerExample = "解答例"
    
    var displayName: String {
        return self.rawValue
    }
    
    var systemImage: String {
        switch self {
        case .questionPaper:
            return "doc.text"
        case .redMarkedPaper:
            return "doc.text.fill"
        case .sketchExample:
            return "pencil.and.outline"
        case .sketch:
            return "pencil"
        case .drawing:
            return "ruler"
        case .answerExample:
            return "checkmark.circle"
        }
    }
}