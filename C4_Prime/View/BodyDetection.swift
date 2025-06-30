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
    @State private var takedPhotos: [UIImage] = []
    private var lastThreePhotos: [UIImage] {
            // .suffix(3) dengan aman mengambil 3 elemen terakhir.
            // Jika array memiliki kurang dari 3 elemen, ia akan mengambil semuanya.
            // Array(..) mengubah hasil (sebuah ArraySlice) kembali menjadi Array.
            return Array(takedPhotos.suffix(3))
        }
    
        var body: some View {
            // 2.
            ZStack(alignment: .bottomTrailing) {
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
                NavigationLink(destination: SelectPhoto(availableImages: takedPhotos)){
                    ZStack{
                        ForEach(lastThreePhotos.indices, id: \.self) { index in
                            // Ambil foto berdasarkan index
                            let photo = lastThreePhotos[index]
                            
                            // Hitung nilai dinamis berdasarkan index
                            // Foto paling belakang (index 0) akan memiliki offset dan rotasi terbesar.
                            // Foto paling depan (index terakhir) akan memiliki offset dan rotasi 0.
                            let reverseIndex = lastThreePhotos.count - 1 - index
                            let xOffset = CGFloat(reverseIndex) * 6
                            let yOffset = CGFloat(reverseIndex) * -6
                            let rotation = Angle.degrees(Double(reverseIndex) * -4)
                            
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 85)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .shadow(radius: 5)
                            // Terapkan nilai dinamis di sini
                                .offset(x: xOffset, y: yOffset)
                                .rotationEffect(rotation)
                        }
                    }
                    .frame(width: 100, height: 150)
                    .offset(x: -5, y: -5)
                }
            }
            .onDisappear{
                cameraViewModel.stopSession()
            }
            .onAppear{
                if cameraViewModel.session.isRunning == false {
                    cameraViewModel.session.startRunning()
                }
            }
            .`task`(priority: .userInitiated) {
                await cameraViewModel.checkPermission()
                cameraViewModel.delegate = poseViewModel
                isReadyToDetect = true
                poseViewModel.takePicture = {
                   let tempTakedPhotos = try await cameraViewModel.takePhoto()
                    if let takedPhoto = UIImage(data: tempTakedPhotos) {
                        self.takedPhotos.append(takedPhoto)
                    }
                    print("Finish take Photo: ", tempTakedPhotos, takedPhotos)
                }
                

            }
            .toolbarBackground(.visible)
            .toolbarBackground(.gray.opacity(0.1), for: .automatic)
        }
}

#Preview {
    BodyDetection()
}
