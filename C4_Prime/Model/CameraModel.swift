//
//  CameraModel.swift
//  C4_Prime
//
//  Created by Ali zaenal on 20/06/25.
//

import SwiftUI
import AVFoundation
import Vision

@Observable
class CameraModel {

    // 1.
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let videoDataOutputQueue = DispatchQueue(label: "videoDataOutputQueue")
    private let videoDataOutput = AVCaptureVideoDataOutput()
    weak var delegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptures = [Int64: PhotoCaptureProcessor]()
    
    
    
    // 2.
    func checkPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await setupCamera()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await setupCamera()
            }
        default:
            print("Camera permission denied")
        }
    }
    
    // 3.
    private func setupCamera() async {
        sessionQueue.async {
            self.session.beginConfiguration()
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                print("Failed to create video input")
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
            }
            
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            
            self.videoDataOutput.setSampleBufferDelegate(self.delegate, queue: self.videoDataOutputQueue)
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
            }
            
            if let connection = self.videoDataOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
                connection.isVideoMirrored = true
            }
            
            
            // Config for Photo output
            self.photoOutput.isHighResolutionCaptureEnabled = true
            self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported
            guard self.session.canAddOutput(self.photoOutput) else { return }
            self.session.sessionPreset = .photo
            self.session.addOutput(self.photoOutput)
            
            
            self.session.commitConfiguration()
            self.session.startRunning()
            
            
        }
        
    }
    
    public func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else {
                return
            }
            
            self.session.stopRunning()
            
            // Remove all inputs and outputs to fully tear down the session
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }
            
            // Clear any in-progress captures to prevent memory leaks
            self.inProgressPhotoCaptures.removeAll()
            
            print("✅ Camera session fully stopped and torn down.")
        }
    }

    
    func takePhoto() async throws -> Data {
        var photoSettings = AVCapturePhotoSettings()
            // ... atur photoSettings Anda seperti sebelumnya ...
            
            print("📸📸Taking photo with settings: \(photoSettings)📸")
            
            return try await withCheckedThrowingContinuation { continuation in
                sessionQueue.async {
                    // Buat delegasi, tapi kali ini kita berikan "cara untuk membersihkan diri".
                    // `onFinish` closure ini akan dipanggil oleh delegasi saat tugasnya selesai.
                    if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                        photoSettings = AVCapturePhotoSettings(format:
                            [AVVideoCodecKey: AVVideoCodecType.hevc])
                    } else {
                        photoSettings = AVCapturePhotoSettings()
                    }
                    photoSettings.flashMode = .auto
                    photoSettings.isAutoStillImageStabilizationEnabled =
                        self.photoOutput.isStillImageStabilizationSupported

                    
                    let delegate = PhotoCaptureProcessor(
                        continuation: continuation,
                        onFinish: { [weak self] uniqueID in
                            // Hapus delegasi dari dictionary setelah selesai.
                            self?.inProgressPhotoCaptures.removeValue(forKey: uniqueID)
                        }
                    )
                    
                    // Simpan delegasi di dictionary kita. Ini adalah referensi `strong`
                    // yang akan menjaganya tetap hidup.
                    self.inProgressPhotoCaptures[photoSettings.uniqueID] = delegate
                    
                    // Panggil capturePhoto seperti biasa.
                    self.photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
                }
            }
        }

}
