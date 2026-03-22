//
//  MagicEyeConverter.swift
//  Magic Sight
//
//  Created by Gemini on 21/03/2026.
//

import UIKit
import OSLog

struct MagicEyeConverter {
    private static let logger = Logger(subsystem: "com.magic-sight.app", category: "Converter")
    
    struct ConversionResult {
        let leftImage: UIImage
        let rightImage: UIImage
        let depthMap: [[Float]]
        let depthMapImage: UIImage?
    }
    
    /// Main entry point for converting a Magic Eye image into a stereoscopic pair.
    static func convertToSpatial(image: UIImage, basePeriod: Int) async -> ConversionResult? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        logger.info("Starting conversion. Width: \(width), Height: \(height), Base Period: \(basePeriod)")
        
        // 1. Extract raw disparity map
        let rawDepthMap = await extractDisparityMap(cgImage: cgImage, period: basePeriod)
        
        // 2. Refine depth map
        let refinedDepthMap = refineDepthMap(rawDepthMap, width: width, height: height, basePeriod: Float(basePeriod))
        
        // 3. Create depth map image for debugging/preview
        let depthImage = createDepthMapImage(refinedDepthMap, width: width, height: height)
        
        // 4. Generate stereo pair using DIBR
        let (left, right) = generateStereoPair(image: image, depthMap: refinedDepthMap)
        
        return ConversionResult(leftImage: left, rightImage: right, depthMap: refinedDepthMap, depthMapImage: depthImage)
    }
    
    private static func extractDisparityMap(cgImage: CGImage, period: Int) async -> [[Float]] {
        let width = cgImage.width
        let height = cgImage.height
        
        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return [] }
        
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        var depthMap = Array(repeating: Array(repeating: Float(0), count: width), count: height)
        
        // Define search range around the base period
        let searchRange = 30
        let minSearch = max(10, period - searchRange)
        let maxSearch = min(period + searchRange, width / 2)
        
        // Optimization: Process rows in parallel
        await withTaskGroup(of: (Int, [Float]).self) { group in
            for y in 0..<height {
                group.addTask {
                    var rowDepth = [Float](repeating: 0, count: width)
                    let rowOffset = y * bytesPerRow
                    
                    for x in 0..<width {
                        var bestShift = period
                        var minSAD: Double = .greatestFiniteMagnitude
                        
                        // Sliding window
                        let windowSize = 2 // Small window for sharp detail
                        
                        for shift in minSearch...maxSearch {
                            var currentSAD: Double = 0
                            
                            for wx in -windowSize...windowSize {
                                let targetX = x + wx
                                let sourceX = targetX - shift
                                
                                if sourceX >= 0 && targetX < width {
                                    let p1Offset = rowOffset + (targetX * bytesPerPixel)
                                    let p2Offset = rowOffset + (sourceX * bytesPerPixel)
                                    
                                    let dr = Int(bytes[p1Offset]) - Int(bytes[p2Offset])
                                    let dg = Int(bytes[p1Offset+1]) - Int(bytes[p2Offset+1])
                                    let db = Int(bytes[p1Offset+2]) - Int(bytes[p2Offset+2])
                                    
                                    currentSAD += Double(dr*dr + dg*dg + db*db)
                                }
                            }
                            
                            if currentSAD < minSAD {
                                minSAD = currentSAD
                                bestShift = shift
                            }
                        }
                        
                        // In Magic Eye, closer objects have a SMALLER period (pixels are shifted towards each other)
                        // So if bestShift < basePeriod, it is "closer" (higher depth)
                        rowDepth[x] = Float(bestShift)
                    }
                    return (y, rowDepth)
                }
            }
            
            for await (y, row) in group {
                depthMap[y] = row
            }
        }
        
        return depthMap
    }
    
    private static func refineDepthMap(_ raw: [[Float]], width: Int, height: Int, basePeriod: Float) -> [[Float]] {
        var refined = raw
        
        // 1. Median filter (horizontal only to preserve object boundaries which are mostly vertical/diagonal)
        let radius = 3
        for y in 0..<height {
            for x in radius..<(width - radius) {
                var neighbors: [Float] = []
                for nx in -radius...radius {
                    neighbors.append(raw[y][x + nx])
                }
                neighbors.sort()
                refined[y][x] = neighbors[neighbors.count / 2]
            }
        }
        
        // 2. Normalization
        // In autostereograms, basePeriod is the "background". 
        // Anything < basePeriod is "closer" (foreground).
        // Let's find the actual range.
        var minVal: Float = .greatestFiniteMagnitude
        var maxVal: Float = -.greatestFiniteMagnitude
        
        for y in 0..<height {
            for x in 0..<width {
                minVal = min(minVal, refined[y][x])
                maxVal = max(maxVal, refined[y][x])
            }
        }
        
        // Invert so that smaller period (closer) = higher depth value (1.0)
        // And larger period (background) = lower depth value (0.0)
        if maxVal > minVal {
            for y in 0..<height {
                for x in 0..<width {
                    let normalized = (refined[y][x] - minVal) / (maxVal - minVal)
                    refined[y][x] = 1.0 - normalized // Invert: smaller period is closer
                }
            }
        }
        
        return refined
    }
    
    private static func createDepthMapImage(_ depthMap: [[Float]], width: Int, height: Int) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
      guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        
        guard let data = context.data else { return nil }
        let pixelBuffer = data.assumingMemoryBound(to: UInt8.self)
        
        for y in 0..<height {
            for x in 0..<width {
                pixelBuffer[y * width + x] = UInt8(depthMap[y][x] * 255.0)
            }
        }
        
        if let cgImage = context.makeImage() {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    private static func generateStereoPair(image: UIImage, depthMap: [[Float]]) -> (UIImage, UIImage) {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let maxShift = 30 // Slightly more for better effect
        
        guard let cgImage = image.cgImage,
              let sourceData = cgImage.dataProvider?.data,
              let sourceBytes = CFDataGetBytePtr(sourceData) else { return (image, image) }
        
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        func createImage(isRight: Bool) -> UIImage {
            guard let context = CGContext(data: nil,
                                         width: width,
                                         height: height,
                                         bitsPerComponent: 8,
                                         bytesPerRow: width * 4,
                                          space: colorSpace,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
            
            let targetBytes = context.data!.assumingMemoryBound(to: UInt8.self)
            
            for y in 0..<height {
                for x in 0..<width {
                    let depth = depthMap[y][x]
                    // Shift left for left eye, right for right eye relative to center
                    let shift = Int(Float(maxShift/2) * depth)
                    let targetX = isRight ? (x - shift) : (x + shift)
                    
                    if targetX >= 0 && targetX < width {
                        let sourceOffset = (y * bytesPerRow) + (x * bytesPerPixel)
                        let targetOffset = (y * width * 4) + (targetX * 4)
                        
                        targetBytes[targetOffset] = sourceBytes[sourceOffset]
                        targetBytes[targetOffset + 1] = sourceBytes[sourceOffset + 1]
                        targetBytes[targetOffset + 2] = sourceBytes[sourceOffset + 2]
                        targetBytes[targetOffset + 3] = sourceBytes[sourceOffset + 3]
                    }
                }
            }
            
            return context.makeImage().map { UIImage(cgImage: $0) } ?? image
        }
        
        return (createImage(isRight: false), createImage(isRight: true))
    }
}
