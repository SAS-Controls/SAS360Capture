//
//  CameraConnectionView.swift
//  SAS360Capture
//
//  Insta360 Camera connection - SDK integration pending
//

import SwiftUI
import Combine

struct CameraConnectionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Camera icon
                        Image(systemName: "camera.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.sasOrange)
                            .padding(.top, 40)
                        
                        Text("Insta360 Camera")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.sasTextPrimary)
                        
                        // Status card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SDK Status")
                                .font(.headline)
                                .foregroundColor(.sasTextPrimary)
                            
                            statusRow(
                                icon: "exclamationmark.triangle.fill",
                                title: "Missing Dependency",
                                detail: "NvEffectSdkCore.framework not included in SDK",
                                color: .sasWarning
                            )
                            
                            statusRow(
                                icon: "envelope.fill",
                                title: "Contact Insta360",
                                detail: "Request complete SDK from developer support",
                                color: .sasBlue
                            )
                            
                            Button(action: openInsta360Support) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Insta360 Developer Portal")
                                }
                                .font(.subheadline)
                                .foregroundColor(.sasBlue)
                            }
                            .padding(.leading, 36)
                        }
                        .padding()
                        .background(Color.sasCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Alternatives card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Now")
                                .font(.headline)
                                .foregroundColor(.sasTextPrimary)
                            
                            statusRow(
                                icon: "checkmark.circle.fill",
                                title: "iPhone Panorama",
                                detail: "Capture panoramas using your iPhone camera",
                                color: .sasSuccess
                            )
                            
                            statusRow(
                                icon: "checkmark.circle.fill",
                                title: "Import 360° Photos",
                                detail: "Import existing equirectangular images",
                                color: .sasSuccess
                            )
                            
                            statusRow(
                                icon: "checkmark.circle.fill",
                                title: "All Other Features",
                                detail: "Floor plans, hotspots, annotations, tours",
                                color: .sasSuccess
                            )
                        }
                        .padding()
                        .background(Color.sasCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: { dismiss() }) {
                                HStack {
                                    Image(systemName: "iphone")
                                    Text("Use iPhone Panorama")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.sasBlue)
                                .cornerRadius(10)
                            }
                            
                            Button(action: { dismiss() }) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Import 360° Photos")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.sasOrange)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
        }
    }
    
    private func statusRow(icon: String, title: String, detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.sasTextPrimary)
                
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.sasTextSecondary)
            }
            
            Spacer()
        }
    }
    
    private func openInsta360Support() {
        if let url = URL(string: "https://www.insta360.com/developer/home") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Placeholder types for compatibility
@MainActor
class Insta360CameraManager: ObservableObject {
    @Published var connectionState: Insta360ConnectionState = .disconnected
    @Published var isCapturing: Bool = false
    @Published var capturedPhoto: UIImage? = nil
    @Published var errorMessage: String = "SDK not available"
    @Published var statusLog: [String] = []
    @Published var captureStateDescription: String? = nil
    
    var isConnected: Bool { false }
    var isDetecting: Bool { false }
    
    init() {}
    
    func startDetecting() {}
    func stopDetecting() {}
    func disconnect() {}
    func capturePhoto() {}
}

enum Insta360ConnectionState {
    case disconnected
    case detecting
    case connected
    case failed
}

#Preview {
    CameraConnectionView()
        .environmentObject(DataManager())
}
