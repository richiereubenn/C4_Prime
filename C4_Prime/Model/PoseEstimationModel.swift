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

@Observable
class PoseEstimationModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // 2.
    var detectedBodyParts: [HumanBodyPoseObservation.JointName: CGPoint] = [:]
    var bodyConnections: [BodyConnection] = []
//    var bufferImage: CMSampleBuffer?
    
    var frameCount = 0
    var processingInterval = 15
    
    override init() {
        super.init()
        setupBodyConnections()
    }
    
    private let bodyCorrection = BodyCorrectionModel()
    
    private func increaseFrameCount(){
        if frameCount >= 100 {
            frameCount = 0
        }else {
            frameCount += 1
        }
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
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task {
            increaseFrameCount()
            
            if let detectedPoints = await processFrame(sampleBuffer) {
                DispatchQueue.main.async {
                    self.detectedBodyParts = detectedPoints
                }
            }
            
            guard frameCount % processingInterval == 0 else {
                    return // Lewati frame ini
            }
            
            let request = DetectHumanBodyPose3DRequest()
            
            let obsv = try await request.perform(on: sampleBuffer)
            guard let obsvdata : HumanBodyPose3DObservation = obsv.first else {
                    print("\n======================\n\n\n❌No one Human detected❌\n")
                    return
                }
            
            let onPositionObsv = bodyCorrection.onPositionFrontDoubleBicepPose(observation: obsvdata)
            
            
            guard onPositionObsv.isPoseCorrect else {
                print(onPositionObsv.feedback)
                SpeechQueueManager.shared.stopAllSpeech()
//                SpeechQueueManager.shared.enqueueSpeech(text: "Follow the overlay guide", priority: .background)
                return
            }
            
            
            print("\n✅✅✅✅✅✅BODY IS on Position")
            
            
            let isPoseCorrect = bodyCorrection.DoubleBicepCorrection(bodyPose: obsvdata)
            
            if isPoseCorrect == true {
                SpeechQueueManager.shared.enqueueSpeech(text: "Keep it UP!. 1,2,3", priority: .background)
                
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
