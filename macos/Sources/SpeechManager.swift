import SwiftUI
import Speech
import Combine

class SpeechManager: ObservableObject {
    static let shared = SpeechManager()
    
    @Published var isRecording = false
    @Published var permissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var lastRecognizedText: String = ""
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.permissionStatus = status
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        // Cancel existing
        recognitionTask?.cancel()
        recognitionTask = nil
        lastRecognizedText = ""
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // Input Node
        let inputNode = audioEngine.inputNode
        
        // Task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            // Fix Duplicate Text: usage of 'endAudio()' triggers a final callback. 
            // If user manually stopped, 'isRecording' is false. Ignore this packet.
            if !self.isRecording { return }
            
            var isFinal = false
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                
                // Broadcast to Editor
                NotificationCenter.default.post(name: .dictationDidUpdate, object: nil, userInfo: [
                    "text": text,
                    "isFinal": isFinal
                ])
            }
            
            if error != nil || isFinal {
                self.stopRecording()
            }
        }
        
        // Audio Tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            NotificationCenter.default.post(name: .dictationDidStart, object: nil)
        } catch {
            print("Audio Engine start error: \(error)")
        }
    }
    
    func stopRecording() {
        if isRecording {
            // Mark as stopped FIRST to block any trailing "Final" packets from endAudio()
            isRecording = false 
            
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            
            NotificationCenter.default.post(name: .dictationDidEnd, object: nil)
        }
    }
}

extension Notification.Name {
    static let dictationDidStart = Notification.Name("dictationDidStart")
    static let dictationDidUpdate = Notification.Name("dictationDidUpdate")
    static let dictationDidEnd = Notification.Name("dictationDidEnd")
}
