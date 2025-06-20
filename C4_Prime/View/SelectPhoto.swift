//
//  SelectPhoto.swift
//  C4_Prime
//
//  Created by Richie Reuben Hermanto on 19/06/25.
//

import SwiftUI
import Photos

struct SelectPhoto: View {
    let availableImages: [UIImage] = [
        UIImage(named: "front-double-bicep")!,
        UIImage(named: "Rectangle 2")!,
        UIImage(named: "front-double-bicep")!,
    ]

    @State private var selectedImages: Set<UIImage> = []
    @State private var showSavedAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Pilih gambar yang ingin disimpan")
                    .font(.headline)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(availableImages, id: \.self) { image in
                            ZStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedImages.contains(image) ? Color.blue : Color.clear, lineWidth: 4)
                                    )
                                    .onTapGesture {
                                        toggleSelection(for: image)
                                    }

                                if selectedImages.contains(image) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .background(Color.white.clipShape(Circle()))
                                        .offset(x: 60, y: -60)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button("Simpan ke Galeri") {
                    saveSelectedImages()
                }
                .disabled(selectedImages.isEmpty)
                .padding()
                .foregroundColor(.white)
                .background(selectedImages.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(10)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Pilih Foto")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showSavedAlert) {
                Alert(title: Text("Berhasil"),
                      message: Text("Gambar berhasil disimpan ke galeri"),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Logic

    func toggleSelection(for image: UIImage) {
        if selectedImages.contains(image) {
            selectedImages.remove(image)
        } else {
            selectedImages.insert(image)
        }
    }

    func saveSelectedImages() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                for image in selectedImages {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }

                DispatchQueue.main.async {
                    showSavedAlert = true
                    selectedImages.removeAll()
                }
            } else {
                print("Akses galeri ditolak")
            }
        }
    }
}

#Preview {
    SelectPhoto()
}
