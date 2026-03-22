//
//  MagicEyeImageView.swift
//  Magic Sight
//
//  Created by Mark Bush on 21/03/2026.
//

import SwiftUI

struct MagicEyeImageView: View {
    let image: UIImage
    let fileName: String?
    let isMagicEye: Bool
    let isScanning: Bool
    let isConverting: Bool
    let onConvert: () -> Void
    
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()

                if isScanning || isConverting {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(24)
                } else if isMagicEye {
                    Button {
                        onConvert()
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
            
            if let fileName = fileName {
                Text(fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
