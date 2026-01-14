import Foundation
import Speech
import AVFoundation
import Combine

class SpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var error: String?
    
    private let speechRecognizer: SFSpeechRecognizer? = {
        if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW")) {
            return recognizer
        }
        return SFSpeechRecognizer() // Fallback to system locale
    }()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.error = nil
                case .denied:
                    self.error = "請在設定中開啟語音辨識權限"
                case .restricted:
                    self.error = "此裝置受限，無法使用語音辨識"
                case .notDetermined:
                    self.error = "權限尚未決定"
                @unknown default:
                    self.error = "未知錯誤"
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.error = "請在設定中開啟麥克風權限"
                }
            }
        }
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            if status == .authorized {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    func startRecording() throws {
        if isRecording { return }
        
        // Reset state
        DispatchQueue.main.async {
            self.transcribedText = ""
            self.error = nil
        }
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法創建辨識請求"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Setup input node
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 {
            throw NSError(domain: "SpeechManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "音訊引擎格式錯誤"])
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "SpeechManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "語音辨識目前不可用"])
        }
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.isRecording = false
                    }
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    // Only report if it's not a cancellation
                    let nsError = error as NSError
                    if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 4 {
                        self.error = "辨識發生錯誤: \(error.localizedDescription)"
                    }
                    self.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        if !isRecording { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.finish() // Use finish() instead of cancel() for better cleanup
        
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
