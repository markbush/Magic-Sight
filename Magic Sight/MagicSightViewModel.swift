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
import Photos
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
            detectedPeriod = nil
            conversionResult = nil
            if let image = selectedImage {
                analyzeImage(image)
            } else {
                selectedFileName = nil
            }
        }
    }
    
    @Published var selectedFileName: String?
    @Published var isMagicEye = false
    @Published var detectedPeriod: Int?
    @Published var isScanning = false
    @Published var isConverting = false
    @Published var isExporting = false
    @Published var exportedURL: URL?
    
    @Published var conversionResult: MagicEyeConverter.ConversionResult?
    
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
        
        // Attempt to get the original filename from Photos library
        Task {
            if let identifier = item.itemIdentifier {
                logger.debug("Fetching PHAsset for identifier: \(identifier)")
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                if let asset = result.firstObject {
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let filename = resources.first?.originalFilename {
                        let name = (filename as NSString).deletingPathExtension
                        logger.info("Found original filename: \(name)")
                        await MainActor.run {
                            self.selectedFileName = name
                        }
                    } else {
                        logger.warning("No original filename found in resources.")
                        await MainActor.run { self.selectedFileName = "Photo" }
                    }
                } else {
                    logger.warning("PHAsset not found for identifier.")
                    await MainActor.run { self.selectedFileName = "Photo" }
                }
            } else {
                logger.warning("No itemIdentifier for PhotosPickerItem.")
                await MainActor.run { self.selectedFileName = "Photo" }
            }
        }
        
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
        selectedFileName = url.deletingPathExtension().lastPathComponent
        
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
        isConverting = false
        isExporting = false
        detectedPeriod = nil
        conversionResult = nil
        exportedURL = nil
        selectedFileName = nil
        imagePickerItem = nil
        errorMessage = nil
    }

    func exportResult() {
        guard let result = conversionResult else { return }
        
        isExporting = true
        errorMessage = nil
        
        Task {
            let url = await MagicEyeExportService.createSpatialPhoto(
                result: result,
                fileName: selectedFileName ?? "MagicSight"
            )
            
            await MainActor.run {
                self.exportedURL = url
                self.isExporting = false
            }
        }
    }

    func convertImage() {
        guard let image = selectedImage, let period = detectedPeriod else { return }
        
        isConverting = true
        errorMessage = nil
        conversionResult = nil // Reset so that a new result always triggers navigation
        
        Task {
            if let result = await MagicEyeConverter.convertToSpatial(image: image, basePeriod: period) {
                await MainActor.run {
                    self.conversionResult = result
                    self.isConverting = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Failed to convert image."
                    self.isConverting = false
                }
            }
        }
    }

    private func reAnalyzeIfNeeded() {
        if let image = selectedImage {
            analyzeImage(image)
        }
    }

    private func analyzeImage(_ image: UIImage) {
        isMagicEye = false
        detectedPeriod = nil
        isScanning = true
        Task {
            let result = await MagicEyeDetector.detectMagicEye(
                in: image,
                ratioThreshold: detectionRatio,
                gradientThreshold: detectionGradient
            )
            
            await MainActor.run {
                self.detectedPeriod = result
                self.isMagicEye = (result != nil)
                self.isScanning = false
                self.logger.info("Image analysis complete. isMagicEye: \(self.isMagicEye)")
            }
        }
    }
}
