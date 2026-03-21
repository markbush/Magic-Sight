//
//  ThresholdSettingsMenu.swift
//  Magic Sight
//
//  Created by Mark Bush on 21/03/2026.
//

import SwiftUI

struct ThresholdSettingsMenu: View {
    @ObservedObject var viewModel: MagicSightViewModel
    
    var body: some View {
        Menu {
            Section("Detection Thresholds") {
                Stepper(value: $viewModel.detectionRatio, in: 0...1, step: 0.05) {
                    Text("Ratio: \(viewModel.detectionRatio.formatted(.number.precision(.fractionLength(2))))")
                }
                Stepper(value: $viewModel.detectionGradient, in: 1...5, step: 0.1) {
                    Text("Gradient: \(viewModel.detectionGradient.formatted(.number.precision(.fractionLength(1))))")
                }
            }
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
}
