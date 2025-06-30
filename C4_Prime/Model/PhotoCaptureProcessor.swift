//
//  PhotoCaptureProcessor.swift
//  C4_Prime
//
//  Created by Ali zaenal on 23/06/25.
//

import AVFoundation

// Tempatkan ini di bawah kelas CameraModel

 class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
     private let continuation: CheckedContinuation<Data, Error>
         // BARU: Closure yang akan dipanggil saat selesai.
         private let onFinish: (Int64) -> Void
         
         // Modifikasi init untuk menerima onFinish closure
         init(continuation: CheckedContinuation<Data, Error>, onFinish: @escaping (Int64) -> Void) {
             self.continuation = continuation
             self.onFinish = onFinish
         }
         
         func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
             // Panggil onFinish di dalam `defer` block.
             // Ini memastikan pembersihan akan selalu terjadi, baik ada error maupun tidak.
             defer {
                 self.onFinish(photo.resolvedSettings.uniqueID)
             }
             
             if let error = error {
                 continuation.resume(throwing: error)
                 return
             }
             
             guard let photoData = photo.fileDataRepresentation() else {
                 let noDataError = NSError(domain: "CameraModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Tidak bisa mendapatkan data dari foto yang diambil."])
                 continuation.resume(throwing: noDataError)
                 return
             }
             
             continuation.resume(returning: photoData)
         }}
