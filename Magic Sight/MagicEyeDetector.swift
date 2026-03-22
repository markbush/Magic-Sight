//
//  MagicEyeDetector.swift
//  Magic Sight
//

import UIKit
import OSLog

struct MagicEyeDetector {
    private static let logger = Logger(subsystem: "com.magic-sight.app", category: "Detector")
    private static let minDisplacement = 10
    
    /// Detects if the given UIImage appears to be an autostereogram.
    /// Returns the detected period if found.
    static func detectMagicEye(in image: UIImage, ratioThreshold: Double, gradientThreshold: Double) async -> Int? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let sampleLinesCount = min(50, height)
        var testedLines: [Int] = []
        let delta = Double(height) / Double(sampleLinesCount)
        for i in 0..<sampleLinesCount {
            testedLines.append(Int(Double(i) * delta))
        }
        
        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        let maxDisplacement = width / 3
        var differences: [Double] = []
        
        var linePixelData: [[(r: Int, g: Int, b: Int)]] = []
        for y in testedLines {
            var row: [(r: Int, g: Int, b: Int)] = []
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let pixelOffset = rowOffset + (x * bytesPerPixel)
                row.append((
                    r: Int(bytes[pixelOffset]),
                    g: Int(bytes[pixelOffset + 1]),
                    b: Int(bytes[pixelOffset + 2])
                ))
            }
            linePixelData.append(row)
        }
        
        for displacement in minDisplacement...maxDisplacement {
            var totalDifference: Double = 0
            var pixelCount: Int = 0
            
            for rowPixels in linePixelData {
                for x in displacement..<width {
                    let p1 = rowPixels[x]
                    let p2 = rowPixels[x - displacement]
                    
                    let diff = Double(abs(p1.r - p2.r) + abs(p1.g - p2.g) + abs(p1.b - p2.b)) / 3.0
                    totalDifference += diff
                    pixelCount += 1
                }
            }
            
            differences.append(totalDifference / Double(pixelCount))
        }
        
        guard differences.count > 3 else { return nil }
        
        var highestGradientIndex = 1
        var highestGradient: Double = -1.0
        
        for i in 2..<(differences.count - 1) {
            let gradient = differences[i + 1] - differences[i]
            if gradient > highestGradient {
                highestGradient = gradient
                highestGradientIndex = i
            }
        }
        
        var bestIndex = highestGradientIndex
        for _ in 0..<5 {
            if bestIndex > 0 && differences[bestIndex - 1] < differences[bestIndex] {
                bestIndex -= 1
            }
        }
        
        let bestDisplacement = bestIndex + minDisplacement
        let minDiff = differences[bestIndex]
        let avgDiff = differences.reduce(0, +) / Double(differences.count)
        let ratio = minDiff / avgDiff
        
        logger.info("Best Displacement: \(bestDisplacement), Ratio: \(ratio, format: .fixed(precision: 3)), Max Gradient: \(highestGradient, format: .fixed(precision: 2))")
        
        if ratio < ratioThreshold && highestGradient > gradientThreshold {
            logger.info("Magic Eye DETECTED! Period: \(bestDisplacement)")
            return bestDisplacement
        }
        
        return nil
    }
}
