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
    // Tidak lagi menggunakan priority DispatchQoS.QoSClass untuk keputusan antrean di sini,
    // karena kita akan lebih fokus pada "terbaru" vs "lama" untuk realtime.
    // Namun, kita bisa tetap meneruskan QoS ke speak() method jika dibutuhkan untuk scheduling task.
    let qos: DispatchQoS.QoSClass
    let completion: ((Result<Void, TextToSpeechError>) -> Void)? // Optional
    let timestamp: Date // Tambahkan timestamp untuk melacak kapan pesan dibuat
}

class SpeechQueueManager: ObservableObject {
    static let shared = SpeechQueueManager() // Singleton
    
    private let ttsService: TextToSpeechServiceProtocol // Gunakan protokol
    // Kita akan menggunakan Array, tapi dengan logika yang berbeda untuk penanganan
    private var speechQueue: [QueuedSpeechRequest] = []
    
    // Gunakan DispatchQueue.main untuk memastikan semua interaksi UI dan AVSpeechSynthesizer di main thread.
    // Ini juga menyederhanakan sinkronisasi karena AVSpeechSynthesizer memang membutuhkan main thread.
    private let queueAccess = DispatchQueue.main // Semua operasi akan di Main Thread
    
    private var isProcessingQueue: Bool = false // Flag untuk menghindari pemrosesan ganda
    
    // Threshold untuk mencegah spamming feedback yang sama dalam waktu singkat
    private let minimumTimeBetweenSameFeedback: TimeInterval = 2.0 // Minimal 1 detik antar feedback yang sama
    private var lastSpokenFeedback: (text: String, timestamp: Date)?

    // Inisialisasi dengan TextToSpeechService actual
    private init(ttsService: TextToSpeechService = TextToSpeechService()) {
        self.ttsService = ttsService
    }
    
    /// Menambahkan permintaan bicara ke antrean dengan strategi realtime.
    /// - Parameters:
    ///   - text: Teks yang akan diucapkan.
    ///   - voiceIdentifier: Identifier suara.
    ///   - qos: Quality of Service untuk task yang akan berbicara.
    ///   - forceSpeak: Jika true, akan memaksa ucapan ini untuk diputar segera, menghentikan yang sedang berjalan.
    ///                 Jika false, akan mengikuti logika smart queue (replace/ignore).
    ///   - completion: Closure yang dipanggil saat ucapan selesai atau gagal.
    func enqueueSpeech(text: String, voiceIdentifier: String? = nil, priority: DispatchQoS.QoSClass = .utility, forceSpeak: Bool = false, completion: ((Result<Void, TextToSpeechError>) -> Void)? = nil) {
        
        // Pastikan operasi di main queue, karena AVSpeechSynthesizer membutuhkannya
        queueAccess.async { [weak self] in
            guard let self = self else { return }
            
            let newRequest = QueuedSpeechRequest(text: text, voiceIdentifier: voiceIdentifier, qos: priority, completion: completion, timestamp: Date())

            // Logika untuk mencegah spamming feedback yang sama dalam waktu singkat
            if let last = self.lastSpokenFeedback, last.text == newRequest.text {
                if Date().timeIntervalSince(last.timestamp) < self.minimumTimeBetweenSameFeedback {
                    print("SpeechQueueManager: Mengabaikan feedback yang sama terlalu cepat: \"\(newRequest.text)\"")
                    completion?(.success(())) // Anggap berhasil agar caller tidak stuck
                    return
                }
            }

            if forceSpeak {
                // Jika forceSpeak, hentikan semua yang sedang berjalan dan di antrean, lalu mulai yang baru.
                self.ttsService.stopSpeaking()
                self.speechQueue.removeAll()
                self.speechQueue.append(newRequest)
                print("SpeechQueueManager: Force speaking \"\(newRequest.text)\". Queue cleared.")
                self.processNextSpeech()
            } else {
                // Jika tidak forceSpeak, implementasikan strategi "replace oldest if not speaking, otherwise ignore if queue full"
                if self.ttsService.isSpeaking {
                    // Jika sedang berbicara, kita tidak ingin menumpuk.
                    // Prioritaskan yang terbaru: ganti pesan yang sedang menunggu jika ada, atau tambahkan jika antrean kosong.
                    // Untuk realtime, kita hanya ingin 0 atau 1 pesan di antrean setelah yang sedang diputar.
                    if self.speechQueue.isEmpty {
                        self.speechQueue.append(newRequest)
                        print("SpeechQueueManager: Added to single-slot queue: \"\(newRequest.text)\"")
                    } else {
                        // Jika sudah ada pesan menunggu (max 1), ganti dengan yang terbaru
                        self.speechQueue[0] = newRequest
                        print("SpeechQueueManager: Replaced pending message with: \"\(newRequest.text)\"")
                    }
                } else {
                    // Jika tidak sedang berbicara, langsung tambahkan dan proses
                    self.speechQueue.append(newRequest)
                    print("SpeechQueueManager: No current speech, added and processing: \"\(newRequest.text)\"")
                    self.processNextSpeech()
                }
            }
        }
    }

    /// Memulai proses ucapan berikutnya dari antrean.
    /// Ini akan dipanggil setelah ucapan selesai atau saat ada permintaan baru dan tidak ada ucapan yang berjalan.
    private func processNextSpeech() {
        // Semua sudah di Main Queue karena queueAccess = DispatchQueue.main
        guard !self.isProcessingQueue else { return }
        self.isProcessingQueue = true

        guard !self.speechQueue.isEmpty else {
            self.isProcessingQueue = false
            return
        }

        let request = self.speechQueue.removeFirst()
        print("SpeechQueueManager: Processing next speech: \"\(request.text)\"")
        
        // Update last spoken feedback timestamp
        self.lastSpokenFeedback = (text: request.text, timestamp: Date())

        // Memanggil speak di TextToSpeechService.
        // Karena TextToSpeechService.speak sudah @MainActor dan kita sudah di Main Queue,
        // kita tidak perlu Task { @MainActor in ... } di sini lagi.
        self.ttsService.speak(text: request.text, withVoice: request.voiceIdentifier) { [weak self] result in
            guard let self = self else { return }
            
            // Panggil completion handler asli dari request
            request.completion?(result)

            // Setelah selesai (sukses/gagal/batal), proses item berikutnya
            self.isProcessingQueue = false // Setel ulang flag
            self.processNextSpeech() // Rekursif panggil untuk item berikutnya
        }
    }
    
    /// Menghentikan semua ucapan yang sedang berjalan dan mengosongkan antrean.
    func stopAllSpeech() {
        queueAccess.async { [weak self] in
            guard let self = self else { return }
            if self.ttsService.isSpeaking {
                self.ttsService.stopSpeaking()
            }
            self.speechQueue.removeAll()
            self.isProcessingQueue = false // Reset flag
            self.lastSpokenFeedback = nil // Reset last spoken
            print("SpeechQueueManager: All speech stopped and queue cleared.")
        }
    }
}

