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
        var isCorrectPose = true

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
        

        let shoulderElbowMinThreshold: Float = 0.035
        let shoulderElbowMaxThreshold: Float = 0.220
        let flexThresholdNormalized: Float = 0.5
        
        var leftArmAligned = false
        var rightArmAligned = false
        
        if let s = leftShoulder, let e = leftElbow {
            let deltaY = e.localPosition.columns.3.y - s.localPosition.columns.3.y
            let absDeltaY = abs(deltaY)
            leftArmAligned = (absDeltaY >= shoulderElbowMinThreshold) && (absDeltaY <= shoulderElbowMaxThreshold)
            print("Left arm aligned: \(leftArmAligned ? "✅ YES" : "❌ NO") (ΔY: \(String(format: "%.3f", absDeltaY)))")
            
            if !leftArmAligned {
                feedback.append(deltaY < -0.02
                                ? "Siku kiri terlalu rendah dari bahu (ΔY: \(String(format: "%.3f", deltaY)))"
                                : "Siku kiri terlalu tinggi dari bahu (ΔY: \(String(format: "%.3f", deltaY)))")
                isCorrectPose = false
                confidence -= 0.3
            }
        }
        
        if let s = rightShoulder, let e = rightElbow {
            let deltaY = e.localPosition.columns.3.y - s.localPosition.columns.3.y
            let absDeltaY = abs(deltaY)
            rightArmAligned = (absDeltaY >= shoulderElbowMinThreshold) && (absDeltaY <= shoulderElbowMaxThreshold)
            print("Right arm aligned: \(rightArmAligned ? "✅ YES" : "❌ NO") (ΔY: \(String(format: "%.3f", absDeltaY)))")
            
            if !rightArmAligned {
                feedback.append(deltaY < -0.02
                                ? "Siku kanan terlalu rendah dari bahu (ΔY: \(String(format: "%.3f", deltaY)))"
                                : "Siku kanan terlalu tinggi dari bahu (ΔY: \(String(format: "%.3f", deltaY)))")
                isCorrectPose = false
                confidence -= 0.3
            }
        }
        
        if let s = leftShoulder, let e = leftElbow, let w = leftWrist {
            let elbowY = e.localPosition.columns.3.y
            let wristY = w.localPosition.columns.3.y
            let deltaY = wristY - elbowY
            let armLength = abs(e.localPosition.columns.3.y - s.localPosition.columns.3.y)
            let normalizedDeltaY = armLength > 0 ? deltaY / armLength : 0
            
            let flexed = leftArmAligned ? normalizedDeltaY > flexThresholdNormalized : deltaY > 0
            print("Left bicep flexed: \(flexed ? "✅ YES" : "❌ NO") (ΔY: \(String(format: "%.3f", deltaY)), Normalized: \(String(format: "%.3f", normalizedDeltaY)), ArmAligned: \(leftArmAligned ? "✅" : "❌"))")
            
            if !flexed {
                feedback.append("Tekuk lengan kiri lebih kuat untuk menunjukkan bisep")
                isCorrectPose = false
                confidence -= 0.2
            }
        }
        
        if let s = rightShoulder, let e = rightElbow, let w = rightWrist {
            let elbowY = e.localPosition.columns.3.y
            let wristY = w.localPosition.columns.3.y
            let deltaY = wristY - elbowY
            let armLength = abs(e.localPosition.columns.3.y - s.localPosition.columns.3.y)
            let normalizedDeltaY = armLength > 0 ? deltaY / armLength : 0
            
            let flexed = rightArmAligned ? normalizedDeltaY > flexThresholdNormalized : deltaY > 0
            print("Right bicep flexed: \(flexed ? "✅ YES" : "❌ NO") (ΔY: \(String(format: "%.3f", deltaY)), Normalized: \(String(format: "%.3f", normalizedDeltaY)), ArmAligned: \(rightArmAligned ? "✅" : "❌"))")
            
            if !flexed {
                feedback.append("Tekuk lengan kanan lebih kuat untuk menunjukkan bisep")
                isCorrectPose = false
                confidence -= 0.2
            }
        }
        
        let elbowSeparationThreshold: Float = 1
        
        if let leftElbow = leftElbow, let rightElbow = rightElbow,
           let leftShoulder = leftShoulder, let rightShoulder = rightShoulder {
            
            let deltaY = abs(leftElbow.localPosition.columns.3.y - rightElbow.localPosition.columns.3.y)
            
            let shoulderHeight = abs(leftShoulder.localPosition.columns.3.y - rightShoulder.localPosition.columns.3.y)
            let normalizedElbowDeltaY = shoulderHeight > 0 ? deltaY / shoulderHeight : 0
            
            let isElbowTooClose = normalizedElbowDeltaY < elbowSeparationThreshold
            
            print("Elbow vertical separation: \(String(format: "%.3f", deltaY)), Normalized: \(String(format: "%.3f", normalizedElbowDeltaY)) → \(isElbowTooClose ? "❌ TOO CLOSE" : "✅ OK")")
            
            if isElbowTooClose {
                feedback.append("Siku kiri dan kanan terlalu sejajar vertikal - rentangkan siku lebih keluar")
                isCorrectPose = false
                confidence -= 0.2
            }
        }
        
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
        

        let SECalResult =  calculateSEVerticalPoseCorrection(angle: leftSEResult.angleXY, side: .left)
        
        print("SECalResult: ",SECalResult)
        
        guard SECalResult == .ideal else {
            SpeechQueueManager.shared.enqueueSpeech(text: generateCorrectionStatusFeedback(status: SECalResult, side: .left), priority: .userInitiated)
            print("🔥OUT FROM HERE SECalResult: ", SECalResult)
            return false
        }
        
        
        
        let rightShoulder = SIMD3<Double>(Double(rightShoulderCoord.x), Double(rightShoulderCoord.y), Double(rightShoulderCoord.x))
        let rightElbow = SIMD3<Double>(Double(rightElbowCoord.x), Double(rightElbowCoord.y), Double(rightElbowCoord.x))
        let rightWrist = SIMD3<Double>(Double(rightWristCoord.x), Double(rightWristCoord.y), Double(rightWristCoord.x))

        let rightSEResult = perform3DAnalysis(from: rightShoulder, to: rightElbow)
        

        let RightSECalResult =  calculateSEVerticalPoseCorrection(angle: rightSEResult.angleXY, side: .right)
        
        guard RightSECalResult == .ideal else {
            print("RightSECalResult: ",RightSECalResult)
            SpeechQueueManager.shared.enqueueSpeech(text: generateCorrectionStatusFeedback(status: RightSECalResult, side: .right), priority: .userInitiated)
            print("🔥OUT FROM HERE: ", RightSECalResult)
            return false
        }
        
        print("\nrightSEResult Sudut XY: \(rightSEResult.angleXY)° ")
        print("rightSEResult Sudut XZ: \(rightSEResult.angleXZ)° ")
        
        let rightEWResult = perform3DAnalysis(from: rightElbow, to: rightWrist)
        print("\nrightEWResult Sudut XY: \(rightEWResult.angleXY)° ")
        print("rightEWResult Sudut XZ: \(rightEWResult.angleXZ)° ")
        

        
        let leftEWResult = self.perform3DAnalysis(from: leftElbow, to: leftWrist)
        print("leftEWResult Sudut XY: \(leftEWResult.angleXY)° ")
        print("leftEWResult Sudut XZ: \(leftEWResult.angleXZ)° ")
        
        let LeftEWCalResult =  calculateEWHorizontalPoseCorrection(angle: leftEWResult.angleXY, side: .left)
        
        guard LeftEWCalResult == .ideal else {
            SpeechQueueManager.shared.enqueueSpeech(text: generateCorrectionStatusFeedback(status: LeftEWCalResult, side: .left), priority: .userInitiated)
            print("🔥OUT FROM HERE: RIGHT", LeftEWCalResult)
            return false
        }
        
        let rightEWCalResult =  calculateEWHorizontalPoseCorrection(angle: rightEWResult.angleXY, side: .right)
        
        print("rightEWCalResult: ", rightEWCalResult)
        
        guard rightEWCalResult == .ideal else {
            SpeechQueueManager.shared.enqueueSpeech(text: generateCorrectionStatusFeedback(status: rightEWCalResult, side: .right), priority: .userInitiated)
            print("🔥OUT FROM HERE: LEFT ", rightEWCalResult)
            return false
        }

        let shouldercymetice = perform3DAnalysis(from: leftShoulder, to: rightShoulder)
        print("\nshouldercymetice Sudut XY: \(shouldercymetice.angleXY)° ")
        print("shouldercymetice Sudut XZ: \(shouldercymetice.angleXZ)° ")
        
        

        
        return true
    }
    
    
    // Reverse the body side for feedback generation cause the camera mirror effect
    enum BodySide: String {
        case left = "right"
        case right = "left"
    }

    /// Merepresentasikan status postur yang terdeteksi.
    enum CorrectionSEStatus: String {
        case ideal = "Ideal"
        case tooHight = "Lower Arm"
        case tooLow = "Raise Arm"
    }

    enum CorrectionEWStatus: String {
        case ideal = "Ideal"
        case tooIn = "Spread Wrist"
        case tooOut = "Pull Wrist"
    }
    
    
    func generateCorrectionStatusFeedback(status: CorrectionSEStatus, side: BodySide) -> String {
        if status.rawValue == "Ideal" {
            return "Ideal"
        }
        
        return status.rawValue.inserting(word: side.rawValue)
    }
    func generateCorrectionStatusFeedback(status: CorrectionEWStatus, side: BodySide) -> String {
        if status.rawValue == "Ideal" {
            return "Ideal"
        }
        
        return status.rawValue.inserting(word: side.rawValue)
    }
    



    /**
     Menentukan status postur (ideal, terlalu tinggi, atau terlalu rendah)
     berdasarkan sudut dan sisi tubuh yang diberikan.
     
     Fungsi ini menggunakan threshold yang telah dianalisis dari data spesifik Anda.
     
     - Parameter sudut: Sudut kemiringan yang telah dihitung (dalam rentang 0-360).
     - Parameter sisi: Sisi tubuh yang dianalisis (.kiri atau .kanan).
     - Parameter toleransi: Nilai toleransi dalam derajat yang ditambahkan pada rentang 'ideal'.
     - Returns: Enum `CorrectionSEStatus` yang sesuai.
     */
    func calculateSEVerticalPoseCorrection(
        angle: Double,
        side: BodySide,
        tolerance: Double = 8.5 // Default tolerance 5 derajat
    ) -> CorrectionSEStatus {
        
        switch side {
        case .left:
            // Threshold berdasarkan analisis data untuk tangan KIRI
            let idealBawah: Double = 301.6
            let idealAtas: Double = 305.0
            
            // Periksa apakah sudut masuk dalam rentang ideal + tolerance
            if angle >= idealBawah - tolerance && angle <= idealAtas + tolerance {
                return .ideal
            }
            
            // Untuk tangan kiri, angle yang lebih kecil berarti lengan lebih tinggi
            if angle < idealBawah - tolerance {
                return .tooLow
            } else {
                return .tooHight
            }
            
        case .right:
            // Threshold berdasarkan analisis data untuk tangan KANAN
            let idealBawah: Double = 229.0
            let idealAtas: Double = 233.6
            
            // Periksa apakah angle masuk dalam rentang ideal + tolerance
            if angle >= idealBawah - tolerance && angle <= idealAtas + tolerance {
                return .ideal
            }
            
            // Untuk tangan kanan, angle yang LEBIH BESAR berarti lengan lebih tinggi
            if angle > idealAtas + tolerance {
                return .tooLow
            } else {
                return .tooHight
            }
        }
    }

    func calculateEWHorizontalPoseCorrection(
        angle: Double,
        side: BodySide,
        tolerance: Double = 5.5 // Default tolerance 5 derajat
    ) -> CorrectionEWStatus {
        
        switch side {
        case .left:
            // Threshold berdasarkan analisis data untuk tangan KIRI
            let idealIn: Double = 152.0
            let idealOut: Double = 137.6
            
            // Periksa apakah sudut masuk dalam rentang ideal + tolerance
            if angle <= idealIn + tolerance && angle >= idealOut - tolerance {
                return .ideal
            }
            
            // Untuk tangan kiri, angle yang lebih kecil berarti lengan lebih tinggi
            if angle > idealIn + tolerance {
                return .tooIn
            } else {
                print("😖😖😖😖Masuk sini cok left: ", angle )
                print("IdealIn: ", idealIn + tolerance)
                print("idealOut: ", idealOut - tolerance)
                return .tooOut
            }
            
        case .right:
            // Threshold berdasarkan analisis data untuk tangan KANAN
            let idealIn: Double = 30.0
            let idealOut: Double = 50.0
            
            
            // Periksa apakah sudut masuk dalam rentang ideal + tolerance
            if angle >= idealIn - tolerance && angle <= idealOut + tolerance {
                return .ideal
            }
            
            // Untuk tangan kiri, angle yang lebih kecil berarti lengan lebih tinggi
            print("😖😖😖😖Masuk sini cok right: ", angle )
            if angle < idealIn - tolerance {
                return .tooIn
            } else {
                return .tooOut
            }
        }
    }



}


