//
//  UserModel.swift
//  AIChatClient2
//
//  Created by 苏冲 on 2024/10/16.
//

import Foundation
import UIKit

class UserModel: ObservableObject {
    @Published var userID: String

    static let shared = UserModel()

    private init() {
        // 删除之前保存的用户标识符（确保生成新的）
               UserDefaults.standard.removeObject(forKey: "userID")
        
        if let savedUserID = UserDefaults.standard.string(forKey: "userID") {
            // 如果用户标识符已存在，从存储中读取
            self.userID = savedUserID
        } else {
            // 生成新的用户标识符并保存
            self.userID = UserModel.generateUniqueUserID()
            UserDefaults.standard.set(self.userID, forKey: "userID")
        }
    }

    // 生成唯一设备标识符的方法
    private static func generateUniqueUserID() -> String {
        let lowerBound = 10000000
        let upperBound = 99999999
        let randomID = Int.random(in: lowerBound...upperBound)
        return String(randomID)
    }
}
