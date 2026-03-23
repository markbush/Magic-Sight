//
//  MagicEyeExportService.swift
//  Magic Sight
//
//  Created by Mark Bush on 21/03/2026.
//

import UIKit
import ImageIO
import UniformTypeIdentifiers
import OSLog

struct MagicEyeExportService {
  private static let logger = Logger(subsystem: "com.magic-sight.app", category: "ExportService")
  
  /// A 3x3 identity rotation matrix.
  private static let identityRotation: [Double] = [
    1, 0, 0,
    0, 1, 0,
    0, 0, 1
  ]
  
  /// Returns a 3x3 intrinsics matrix for a simplified pinhole camera model.
  private static func calculateIntrinsics(width: Int, height: Int, horizontalFOV: Double) -> [Double] {
    let w = Double(width)
    let h = Double(height)
    let horizontalFOVInRadians = horizontalFOV / 180.0 * .pi
    let focalLengthX = (w * 0.5) / (tan(horizontalFOVInRadians * 0.5))
    let focalLengthY = focalLengthX
    let principalPointX = 0.5 * w
    let principalPointY = 0.5 * h
    return [
      focalLengthX, 0, principalPointX,
      0, focalLengthY, principalPointY,
      0, 0, 1
    ]
  }
  
  /// Creates a Spatial Photo (HEIC) from a stereo pair and returns the temporary URL.
  static func createSpatialPhoto(result: MagicEyeConverter.ConversionResult, fileName: String) async -> URL? {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("\(fileName)_Spatial.heic")
    
    guard let leftCgImage = result.leftImage.cgImage,
          let rightCgImage = result.rightImage.cgImage else { return nil }
    
    let width = leftCgImage.width
    let height = leftCgImage.height
    
    // Create a HEIC image destination
    // Use UTType.heic.identifier which is "public.heic"
    guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.heic.identifier as CFString, 2, nil) else {
      logger.error("Failed to create image destination.")
      return nil
    }
    
    // Global Container Properties
    // kCGImagePropertyPrimaryImage: 0 (literal "PrimaryImage")
    let containerProperties: [CFString: Any] = [
      kCGImagePropertyPrimaryImage: 0
    ]
    CGImageDestinationSetProperties(destination, containerProperties as CFDictionary)
    
    let horizontalFOV = 60.0
    let baselineInMeters = 0.064 // 64mm
    let intrinsics = calculateIntrinsics(width: width, height: height, horizontalFOV: horizontalFOV)
    
    // Metadata construction using literal strings to avoid scope errors
    func createProperties(isLeft: Bool) -> [CFString: Any] {
      let position = isLeft ? [0.0, 0.0, 0.0] : [baselineInMeters, 0.0, 0.0]
      
      return [
        kCGImagePropertyGroups: [
          kCGImagePropertyGroupIndex: 0,
          kCGImagePropertyGroupType: kCGImagePropertyGroupTypeStereoPair,
          (isLeft ? kCGImagePropertyGroupImageIsLeftImage : kCGImagePropertyGroupImageIsRightImage): true,
          kCGImagePropertyGroupImageDisparityAdjustment: 0 // 0 encoded as Int
        ],
        kCGImagePropertyHEIFDictionary: [
          kIIOMetadata_CameraExtrinsicsKey: [
            kIIOCameraExtrinsics_Position: position,
            kIIOCameraExtrinsics_Rotation: identityRotation
          ],
          kIIOMetadata_CameraModelKey: [
            kIIOCameraModel_Intrinsics: intrinsics,
            kIIOCameraModel_ModelType: kIIOCameraModelType_SimplifiedPinhole
          ]
        ],
        kCGImagePropertyHasAlpha: false
      ]
    }
    
    // Add Left Eye
    CGImageDestinationAddImage(destination, leftCgImage, createProperties(isLeft: true) as CFDictionary)
    
    // Add Right Eye
    CGImageDestinationAddImage(destination, rightCgImage, createProperties(isLeft: false) as CFDictionary)
    
    if CGImageDestinationFinalize(destination) {
      logger.info("Successfully exported Spatial Photo to: \(fileURL.path)")
      return fileURL
    } else {
      logger.error("Failed to finalize image destination.")
      return nil
    }
  }
}

