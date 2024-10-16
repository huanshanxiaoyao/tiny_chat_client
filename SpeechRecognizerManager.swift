//
//  SpeechRecognizerManager.swift
//  AIChatClient2
//
//  Created by 苏冲 on 2024/10/16.
//

import Foundation
import Speech
import AVFoundation

class SpeechRecognizerManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText: String = ""

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override init() {
        super.init()
    }

    func startRecording() {
        if isRecording {
            stopRecording()
        } else {
            requestSpeechAuthorization()
        }
    }

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self?.startSpeechRecognition()
                } else {
                    print("语音识别权限被拒绝")
                }
            }
        }
    }

    private func startSpeechRecognition() {
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

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.recognizedText = result.bestTranscription.formattedString
                }
            }
            if let error = error {
                print("识别任务出错：\(error.localizedDescription)")
                self?.stopRecording()
            } else if result?.isFinal == true {
                self?.stopRecording()
            }
        }

        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            print("音频引擎启动失败：\(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
}

