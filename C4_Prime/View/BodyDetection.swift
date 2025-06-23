//
//  BodyDetection.swift
//  C4_Prime
//
//  Created by Ali zaenal on 19/06/25.
//

import SwiftUI

struct BodyDetection: View {
    @State private var cameraViewModel = CameraModel()
    @State private var poseViewModel = PoseEstimationModel()
    @State private var isReadyToDetect = false
    
        
        var body: some View {
            // 2.
            ZStack {
                // 2a.
//                if cameraViewModel.session.isRunning == false {
//                    
//                    Text("Preparing your camera...")
//                } else {
//                        
//                    }
                
                CameraPreviewView(session: cameraViewModel.session)
                    .edgesIgnoringSafeArea(.all)
//                    .onAppear{
//                        SpeechQueueManager.shared.enqueueSpeech(text: "Be prepare inside to camera", priority: .utility)
//                        
//                        
//                    }
                // 2b.
                PoseOverlayView(
                    bodyParts: poseViewModel.detectedBodyParts,
                    connections: poseViewModel.bodyConnections
                )
            }
            .task(priority: .userInitiated) {
                await cameraViewModel.checkPermission()
                cameraViewModel.delegate = poseViewModel
                isReadyToDetect = true
                

            }
        }
}

#Preview {
    BodyDetection()
}
