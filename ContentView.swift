import SwiftUI
import Speech
import AVFoundation

// 主视图，包含 TabView
struct ContentView: View {
 
    @StateObject private var courseDataManager = CourseDataManager()
    
    var body: some View {
        TabView {
            ChatView(courseDataManager: courseDataManager)
                .tabItem {
                    Image(systemName: "message")
                    Text("聊天")
                }
            CourseView()
                .tabItem {
                    Image(systemName: "book")
                    Text("课程")
                }
        }
        .environmentObject(courseDataManager) // 注入 CourseDataManager
    }
}

// 聊天视图
struct ChatView: View {
    @State private var inputText: String = ""
    @StateObject private var speechManager = SpeechRecognizerManager()
    @StateObject private var chatManager: ChatManager
    @EnvironmentObject var courseDataManager: CourseDataManager
    
    init(courseDataManager: CourseDataManager) {
         // 使用 courseDataManager 初始化 chatManager
         _chatManager = StateObject(wrappedValue: ChatManager(postRequest: postRequest, courseDataManager: courseDataManager))
     }
    
    var body: some View {
        VStack {
            Text("Chat with Peter")
                .font(.title)
                .padding()

            MessageListView(messages: chatManager.messages)

            Divider()

    
        }
        .safeAreaInset(edge: .bottom) {
            InputBar(inputText: $inputText, sendAction: {
                chatManager.sendMessage(inputText: inputText)
                inputText = ""},
                     recordAction: speechManager.startRecording,
                     isRecording: $speechManager.isRecording)
            .padding()
            .background(Color(.systemBackground))
        }
        .onAppear {
                   // 更新 chatManager 的 courseDataManager 为环境中的实例
                   chatManager.courseDataManager = courseDataManager
               }
        .alert(isPresented: $chatManager.alertModel.showAlert) {
            Alert(title: Text("错误"), message: Text(chatManager.alertModel.alertMessage), dismissButton: .default(Text("确定")))
        }
        .modifier(ConfirmationDialogModifier(
            confirmationModel: chatManager.confirmationModel,
            alertModel: chatManager.alertModel,
            messages: $chatManager.messages,
            postRequest: chatManager.postRequest))
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
}



