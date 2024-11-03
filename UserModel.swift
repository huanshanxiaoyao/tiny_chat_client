//
//  UserModel.swift
//  AIChatClient2
//
//  Created by 苏冲 on 2024/10/16.
//

import Foundation
import UIKit
import CryptoKit
import KeychainAccess

class UserModel: ObservableObject {
    @Published var userID: String

    static let shared = UserModel()
    private let keychain = Keychain(service: "com.AandB.123456")

    private init() {
        // 尝试从 Keychain 中读取用户标识符
        if let savedUserID = keychain["userID"] {
            // 如果用户标识符已存在，从 Keychain 中读取
            self.userID = savedUserID
            print("get userID from keychain success\(savedUserID)")
        } else {
            // 生成新的用户标识符并保存到 Keychain
            self.userID = UserModel.generateUniqueUserID()
            keychain["userID"] = self.userID
        }
    }

    private static func generateUniqueUserID() -> String {
        // 获取设备的 identifierForVendor 作为基础标识符
        guard let vendorID = UIDevice.current.identifierForVendor?.uuidString else {
            // 如果无法获取设备标识符，则返回一个随机8位数
            return String(Int.random(in: 10000000...99999999))
        }
        print("get vendorID success\(vendorID.utf8)")
        
        // 使用 SHA256 哈希处理设备标识符
        let hash = SHA256.hash(data: Data(vendorID.utf8))
        
        // 取哈希结果的前几位，并转换为 8 位整数
        let hashValue = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // 提取前 8 位数字并转换为整数
        let numericHash = hashValue.compactMap { $0.wholeNumberValue }.prefix(8)
        var uid = numericHash.map(String.init).joined()
        
        // 如果生成的 UID 不够 8 位，使用随机数补全
        while uid.count < 8 {
            uid += String(Int.random(in: 0...9))
        }

        return uid
    }
}

