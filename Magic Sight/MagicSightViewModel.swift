//
//  MagicSightViewModel.swift
//  Magic Sight
//
//  Created by Mark Bush on 21/03/2026.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import OSLog
internal import Combine

@MainActor
class MagicSightViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.magic-sight.app", category: "ViewModel")
    
    @AppStorage("detectionRatio") var detectionRatio: Double = 0.7 {
        didSet {
            reAnalyzeIfNeeded()
        }
    }
    @AppStorage("detectionGradient") var detectionGradient: Double = 2.0 {
        didSet {
            reAnalyzeIfNeeded()
        }
    }
    
    @Published var selectedImage: UIImage? {
        didSet {
            isMagicEye = false
            if let image = selectedImage {
                analyzeImage(image)
            }
        }
    }
    @Published var isMagicEye = false
    @Published var isScanning = false
    @Published var imagePickerItem: PhotosPickerItem? {
        didSet {
            if let item = imagePickerItem {
                loadTransferable(from: item)
            }
        }
    }
    
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadTransferable(from item: PhotosPickerItem) {
        isLoading = true
        errorMessage = nil
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let data?):
                    if let image = UIImage(data: data) {
                        self.selectedImage = image
                    } else {
                        self.errorMessage = "Failed to load image data"
                    }
                case .success(nil):
                    self.errorMessage = "No image data found"
                case .failure(let error):
                    self.errorMessage = "Error loading image: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func loadImage(from url: URL) {
        isLoading = true
        errorMessage = nil
        
        // Ensure access to security-scoped resource if needed
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            if let image = UIImage(data: data) {
                self.selectedImage = image
            } else {
                self.errorMessage = "Failed to load image from URL"
            }
        } catch {
            self.errorMessage = "Error reading file: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func clearImage() {
        selectedImage = nil
        isMagicEye = false
        isScanning = false
        imagePickerItem = nil
        errorMessage = nil
    }

    private func reAnalyzeIfNeeded() {
        if let image = selectedImage {
            analyzeImage(image)
        }
    }

    private func analyzeImage(_ image: UIImage) {
        isMagicEye = false
        isScanning = true
        Task {
            let result = await MagicEyeDetector.detectMagicEye(
                in: image,
                ratioThreshold: detectionRatio,
                gradientThreshold: detectionGradient
            )
            logger.info("Image analysis complete (Ratio: \(self.detectionRatio, format: .fixed(precision: 2)), Gradient: \(self.detectionGradient, format: .fixed(precision: 2))). isMagicEye: \(result, privacy: .public)")
            await MainActor.run {
                self.isMagicEye = result
                self.isScanning = false
            }
        }
    }
}
