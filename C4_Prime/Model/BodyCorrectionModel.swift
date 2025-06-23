//
//  BodyCorrectionModel.swift
//  C4_Prime
//
//  Created by Ali zaenal on 20/06/25.
//

import Foundation
import Vision
import simd



struct PoseClassificationResult {
    let isPoseCorrect: Bool
    let confidence: Float
    let feedback: String
    let detectedJoints: [String: Bool]
}

/// Hasil analisis orientasi 3D antara dua sendi
struct AnalisisSudut3D {
    // Bidang XY (tampak depan)
    let sudutXY: Double
    
    // Bidang XZ (tampak atas)
    let sudutXZ: Double
    
    // Keterangan relatif per sumbu
    let keteranganHorizontal: String
    let keteranganVertikal: String
    let keteranganKedalaman: String
    
    // Informasi tambahan untuk analisis lanjutan
    let vektorRelatif: SIMD3<Double>
    let jarak: Double
}

struct BodyCorrectionModel {
    func onPositionFrontDoubleBicepPose(observation: HumanBodyPose3DObservation) -> PoseClassificationResult  {
        
        print("\n === FRONT DOUBLE BICEP POSE ANALYSIS === ")
        
        let leftShoulder = observation.joint(for: .leftShoulder)
        let rightShoulder = observation.joint(for: .rightShoulder)
        let leftElbow = observation.joint(for: .leftElbow)
        let rightElbow = observation.joint(for: .rightElbow)
        let leftWrist = observation.joint(for: .leftWrist)
        let rightWrist = observation.joint(for: .rightWrist)
        
        var detectedJoints: [String: Bool] = [:]
        var missingJoints: [String] = []
        var feedback: [String] = []
        var isCorrectPose = false
        var confidence: Float = 1.0
        
        detectedJoints["leftShoulder"] = leftShoulder != nil
        detectedJoints["rightShoulder"] = rightShoulder != nil
        detectedJoints["leftElbow"] = leftElbow != nil
        detectedJoints["rightElbow"] = rightElbow != nil
        detectedJoints["leftWrist"] = leftWrist != nil
        detectedJoints["rightWrist"] = rightWrist != nil
        
        for (joint, detected) in detectedJoints {
            if !detected {
                missingJoints.append(joint)
            }
        }
        
        if missingJoints.count > 2 {
            print("\n❌ CLASSIFICATION RESULT: POSE TIDAK DAPAT DIDETEKSI")
            print("Reason: Terlalu banyak joint yang tidak terdeteksi (\(missingJoints.count)/6)")
            return PoseClassificationResult(
                isPoseCorrect: false,
                confidence: 0.0,
                feedback: "Tidak dapat mendeteksi pose - terlalu banyak joint yang hilang: \(missingJoints.joined(separator: ", "))",
                detectedJoints: detectedJoints
            )
        }
        
        print("\nPOSE ANALYSIS:")
        
        

        
        confidence = max(0.0, confidence)
        let finalFeedback = isCorrectPose ? "Pose Front Double Bicep SEMPURNA! 💪" : feedback.joined(separator: ", ")
        
        print("\n=== FINAL CLASSIFICATION RESULT ===")
        print("Pose Correct: \(isCorrectPose ? "✅ YES" : "❌ NO")")
        print("Confidence: \(String(format: "%.1f", confidence * 100))%")
        print("Feedback: \(finalFeedback)")
        print("=======================================\n")
        
        return PoseClassificationResult(
            isPoseCorrect: isCorrectPose,
            confidence: confidence,
            feedback: finalFeedback,
            detectedJoints: detectedJoints
        )
    }
    
    
    

    /**
     Menganalisis orientasi 3D secara komprehensif antara dua sendi (joint).
     
     - Asumsi Sistem Koordinat:
       - `+X` : Ke kanan (right)
       - `+Y` : Ke atas (up)
       - `-Z` : Ke depan/maju (forward, menuju kamera)
       - `+Z` : Ke belakang/mundur (backward, menjauhi kamera)
     
     - Parameter jointA: Koordinat 3D sendi awal (mis: bahu)
     - Parameter jointB: Koordinat 3D sendi akhir (mis: siku)
     - Parameter threshold: Batas toleransi untuk posisi "sejajar" (default: 0.01)
     - Returns: AnalisisSudut3D berisi semua hasil analisis
     */
    // Represents the result of a 3D angle analysis between two points.
    // Anda juga perlu mengubah nama struct/class `AnalisisSudut3D` menjadi `Angle3DAnalysis` di definisi aslinya.
    struct Angle3DAnalysis {
        let angleXY: Double
        let angleXZ: Double
        let horizontalDescription: String
        let verticalDescription: String
        let depthDescription: String
        let relativeVector: SIMD3<Double>
        let distance: Double
    }

