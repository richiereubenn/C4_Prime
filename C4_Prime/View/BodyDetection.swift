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
    
        
        var body: some View {
            // 2.
            ZStack {
                // 2a.
                CameraPreviewView(session: cameraViewModel.session)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear{
                        Task{
                            try txtToSpeech.speak(text: "prepare yourself to enter the camera", completion: {})
                        }
                    }
                // 2b.
                PoseOverlayView(
                    bodyParts: poseViewModel.detectedBodyParts,
                    connections: poseViewModel.bodyConnections
                )
            }
            .task {
                await cameraViewModel.checkPermission()
                cameraViewModel.delegate = poseViewModel
            }
        }
}

#Preview {
    BodyDetection()
}
