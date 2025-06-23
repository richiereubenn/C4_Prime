//
//  TextToSpeechService.swift
//  TextToSpeech
//
//  Created by Jesus Cruz Suárez on 14/10/24.
//

import AVFAudio
import Foundation

protocol TextToSpeechServiceProtocol {
    func speak(text: String, withVoice voiceIdentifier: String?, completion: @escaping (Result<Void, TextToSpeechError>) -> Void)
    func stopSpeaking()
    var isSpeaking: Bool { get } // Tambahkan properti untuk mengecek status
}

enum TextToSpeechError: Error {
    case audioSessionSetupFailed
    case audioSessionDeactivationFailed(String)
    case speechSynthesisFailed
    case speakAlreadyInProgress // Tambahan error jika ingin memberitahu caller

    var message: String {
        switch self {
        case .audioSessionSetupFailed:
            return "Failed to set up the audio session. Please check the audio settings and try again."
        case .audioSessionDeactivationFailed(let details):
            return "Failed to deactivate the audio session: \(details)"
        case .speechSynthesisFailed:
            return "Speech synthesis failed. Please check if the text or voice parameters are correct."
        case .speakAlreadyInProgress:
            return "A speech is already in progress. Please wait or stop it first."
        }
    }
}

class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate, TextToSpeechServiceProtocol {
    private var synthesizer: AVSpeechSynthesizer
    // Mengubah completion menjadi Result untuk penanganan error yang lebih baik
    private var currentCompletion: ((Result<Void, TextToSpeechError>) -> Void)?
    private var currentUtterance: AVSpeechUtterance?
    
    // Properti baru untuk mengecek status bicara
    var isSpeaking: Bool {
        return synthesizer.isSpeaking
    }

    override init() {
        synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
    }
    
    /// Speaks the given text using a specified voice, if provided.
    /// - Parameters:
    ///   - text: The text to be converted into speech.
    ///   - voiceIdentifier: The identifier for the voice to use. If `nil`, the device’s default language will be used.
    ///   - completion: A closure that is executed when the speech finishes or an error occurs.
    @MainActor
    func speak(text: String, withVoice voiceIdentifier: String? = nil, completion: @escaping (Result<Void, TextToSpeechError>) -> Void) {
        // Jika sedang berbicara, jangan mulai yang baru dari sini.
        // Biarkan manajemen antrean di layer yang lebih tinggi.
        guard !synthesizer.isSpeaking else {
            completion(.failure(.speakAlreadyInProgress)) // Beri tahu caller bahwa sudah ada bicara
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            completion(.failure(.audioSessionSetupFailed))
            return
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        if let voiceId = voiceIdentifier, let selectedVoice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = selectedVoice
        } else {
            let defaultLanguage = Locale.current.language.languageCode?.identifier ?? "en-US"
            utterance.voice = AVSpeechSynthesisVoice(language: defaultLanguage)
        }
        
        // Tidak perlu menghentikan suara di sini, karena guard di atas sudah memastikan
        // bahwa kita hanya mulai jika tidak sedang berbicara.
        // Jika kamu ingin fitur "menginterupsi", itu akan ditambahkan di layer manager antrean.
        
        self.currentUtterance = utterance
        self.currentCompletion = completion // Simpan completion handler
        
        synthesizer.speak(utterance)
    }
    
    /// Stops the current speech if it is in progress.
    @MainActor
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            // Delegate method will be called for cancellation,
            // which will handle clearing currentUtterance and currentCompletion.
            // No need to explicitly call restoreAudioSession here,
            // it will be handled by the next speak call or manual deactivation.
        }
    }
    
    /// Restores the audio session to its inactive state.
    private func restoreAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ini akan ditangkap oleh closure completion atau diproses secara internal
            print("Failed to deactivate audio session: \(error.localizedDescription)")
            // Jika ada currentCompletion, panggil dengan error
            currentCompletion?(.failure(.audioSessionDeactivationFailed(error.localizedDescription)))
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if utterance == currentUtterance {
            restoreAudioSession()
            currentCompletion?(.success(())) // Panggil completion dengan success
            self.currentUtterance = nil
            self.currentCompletion = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if utterance == currentUtterance {
            // Tidak perlu restoreAudioSession di sini karena ini adalah pembatalan,
            // dan session mungkin masih diperlukan oleh speak() berikutnya atau akan dinonaktifkan secara manual.
            currentCompletion?(.failure(.speechSynthesisFailed)) // Beri tahu bahwa dibatalkan
            self.currentUtterance = nil
            self.currentCompletion = nil
        }
    }
}


// Struktur untuk menyimpan permintaan TTS
struct QueuedSpeechRequest {
    let text: String
    let voiceIdentifier: String?
    let priority: DispatchQoS.QoSClass // Tambahkan prioritas
    let completion: ((Result<Void, TextToSpeechError>) -> Void)? // Optional
}

class SpeechQueueManager: ObservableObject {
    private var callCount = 0
    private var callCountper = 15
    
    static let shared = SpeechQueueManager() // Singleton
    