    func perform3DAnalysis(
        from jointA: SIMD3<Double>,
        to jointB: SIMD3<Double>,
        threshold: Double = 0.01
    ) -> Angle3DAnalysis {
        
        // 1. Calculate the relative vector and distance
        let deltaX = jointB.x - jointA.x
        let deltaY = jointB.y - jointA.y
        let deltaZ = jointB.z - jointA.z
        let vector = SIMD3<Double>(deltaX, deltaY, deltaZ)
        let distance = length(vector)
        
        // 2. Analyze the XY plane (front view)
        let angleXY = calculateAngleInPlane(dx: deltaX, dy: deltaY, plane: .xy)
        
        // 3. Analyze the XZ plane (top view)
        let angleXZ = calculateAngleInPlane(dx: deltaX, dy: deltaZ, plane: .xz)
        
        // 4. Generate relative descriptions for each axis
        let horizontalDescription = getRelativeAxisDescription(value: deltaX, positive: "Right", negative: "Left", threshold: threshold)
        let verticalDescription = getRelativeAxisDescription(value: deltaY, positive: "Up", negative: "Down", threshold: threshold)
        let depthDescription = getRelativeAxisDescription(value: -deltaZ, positive: "Forward", negative: "Backward", threshold: threshold) // Note: -Z is considered 'forward'
        
        return Angle3DAnalysis(
            angleXY: angleXY,
            angleXZ: angleXZ,
            horizontalDescription: horizontalDescription,
            verticalDescription: verticalDescription,
            depthDescription: depthDescription,
            relativeVector: vector,
            distance: distance
        )
    }

    // MARK: - Helper Functions

    enum AnalysisPlane {
        case xy // Represents the horizontal-vertical plane (front view)
        case xz // Represents the horizontal-depth plane (top view)
    }

    /// Calculates the angle in a specific 2D plane.
    private func calculateAngleInPlane(dx: Double, dy: Double, plane: AnalysisPlane) -> Double {
        let angle = atan2(dy, dx) * 180 / .pi
        let normalizedAngle = angle < 0 ? angle + 360 : angle
        
        return normalizedAngle
    }

    /// Generates a relative description for a single axis value.
    private func getRelativeAxisDescription(value: Double, positive: String, negative: String, threshold: Double) -> String {
        if abs(value) < threshold {
            return "Aligned"
        } else if value > 0 {
            return "To the \(positive)"
        } else {
            return "To the \(negative)"
        }
    }

    
    
    func DoubleBicepCorrection(bodyPose: HumanBodyPose3DObservation) -> Bool {
        
        guard let leftElbowCoord = bodyPose.joint(for: .leftElbow)?.localPosition.columns.3 else {
            print("for: .leftElbow ", "not detected")
            return false
        }
        
        guard let leftShoulderCoord = bodyPose.joint(for: .leftShoulder)?.localPosition.columns.3 else {
            print("for: .leftShoulder ", "not detected")
            return false
        }
        
        guard let leftWristCoord = bodyPose.joint(for: .leftWrist)?.localPosition.columns.3 else {
            print("for: .leftWrist ", "not detected")
            return false
        }
        
        
        guard let rightElbowCoord = bodyPose.joint(for: .rightElbow)?.localPosition.columns.3 else {
            print("for: .rightElbow ", "not detected")
            return false
        }
        
        guard let rightShoulderCoord = bodyPose.joint(for: .rightShoulder)?.localPosition.columns.3 else {
            print("for: .rightShoulder ", "not detected")
            return false
        }
        
        guard let rightWristCoord = bodyPose.joint(for: .rightWrist)?.localPosition.columns.3 else {
            print("for: .rightWrist ", "not detected")
            return false
        }
        
        let leftShoulder = SIMD3<Double>(Double(leftShoulderCoord.x), Double(leftShoulderCoord.y), Double(leftShoulderCoord.x))
        let leftElbow = SIMD3<Double>(Double(leftElbowCoord.x), Double(leftElbowCoord.y), Double(leftElbowCoord.x))
        let leftWrist = SIMD3<Double>(Double(leftWristCoord.x), Double(leftWristCoord.y), Double(leftWristCoord.x))

        let leftSEResult = self.perform3DAnalysis(from: leftShoulder, to: leftElbow)
        print("leftSEResult Sudut XY: \(leftSEResult.angleXY)° ")
        print("leftSEResult Sudut XZ: \(leftSEResult.angleXZ)° ")
        
        
        let leftEWResult = self.perform3DAnalysis(from: leftElbow, to: leftWrist)
        print("leftEWResult Sudut XY: \(leftEWResult.angleXY)° ")
        print("leftEWResult Sudut XZ: \(leftEWResult.angleXZ)° ")
        

        
        let rightShoulder = SIMD3<Double>(Double(rightShoulderCoord.x), Double(rightShoulderCoord.y), Double(rightShoulderCoord.x))
        let rightElbow = SIMD3<Double>(Double(rightElbowCoord.x), Double(rightElbowCoord.y), Double(rightElbowCoord.x))
        let rightWrist = SIMD3<Double>(Double(rightWristCoord.x), Double(rightWristCoord.y), Double(rightWristCoord.x))

        let rightSEResult = perform3DAnalysis(from: rightShoulder, to: rightElbow)
        
        print("\nrightSEResult Sudut XY: \(rightSEResult.angleXY)° ")
        print("rightSEResult Sudut XZ: \(rightSEResult.angleXZ)° ")
        
        let rightEWResult = perform3DAnalysis(from: rightElbow, to: rightWrist)
        print("\nrightEWResult Sudut XY: \(rightEWResult.angleXY)° ")
        print("rightEWResult Sudut XZ: \(rightEWResult.angleXZ)° ")
        

        let shouldercymetice = perform3DAnalysis(from: leftShoulder, to: rightShoulder)
        print("\nshouldercymetice Sudut XY: \(shouldercymetice.angleXY)° ")
        print("shouldercymetice Sudut XZ: \(shouldercymetice.angleXZ)° ")
        
        
        return true
    }
}


