//
//  SelectPhoto.swift
//  C4_Prime
//
//  Created by Richie Reuben Hermanto on 19/06/25.
//

import SwiftUI
import Photos

struct SelectPhoto: View {
    @Environment(\.presentationMode) var presentationMode
    
    let availableImages: [UIImage] = [
        UIImage(named: "front-double-bicep")!,
        UIImage(named: "Rectangle 2")!,
    ]

    @State private var selectedImages: Set<UIImage> = []
    @State private var showSavedAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {

                    ScrollView {
                        LazyVStack(spacing: 115) {
                            ForEach(availableImages, id: \.self) { image in
                                GeometryReader { geometry in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geometry.size.width, height: 300)
                                            .clipped()
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedImages.contains(image) ? Color.yellow : Color.clear, lineWidth: 4)
                                            )
                                            .onTapGesture {
                                                toggleSelection(for: image)
                                            }

                                        if selectedImages.contains(image) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 25))
                                                .foregroundColor(.yellow)
                                                .background(Color.black.clipShape(Circle()))
                                                .offset(x: -20, y: 251)
                                        }
                                    }
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    Text("Selected Photo: \(selectedImages.count)")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Spacer()
                }
                .padding(.top)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Select Photo")
        .navigationBarTitleDisplayMode(.inline)
      
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .foregroundColor(.yellow)
        })
        .navigationBarItems(trailing:
            Button("Done") {
                if !selectedImages.isEmpty {
                    saveSelectedImages()
                }
            }
            .foregroundColor(selectedImages.isEmpty ? .gray : .yellow)
            .disabled(selectedImages.isEmpty)
        )
        .alert(isPresented: $showSavedAlert) {
            Alert(
                title: Text("Berhasil"),
                message: Text("Gambar berhasil disimpan ke galeri"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

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
