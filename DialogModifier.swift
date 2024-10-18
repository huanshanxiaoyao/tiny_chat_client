//
//  DialogModifier.swift
//  AIChatClient2
//
//  Created by 苏冲 on 2024/10/16.
//

import SwiftUI

struct ConfirmationDialogModifier: ViewModifier {
    @ObservedObject var confirmationModel: ConfirmationModel
    @ObservedObject var alertModel: AlertModel
    @Binding var messages: [Message]
    
    var postRequest: (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void

    func body(content: Content) -> some View {
        content
            .alert(isPresented: $confirmationModel.showConfirmationDialog) {
                Alert(
                    title: Text("请确认"),
                    message: Text(confirmationModel.confirmationMessage),
                    primaryButton: .default(Text("Yes"), action: {
                        // 用户点击了 Yes，发送确认请求
                        let parameters = ["title": confirmationModel.currentTitle,
                                          "ssid": confirmationModel.currentSSID,
                                          "userID": UserModel.shared.userID]
                        postRequest("\(Config.baseURL)/confirm", parameters) { result in
                            switch result {
                            case .success(let response):
                                DispatchQueue.main.async {
                                    let botMessage = Message(content: "确认成功, 将为你准备教案：\(response)", isUser: false)
                                    messages.append(botMessage)
                                }
                            case .failure(let error):
                                // 显示错误信息
                                alertModel.alertMessage = error.localizedDescription
                                alertModel.showAlert = true
                                
                            }
                        }
                    }),
                    secondaryButton: .cancel(Text("No"), action: {
                        // 用户点击了 No，可以执行其他操作
                        DispatchQueue.main.async {
                            let botMessage = Message(content: "用户取消了确认操作。", isUser: false)
                            messages.append(botMessage)
                        }
                    })
                )
            }
    }
}