    private let ttsService: TextToSpeechServiceProtocol // Gunakan protokol
    private var speechQueue: [QueuedSpeechRequest] = []
    private let queueAccess = DispatchQueue(label: "com.yourapp.speechQueueAccess", attributes: .concurrent) // Concurrent queue for thread-safe access
    private var isProcessingQueue: Bool = false // Flag untuk menghindari pemrosesan ganda

    // Inisialisasi dengan TextToSpeechService actual
    private init(ttsService: TextToSpeechService = TextToSpeechService()) {
        self.ttsService = ttsService
    }
    
    private func increaseCallCount() {
        if callCount % callCountper == 0 || callCount == callCountper * 3 {
            callCount = 0
            return
        }
        callCount += 1
        
    }

    /// Menambahkan permintaan bicara ke antrean.
    /// - Parameters:
    ///   - text: Teks yang akan diucapkan.
    ///   - voiceIdentifier: Identifier suara.
    ///   - priority: Prioritas QoS untuk permintaan ini.
    ///   - interruptCurrent: Jika true, akan menghentikan ucapan saat ini dan memprioritaskan yang baru.
    ///   - completion: Closure yang dipanggil saat ucapan selesai atau gagal.
    func enqueueSpeech(text: String, voiceIdentifier: String? = nil, priority: DispatchQoS.QoSClass = .utility, interruptCurrent: Bool = false, completion: ((Result<Void, TextToSpeechError>) -> Void)? = nil) {
        
        let request = QueuedSpeechRequest(text: text, voiceIdentifier: voiceIdentifier, priority: priority, completion: completion)

        queueAccess.async(flags: .barrier) { [weak self] in // Gunakan barrier untuk modifikasi array
            guard let self = self else { return }

            if interruptCurrent && self.ttsService.isSpeaking {
                self.ttsService.stopSpeaking() // Hentikan yang sedang berjalan
                self.speechQueue.removeAll() // Kosongkan antrean jika ada interupsi
                print("SpeechQueueManager: Current speech interrupted and queue cleared.")
            } else if self.ttsService.isSpeaking {
                // Jika sedang berbicara dan tidak ada interupsi, tambahkan ke antrean berdasarkan prioritas
                if self.callCount == 0 || self.speechQueue.last?.text != request.text{
                    print("CALLED UPSSS CUY")
                    self.insertIntoQueue(request)
                    print("SpeechQueueManager: Added to queue (not interrupting). Current queue size: \(self.speechQueue.count)")
                    return // Jangan proses sekarang, biarkan yang sedang berjalan selesai
                }
            }
            
            // Jika tidak sedang berbicara atau baru saja diinterupsi, tambahkan dan mulai proses
            if self.callCount == 0 || self.speechQueue.last?.text != request.text{
                print("CALLED HERE", callCount , request.text)
                self.speechQueue.append(request)
                print("SpeechQueueManager: Added to queue. Current queue size: \(self.speechQueue.count)")
                self.processNextSpeech()
            }
        }
    }

    // Memasukkan permintaan ke antrean berdasarkan prioritas
    private func insertIntoQueue(_ newRequest: QueuedSpeechRequest) {
        // Prioritas lebih tinggi harus di depan (indeks lebih kecil)
        // AVSpeechSynthesizer QosClass values: userInteractive > userInitiated > default > utility > background
        if let index = speechQueue.firstIndex(where: { $0.priority.rawValue.rawValue < newRequest.priority.rawValue.rawValue }) {
            speechQueue.insert(newRequest, at: index)
        } else {
            speechQueue.append(newRequest)
        }
    }

    /// Memulai proses ucapan berikutnya dari antrean.
    /// Ini akan dipanggil setelah ucapan selesai atau saat ada permintaan baru dan tidak ada ucapan yang berjalan.
    private func processNextSpeech() {
        queueAccess.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Pastikan hanya satu instance prosesor yang berjalan
            guard !self.isProcessingQueue else { return }
            self.isProcessingQueue = true

            // Lanjutkan di main thread karena AVSpeechSynthesizer perlu itu
            Task { @MainActor in
                guard !self.speechQueue.isEmpty else {
                    self.isProcessingQueue = false
                    return
                }

                let request = self.speechQueue.removeFirst()
                print("SpeechQueueManager: Processing next speech: \"\(request.text)\"")

                self.ttsService.speak(text: request.text, withVoice: request.voiceIdentifier) { [weak self] result in
                    guard let self = self else { return }
                    
                    // Panggil completion handler asli dari request
                    request.completion?(result)

                    // Setelah selesai (sukses/gagal/batal), proses item berikutnya
                    self.isProcessingQueue = false // Setel ulang flag
                    self.processNextSpeech() // Rekursif panggil untuk item berikutnya
                }
            }
        }
    }
    
    /// Menghentikan semua ucapan yang sedang berjalan dan mengosongkan antrean.
    func stopAllSpeech() {
        queueAccess.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.ttsService.stopSpeaking()
            self.speechQueue.removeAll()
            self.isProcessingQueue = false // Reset flag
            print("SpeechQueueManager: All speech stopped and queue cleared.")
        }
    }
}
