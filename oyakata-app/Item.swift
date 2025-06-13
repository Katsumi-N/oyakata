//
//  Item.swift
//  oyakata-app
//
//  Created by 納谷克海 on 2025/06/13.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
