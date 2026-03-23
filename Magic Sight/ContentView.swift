//
//  ContentView.swift
//  Magic Sight
//
//  Created by Mark Bush on 21/03/2026.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    @StateObject private var viewModel: MagicSightViewModel
    @State private var isShowingFileImporter = false
    @State private var isShowingSpatialResult = false
    
    init(viewModel: MagicSightViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? MagicSightViewModel())
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if let image = viewModel.selectedImage {
                    MagicEyeImageView(
                        image: image,
                        fileName: viewModel.selectedFileName,
                        isMagicEye: viewModel.isMagicEye,
                        isScanning: viewModel.isScanning,
                        isConverting: viewModel.isConverting,
                        onConvert: {
                            viewModel.convertImage()
                        }
                    )
                } else {
                    ContentUnavailableView {
                        Label("No Image Selected", systemImage: "photo.on.rectangle")
                    } description: {
                        Text("Select an autostereogram from your Photos or Files.")
                    }
                }
            }
            .navigationTitle("Magic Sight")
            .navigationDestination(isPresented: $isShowingSpatialResult) {
                if let result = viewModel.conversionResult {
                    SpatialResultView(
                        viewModel: viewModel,
                        result: result,
                        fileName: viewModel.selectedFileName
                    )
                }
            }
            .onChange(of: viewModel.conversionResult != nil) { oldValue, newValue in
                if newValue {
                    isShowingSpatialResult = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ThresholdSettingsMenu(viewModel: viewModel)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.selectedImage != nil {
                        Button("Clear") {
                            viewModel.clearImage()
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    PhotosPicker(selection: $viewModel.imagePickerItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Label("Photos", systemImage: "photo.fill")
                    }
                    
                    Spacer()
                    
                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label("Files", systemImage: "folder.fill")
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.loadImage(from: url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading image...")
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(8)
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
}

#Preview("Empty State") { @MainActor in
    ContentView()
}

#Preview("Loaded Image") { @MainActor in
    let viewModel = MagicSightViewModel()
    viewModel.selectedImage = UIImage(systemName: "photo.artframe")
    return ContentView(viewModel: viewModel)
}

#Preview("Magic Eye State") { @MainActor in
    let viewModel = MagicSightViewModel()
    viewModel.selectedImage = UIImage(named: "shark")
    return ContentView(viewModel: viewModel)
}
