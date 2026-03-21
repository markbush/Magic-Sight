//
//  MagicEyeImageView.swift
//  Magic Sight
//
//  Created by Mark Bush on 21/03/2026.
//


import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
struct MagicEyeImageView: View {
    let image: UIImage
    let isMagicEye: Bool
    let isScanning: Bool
    @Binding var isShowingConversionAlert: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()

            if isScanning {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(24)
            } else if isMagicEye {
                Button {
                    isShowingConversionAlert = true
                } label: {
                    Image(systemName: "cube.transparent.fill")
                        .font(.system(size: 24))
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(24)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
