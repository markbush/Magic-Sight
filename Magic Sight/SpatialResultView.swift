//
//  SpatialResultView.swift
//  Magic Sight
//
//  Created by Mark Bush on 21/03/2026.
//

import SwiftUI
import CoreMotion
internal import Combine

struct SpatialResultView: View {
    @ObservedObject var viewModel: MagicSightViewModel
    let result: MagicEyeConverter.ConversionResult
    let fileName: String?
    
    @StateObject private var motionManager = MotionManager()
    @State private var showDepthMap = false
    
    var body: some View {
        VStack {
            if showDepthMap, let depthImage = result.depthMapImage {
                VStack {
                    Spacer()
                    Image(uiImage: depthImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                    
                    Spacer()

                    if let fileName = fileName {
                        Text("\(fileName) (Depth Map)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack {
                    GeometryReader { geometry in
                        ZStack {
                            // Left eye image (shifted left)
                            Image(uiImage: result.leftImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .offset(x: -motionManager.roll * 20)
                            
                            // Right eye image (shifted right)
                            Image(uiImage: result.rightImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .offset(x: motionManager.roll * 20)
                                .blendMode(.multiply)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    
                    Spacer()

                    if let fileName = fileName {
                        Text("\(fileName) (3D Result)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
                        
            Toggle("Show Depth Map", isOn: $showDepthMap)
                .padding()
        }
        .navigationTitle("Spatial Result")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isExporting {
                    ProgressView()
                } else {
                    Button {
                        viewModel.exportResult()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .onChange(of: viewModel.exportedURL) { oldValue, newValue in
            if let url = newValue {
                shareFile(url: url)
            }
        }
        .onAppear {
            motionManager.start()
        }
        .onDisappear {
            motionManager.stop()
        }
    }
    
    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
}

class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    
    @Published var pitch: CGFloat = 0
    @Published var roll: CGFloat = 0
    
    func start() {
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 60.0
            motion.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data else { return }
                self?.pitch = CGFloat(data.attitude.pitch)
                self?.roll = CGFloat(data.attitude.roll)
            }
        }
    }
    
    func stop() {
        motion.stopDeviceMotionUpdates()
    }
}
