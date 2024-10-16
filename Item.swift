//
//  Item.swift
//  AIChatClient2
//
//  Created by 苏冲 on 2024/10/14.
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