extension String {
    
    /// Menyisipkan sebuah kata di antara kata pertama dan sisa string.
    ///
    /// Function ini mencari spasi pertama, lalu menyisipkan kata yang diberikan di antara
    /// bagian sebelum dan sesudah spasi tersebut.
    ///
    /// Contoh:
    /// ```
    /// "Too High".inserting(word: "Left") -> "Too Left High"
    /// "Terlalu rendah".inserting(word: "Kanan") -> "Terlalu Kanan rendah"
    /// "Ideal".inserting(word: "Sangat") -> "Ideal" // Tidak ada spasi, tidak ada perubahan
    /// ```
    /// - Parameter word: Kata (String) yang ingin disisipkan.
    /// - Returns: Sebuah string baru dengan kata yang telah disisipkan, atau string asli jika tidak ada spasi.
    func inserting(word: String) -> String {
        // 1. Bersihkan string dari spasi di awal/akhir
        let trimmedString = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Cari rentang (range) dari spasi pertama
        if let rangeOfFirstSpace = trimmedString.range(of: " ") {
            // 3. Ambil bagian sebelum spasi
            let firstPart = trimmedString[..<rangeOfFirstSpace.lowerBound]
            
            // 4. Ambil bagian setelah spasi
            let secondPart = trimmedString[rangeOfFirstSpace.upperBound...]
            
            // 5. Gabungkan semuanya menjadi string baru
            return "\(firstPart) \(word) \(secondPart)"
        }
        
        // 6. Jika tidak ada spasi, kembalikan string asli
        return trimmedString
    }
}
