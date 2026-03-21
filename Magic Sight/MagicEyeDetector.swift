//
//  MagicEyeDetector.swift
//  Magic Sight
//
//  Created by Mark Bush on 21/03/2026.
//

// The algorithm in this file is based on the stereogram-solver
// application by Jérémie Piellard:
// https://github.com/piellardj/stereogram-solver
// It has been modified to allow the thresholds to be modified
// by the user.

import UIKit
import OSLog

struct MagicEyeDetector {
    private static let logger = Logger(subsystem: "com.magic-sight.app", category: "Detector")
    private static let minDisplacement = 10
    
    /// Detects if the given UIImage appears to be an autostereogram.
    /// Returns true if a strong horizontal repeating pattern is found using a gradient-based approach.
    static func detectMagicEye(in image: UIImage, ratioThreshold: Double, gradientThreshold: Double) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Use a significant number of lines as in the TS code
        let sampleLinesCount = min(50, height)
        var testedLines: [Int] = []
        let delta = Double(height) / Double(sampleLinesCount)
        for i in 0..<sampleLinesCount {
            testedLines.append(Int(Double(i) * delta))
        }
        
        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return false }
        
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        let maxDisplacement = width / 3
        var differences: [Double] = []
        
        // Pre-extract pixel data for the tested lines to speed up the triple loop
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
        
        guard differences.count > 3 else { return false }
        
        // Find highest gradient (steepest rise after the minimum)
        var highestGradientIndex = 1
        var highestGradient: Double = -1.0
        
        for i in 2..<(differences.count - 1) {
            let gradient = differences[i + 1] - differences[i]
            if gradient > highestGradient {
                highestGradient = gradient
                highestGradientIndex = i
            }
        }
        
        // Refine by looking back for the actual minimum plateau before the rise
        var bestIndex = highestGradientIndex
        for _ in 0..<5 {
            if bestIndex > 0 && differences[bestIndex - 1] < differences[bestIndex] {
                bestIndex -= 1
            }
        }
        
        let bestDisplacement = bestIndex + minDisplacement
        let minDiff = differences[bestIndex]
        
        // Calculate average difference of all tested displacements for comparison
        let avgDiff = differences.reduce(0, +) / Double(differences.count)
        
        // Detection Logic:
        // A valid Magic Eye should have a significantly lower minimum compared to the average,
        // and a relatively steep rise (highestGradient) following it.
        let ratio = minDiff / avgDiff
        
      logger.info("Best Displacement: \(bestDisplacement), Min Diff: \(minDiff, format: .fixed(precision: 2)), Avg Diff: \(avgDiff, format: .fixed(precision: 2)), Ratio: \(ratio, format: .fixed(precision: 3)), Max Gradient: \(highestGradient, format: .fixed(precision: 2))")
        
        // Thresholds based on empirical observation of magic eye patterns vs random images
        // Ratio < 0.6 means the minimum is 40% lower than the average.
        // Highest gradient should be positive and reasonably large.
        if ratio < ratioThreshold && highestGradient > gradientThreshold {
            logger.info("Magic Eye DETECTED!")
            return true
        }
        
        return false
    }
}
