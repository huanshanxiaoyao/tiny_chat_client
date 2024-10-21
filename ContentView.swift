import SwiftUI
import Speech
import AVFoundation

// 主视图，包含 TabView
struct ContentView: View {
 
    @StateObject private var courseDataManager: CourseDataManager
    @StateObject private var studyManager: StudyManager
    
    
    init() {
        let courseDataManager = CourseDataManager()
        _courseDataManager = StateObject(wrappedValue: courseDataManager)
        _studyManager = StateObject(wrappedValue: StudyManager(courseDataManager: courseDataManager))
    }

    
    var body: some View {
        TabView {
            ChatView()
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
        .environmentObject(studyManager) // 注入 StudyManager
    }
}

// 聊天视图
struct ChatView: View {
    @State private var inputText: String = ""
    @FocusState private var isInputActive: Bool
    @StateObject private var speechManager = SpeechRecognizerManager()

    @StateObject private var chatManager: ChatManager
    
    @EnvironmentObject var courseDataManager: CourseDataManager
    
    @EnvironmentObject var studyManager: StudyManager
    
    init() {
         // 使用 courseDataManager 初始化 chatManager
         _chatManager = StateObject(wrappedValue: ChatManager(postRequest: postRequest))
     }
    
    var body: some View {
        VStack {
            Text("Chat with Peter")
                .font(.title)
                .padding()

            MessageListView(messages: chatManager.messages)
                .onTapGesture {
                    isInputActive = false // 点击消息列表区域收起键盘
                }

            Divider()
        }
        .onAppear {
                   chatManager.courseDataManager = courseDataManager
                   chatManager.studyManager = studyManager
                   chatManager.startPolling()
               }
        .safeAreaInset(edge: .bottom) {
            InputBar(inputText: $inputText, sendAction: {
                chatManager.sendMessage(inputText: inputText)
                inputText = ""
            },
                     recordAction: speechManager.startRecording,
                     isRecording: $speechManager.isRecording,
                     isInputActive: $isInputActive)
            .padding()
            .background(Color(.systemBackground))
            .focused($isInputActive)
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
        @FocusState.Binding var isInputActive: Bool

        var body: some View {
            HStack {
                TextField("请输入消息", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputActive)
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

