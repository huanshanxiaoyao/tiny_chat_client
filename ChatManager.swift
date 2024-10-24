import SwiftUI
import Combine

class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var alertModel = AlertModel()
    @Published var confirmationModel = ConfirmationModel()
    
    var courseDataManager: CourseDataManager?
    var studyManager: StudyManager?

    var postRequest: (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void
    private var timer: AnyCancellable?
   

    init(postRequest: @escaping (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void) {
        self.postRequest = postRequest
        startPolling()
    }
    

    func sendMessage(inputText: String) {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let userMessage = Message(content: trimmedText, isUser: true)
        messages.append(userMessage)

        let parameters = ["data": trimmedText, "userID": UserModel.shared.userID]

        postRequest("\(Config.baseURL)/dialogue", parameters) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.handleResponse(response)
                case .failure(let error):
                    self.alertModel.alertMessage = error.localizedDescription
                    self.alertModel.showAlert = true
                }
            }
        }
    }

    private func handleResponse(_ response: [String: Any]) {
        guard let courseDataManager = self.courseDataManager else {
            self.alertModel.alertMessage = "CourseDataManager 未设置。"
            self.alertModel.showAlert = true
            return
        }
        
        if let needConfirm = response["need_confirm"] as? Bool,
           let confirmStr = response["confirm_str"] as? String,
           let title = response["title"] as? String,
           let ssid = response["ssid"] as? String {

            if needConfirm {
                confirmationModel.currentTitle = title
                confirmationModel.currentSSID = ssid
                confirmationModel.confirmationMessage = confirmStr
                confirmationModel.showConfirmationDialog = true
            } else {
                let botMessage = Message(content: "任务添加成功：\(title)", isUser: false)
                messages.append(botMessage)
            }
        } else {
            alertModel.alertMessage = "无效的响应格式"
            alertModel.showAlert = true
        }
    }

    func startPolling() {
        guard courseDataManager != nil else { return }
        timer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForNewMessages()
            }
    }

    func stopPolling() {
        timer?.cancel()
        timer = nil
    }
    
    private func checkForNewMessages() {
        guard let courseDataManager = self.courseDataManager else { return }
        
        let url = "\(Config.baseURL)/check"
        let parameters = ["userID": UserModel.shared.userID]
        postRequest(url, parameters) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                        // 如果存在 new_message 字段，处理 new_message 内容
                        if let newMessageContent = response["new_message"] as? String, !newMessageContent.isEmpty {
                            let botMessage = Message(content: newMessageContent, isUser: false)
                            self.messages.append(botMessage)
                        }
                        
                            if let courseTitle = response["course_title"] as? String,
                               let courseId = response["course_id"] as? Int,
                               let outlineContent = response["outline_content"] as? String, !outlineContent.isEmpty {
                                
                                // 将 outline_content 解析为 [OutlineItem]
                                var outlineItems: [OutlineItem] = []
                                
                                if let data = outlineContent.data(using: .utf8) {
                                    do {
                                        if let outlineDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [Any]] {
                                            for (key, value) in outlineDict {
                                                if let id = Int(key),
                                                   value.count >= 2,
                                                   let subTitle = value[0] as? String,
                                                   let content = value[1] as? String {
                                                    let outlineItem = OutlineItem(id: id, subTitle: subTitle, content: content, status: 0)
                                                    outlineItems.append(outlineItem)
                                                }
                                            }
                                        }
                                    } catch {
                                        print("解析 outline_content 失败: \(error)")
                                    }
                                }
                                // 创建新的 Course 对象
                                let newCourse = Course(id: courseId, title: courseTitle, outline: outlineItems)
                                
                                // 使用 CourseDataManager 保存新课程
                                DispatchQueue.main.async {
                                    courseDataManager.addOrUpdateCourse(id: courseId, title: courseTitle, outlineContent: outlineItems)
                                }

                                // 在消息中追加一条关于 outline_content 的消息（可选）
                                let outlineMessage = Message(content: outlineContent, isUser: false)
                                self.messages.append(outlineMessage)
                            }
                // 如果成功保存课程数据，弹出确认框询问用户是否开始学习
                if let courseTitle = response["course_title"] as? String,
                   let courseId = response["course_id"] as? Int {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "开始学习", message: "是否开始学习 \(courseTitle) 的第1节？", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                            // 用户确认后，发送学习请求
                            self.startStudy(courseId: courseId, outlineItemId: 0)
                        })
                        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            rootViewController.present(alert, animated: true)
                        }
                    }
                }
                case .failure(let error):
                    print("检查新消息时出错: \(error.localizedDescription)")
                }
            }
        }
    }

    func startStudy(courseId: Int, outlineItemId: Int) {
        guard let studyManager = self.studyManager else {
            self.alertModel.alertMessage = "StudyManager 未设置。"
            self.alertModel.showAlert = true
            return
        }
        
        studyManager.startStudy(courseId: courseId, outlineItemId: outlineItemId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let content):
                // 添加消息到对话列表
                let botMessage = Message(content: content, isUser: false)
                self.messages.append(botMessage)
                self.objectWillChange.send()
            case .failure(let error):
                self.alertModel.alertMessage = "学习请求失败: \(error.localizedDescription)"
                self.alertModel.showAlert = true
            }
        }
    }

}
