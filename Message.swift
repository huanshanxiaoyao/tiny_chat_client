//
//  Message.swift
//  AIChatClient
//
//  Created by 苏冲 on 2024/10/14.
//

import Foundation

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}
