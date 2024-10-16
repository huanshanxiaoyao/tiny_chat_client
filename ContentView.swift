import SwiftUI
import Speech
import AVFoundation

struct ContentView: View {
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isRecording = false
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?

    // 新增的状态变量
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showConfirmationDialog = false
    @State private var confirmationMessage = ""
    @State private var currentTitle = ""
    @State private var currentSSID = ""

    var body: some View {
        VStack {
            MessageListView(messages: messages)
            Divider()
            InputBar(inputText: $inputText, sendAction: sendMessage, recordAction: startRecording, isRecording: $isRecording).padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("错误"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
        .alert(isPresented: $showConfirmationDialog) {
            Alert(
                title: Text("请确认"),
                message: Text(confirmationMessage),
                primaryButton: .default(Text("Yes"), action: {
                    // 用户点击了 Yes，发送确认请求
                    let parameters = ["title": currentTitle, "ssid": currentSSID]
                    postRequest(urlString: "http://192.168.31.74:5001/confirm", parameters: parameters) { result in
                        switch result {
                        case .success(let response):
                            DispatchQueue.main.async {
                                let botMessage = Message(content: "确认成功：\(response)", isUser: false)
                                messages.append(botMessage)
                            }
                        case .failure(let error):
                            alertMessage = error.localizedDescription
                            showAlert = true
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

    // 发送消息的函数
    func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        let userMessage = Message(content: trimmedText, isUser: true)
        messages.append(userMessage)
        inputText = ""

        // 准备请求参数
        let parameters = ["data": trimmedText]

        // 发送 POST 请求到后端
        postRequest(urlString: "http://192.168.31.74:5001/dialogue", parameters: parameters) { result in
            switch result {
            case .success(let response):
                if let needConfirm = response["need_confirm"] as? Bool,
                   let confirmStr = response["confirm_str"] as? String,
                   let title = response["title"] as? String,
                   let ssid = response["ssid"] as? String {

                    if needConfirm {
                        // 需要用户确认，更新状态变量
                        currentTitle = title
                        currentSSID = ssid
                        confirmationMessage = confirmStr
                        showConfirmationDialog = true
                    } else {
                        // 不需要确认，直接处理
                        DispatchQueue.main.async {
                            let botMessage = Message(content: "任务添加成功：\(title)", isUser: false)
                            messages.append(botMessage)
                        }
                    }
                } else {
                    // 响应格式不正确
                    alertMessage = "无效的响应格式"
                    showAlert = true
                }
            case .failure(let error):
                // 请求失败，显示错误信息
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    // 开始或停止录音
    func startRecording() {
        if isRecording {
            stopRecording()
        } else {
            requestSpeechAuthorization()
        }
    }

    // 请求语音识别权限
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            if authStatus == .authorized {
                startSpeechRecognition()
            } else {
                print("语音识别权限被拒绝")
            }
        }
    }

    // 开始语音识别
    func startSpeechRecognition() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("音频会话配置失败：\(error.localizedDescription)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("无法创建识别请求")
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        guard let speechRecognizer = speechRecognizer else {
            print("无法创建语音识别器")
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result,error in
            if let result = result {
                DispatchQueue.main.async {
                    inputText = result.bestTranscription.formattedString
                }
            }
            if let error = error {
                print("识别任务出错：\(error.localizedDescription)")
                stopRecording()
            } else if result?.isFinal == true {
                stopRecording()
            }
        }

        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                isRecording = true
            }
        } catch {
            print("音频引擎启动失败：\(error.localizedDescription)")
        }
    }

    // 停止语音识别
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
}

// 消息列表视图
struct MessageListView: View {
    let messages: [Message]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageView(message: message)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

// 单条消息视图
struct MessageView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                TextBubble(text: message.content, isUser: true)
            } else {
                TextBubble(text: message.content, isUser: false)
                Spacer()
            }
        }
        .id(message.id)
    }
}

// 消息气泡视图
struct TextBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        Text(text)
            .padding()
            .background(isUser ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isUser ? .white : .black)
            .cornerRadius(16)
            .frame(maxWidth: 250, alignment: isUser ? .trailing : .leading)
    }
}

// 输入栏视图
struct InputBar: View {
    @Binding var inputText: String
    var sendAction: () -> Void
    var recordAction: () -> Void
    @Binding var isRecording: Bool

    var body: some View {
        HStack {
            TextField("请输入消息", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: sendAction) {
                Image(systemName: "paperplane.fill")
                    .rotationEffect(.degrees(45))
                    .padding()
            }
            Button(action: recordAction) {
                Image(systemName: isRecording ? "mic.circle.fill" : "mic.fill")
                    .padding()
                    .foregroundColor(isRecording ? .red : .blue)
            }
        }
    }
}





    
