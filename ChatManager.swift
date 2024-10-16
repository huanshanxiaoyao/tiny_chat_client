import SwiftUI

class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var alertModel = AlertModel()
    @Published var confirmationModel = ConfirmationModel()
    
    var postRequest: (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void

    init(postRequest: @escaping (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void) {
        self.postRequest = postRequest
    }

    func sendMessage(inputText: String) {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let userMessage = Message(content: trimmedText, isUser: true)
        messages.append(userMessage)

        // 准备请求参数
        let parameters = ["data": trimmedText]

        // 发送 POST 请求到后端
        postRequest("\(Config.baseURL)/dialogue", parameters) { result in
            switch result {
            case .success(let response):
                if let needConfirm = response["need_confirm"] as? Bool,
                   let confirmStr = response["confirm_str"] as? String,
                   let title = response["title"] as? String,
                   let ssid = response["ssid"] as? String {

                    if needConfirm {
                        // 需要用户确认，更新状态变量
                        DispatchQueue.main.async {
                            self.confirmationModel.currentTitle = title
                            self.confirmationModel.currentSSID = ssid
                            self.confirmationModel.confirmationMessage = confirmStr
                            self.confirmationModel.showConfirmationDialog = true
                        }
                    } else {
                        // 不需要确认，直接处理
                        DispatchQueue.main.async {
                            let botMessage = Message(content: "任务添加成功：\(title)", isUser: false)
                            self.messages.append(botMessage)
                        }
                    }
                } else {
                    // 响应格式不正确
                    DispatchQueue.main.async {
                        self.alertModel.alertMessage = "无效的响应格式"
                        self.alertModel.showAlert = true
                    }
                }
            case .failure(let error):
                // 请求失败，显示错误信息
                DispatchQueue.main.async {
                    self.alertModel.alertMessage = error.localizedDescription
                    self.alertModel.showAlert = true
                }
            }
        }
    }
}

