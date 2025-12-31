//
//  PhotoImporterView.swift
//  SAS360Capture
//
//  Import 360° photos from photo library
//

import SwiftUI
import PhotosUI

struct PhotoImporterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    let tourId: UUID
    var onImport: (UIImage, String) -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Preview area
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.sasOrange, lineWidth: 2)
                            )
                        
                        Text("360° Photo Selected")
                            .font(.headline)
                            .foregroundColor(.sasSuccess)
                        
                        Text("\(Int(image.size.width)) x \(Int(image.size.height))")
                            .font(.caption)
                            .foregroundColor(.sasTextSecondary)
                        
                    } else {
                        // Photo picker
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 60))
                                    .foregroundColor(.sasBlue)
                                
                                Text("Select 360° Photo")
                                    .font(.headline)
                                    .foregroundColor(.sasTextPrimary)
                                
                                Text("Choose a 360° photo from your library")
                                    .font(.subheadline)
                                    .foregroundColor(.sasTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                            .background(Color.sasCardBg)
                            .cornerRadius(12)
                        }
                    }
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .sasOrange))
                            .scaleEffect(1.5)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.sasError)
                            .padding()
                            .background(Color.sasError.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        if selectedImage != nil {
                            Button(action: importPhoto) {
                                Text("Use This Photo")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.sasOrange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                selectedImage = nil
                                selectedItem = nil
                            }) {
                                Text("Choose Different Photo")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.sasCardBg)
                                    .foregroundColor(.sasTextPrimary)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationTitle("Import 360° Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                loadImage(from: newValue)
            }
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Could not load image"
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func importPhoto() {
        guard let image = selectedImage else { return }
        
        // Save to disk
        if let path = dataManager.save360Image(image, for: tourId, hotspotId: UUID()) {
            onImport(image, path)
            dismiss()
        } else {
            errorMessage = "Failed to save image"
        }
    }
}

// MARK: - Preview
#Preview {
    PhotoImporterView(tourId: UUID()) { _, _ in }
        .environmentObject(DataManager())
}
