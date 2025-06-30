//
//  PoseEstimationModel.swift
//  C4_Prime
//
//  Created by Ali zaenal on 20/06/25.
//

import SwiftUI
import Vision
import AVFoundation
import Observation

// 1.
struct BodyConnection: Identifiable {
    let id = UUID()
    let from: HumanBodyPoseObservation.JointName
    let to: HumanBodyPoseObservation.JointName
}


enum CaptureState {
    case idle           // Menunggu pose yang benar
    case countingDown   // Menghitung mundur sebelum mengambil foto
    case takingPicture  // Sedang dalam proses mengambil foto
    case cooldown       // Memberi jeda setelah foto diambil
}

@Observable
class PoseEstimationModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // 2.
    var detectedBodyParts: [HumanBodyPoseObservation.JointName: CGPoint] = [:]
    var bodyConnections: [BodyConnection] = []
//    var bufferImage: CMSampleBuffer?
    
    var frameCount = 0

    var processingInterval = 15
    
    private var isOnTakePicture = false
    
    var takePicture: ()async throws -> Void = {}
    override init() {
        super.init()
        setupBodyConnections()
        
    }
    
    private var isOnPosition = false
    
    private let bodyCorrection = BodyCorrectionModel()
    
    private var captureState: CaptureState = .idle
    
    private func increaseFrameCount(){
        if frameCount >= 100 {
            frameCount = 0
        }else {
            frameCount += 1
        }
    }
    
    func toggleOnTakePicture(){
        isOnTakePicture = !isOnTakePicture
    }
    
    // 3.
    private func setupBodyConnections() {
        bodyConnections = [
            BodyConnection(from: .nose, to: .neck),
            BodyConnection(from: .neck, to: .rightShoulder),
            BodyConnection(from: .neck, to: .leftShoulder),
            BodyConnection(from: .rightShoulder, to: .rightHip),
            BodyConnection(from: .leftShoulder, to: .leftHip),
            BodyConnection(from: .rightHip, to: .leftHip),
            BodyConnection(from: .rightShoulder, to: .rightElbow),
            BodyConnection(from: .rightElbow, to: .rightWrist),
            BodyConnection(from: .leftShoulder, to: .leftElbow),
            BodyConnection(from: .leftElbow, to: .leftWrist),
            BodyConnection(from: .rightHip, to: .rightKnee),
            BodyConnection(from: .rightKnee, to: .rightAnkle),
            BodyConnection(from: .leftHip, to: .leftKnee),
            BodyConnection(from: .leftKnee, to: .leftAnkle)
        ]
    }

    // 4.
    // Ganti seluruh fungsi captureOutput Anda dengan yang ini
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task {
            increaseFrameCount()
            
            // Tetap proses frame untuk menampilkan overlay secara real-time
            if let detectedPoints = await processFrame(sampleBuffer) {
                DispatchQueue.main.async {
                    self.detectedBodyParts = detectedPoints
                }
            }
            
            // Lewati pemrosesan pose jika interval belum tercapai
            guard frameCount % processingInterval == 0 else {
                return
            }
            
            let request = DetectHumanBodyPose3DRequest()
            
            guard let obsvData = try? await request.perform(on: sampleBuffer).first as? HumanBodyPose3DObservation else {
                // Jika tidak ada orang terdeteksi, reset state ke idle
                DispatchQueue.main.async {
                    if self.captureState == .countingDown {
                        print("❌ Pose batal, kembali ke idle.")
                    }
                    self.captureState = .idle
                }
                return
            }
            
            // Pengecekan pose awal (misal: menghadap kamera)
            let onPositionObsv = bodyCorrection.onPositionFrontDoubleBicepPose(observation: obsvData)
            guard onPositionObsv.isPoseCorrect else {
                return
            }
            
            // Pengecekan detail pose (Double Bicep)
            let isPoseCorrect = bodyCorrection.DoubleBicepCorrection(bodyPose: obsvData)
            
            // 1. Reset state jika pose tidak lagi benar saat countdown
            guard isPoseCorrect else {
                DispatchQueue.main.async {
                    if self.captureState == .countingDown {
                        print("❌ Pose batal saat countdown, kembali ke idle.")
                    }
                    self.captureState = .idle
                }
                return
            }
            
            // 2. Jika pose sudah benar, kita lanjutkan berdasarkan state saat ini.
            // Hanya mulai proses jika state adalah .idle.
            guard self.captureState == .idle else {
                // Jika sedang countdown, mengambil foto, atau cooldown, jangan lakukan apa-apa.
                return
            }

            // 3. Mulai proses pengambilan foto
            DispatchQueue.main.async {
                print("✅ Pose terdeteksi! Memulai hitungan mundur...")
                self.captureState = .countingDown
                SpeechQueueManager.shared.enqueueSpeech(text: "Keep it UP!. 1,2,3", priority: .background, forceSpeak: true)
                
                // Atur timer untuk mengambil foto setelah 3.5 detik
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    // Pastikan kita masih dalam state countingDown.
                    // Ini mencegah pengambilan foto jika pengguna sudah bergerak.
                    guard self.captureState == .countingDown else {
                        print("Pengambilan foto dibatalkan karena state berubah.")
                        return
                    }
                    
                    self.captureState = .takingPicture
                    print("📸 Mengambil foto...")
                    
                    Task {
                        do {
                            try await self.takePicture()
                            print("✅ Foto berhasil diambil.")
                            
                            // Setelah selesai, masuk ke state cooldown
                            self.captureState = .cooldown
                            print("❄️ Memulai cooldown...")
                            
                            // Beri jeda 2 detik sebelum kembali ke idle
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                print("👍 Siap untuk pose berikutnya. Kembali ke idle.")
                                self.captureState = .idle
                            }
                        } catch {
                            print("Gagal mengambil foto: \(error)")
                            self.captureState = .idle // Jika gagal, langsung kembali ke idle
                        }
                    }
                }
            }
        }
    }

    // 5.
    func processFrame(_ sampleBuffer: CMSampleBuffer) async -> [HumanBodyPoseObservation.JointName: CGPoint]? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        let request = DetectHumanBodyPoseRequest()
        
        do {
            let results = try await request.perform(on: imageBuffer, orientation: .none)
            if let observation = results.first {
                return extractPoints(from: observation)
            }
        } catch {
            print("Error processing frame: \(error.localizedDescription)")
        }

        return nil
    }

    // 6.
    private func extractPoints(from observation: HumanBodyPoseObservation) -> [HumanBodyPoseObservation.JointName: CGPoint] {
        var detectedPoints: [HumanBodyPoseObservation.JointName: CGPoint] = [:]
        let humanJoints: [HumanBodyPoseObservation.PoseJointsGroupName] = [.face, .torso, .leftArm, .rightArm, .leftLeg, .rightLeg]
        
        for groupName in humanJoints {
            let jointsInGroup = observation.allJoints(in: groupName)
            for (jointName, joint) in jointsInGroup {
                if joint.confidence > 0.5 { // Ensuring only high-confidence joints are added
                    let point = joint.location.verticallyFlipped().cgPoint
                    detectedPoints[jointName] = point
                }
            }
        }
        return detectedPoints
    }
}
