//
//  PanoramaCaptureView.swift
//  SAS360Capture
//
//  iPhone-based panorama capture with rotation guide
//

import SwiftUI
import AVFoundation
import CoreMotion
import Combine

struct PanoramaCaptureView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var captureManager = PanoramaCaptureManager()
    
    var onComplete: (UIImage) -> Void
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(captureManager: captureManager)
                .ignoresSafeArea()
            
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Rotation guide wheel
                if captureManager.isMotionActive {
                    RotationGuideView(
                        currentAngle: captureManager.currentYaw,
                        capturedAngles: captureManager.capturedAngles,
                        targetCount: 8
                    )
                    .frame(width: 220, height: 220)
                    .padding(.bottom, 20)
                }
                
                // Instructions
                instructionsView
                    .padding(.bottom, 20)
                
                // Capture button
                captureButton
                    .padding(.bottom, 50)
            }
            
            // Processing overlay
            if captureManager.isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            captureManager.startSession()
            captureManager.startMotionUpdates()
        }
        .onDisappear {
            captureManager.stopSession()
            captureManager.stopMotionUpdates()
        }
        .onChange(of: captureManager.completedImage) { _, image in
            if let image = image {
                onComplete(image)
                dismiss()
            }
        }
        .alert("Error", isPresented: $captureManager.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(captureManager.errorMessage)
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("\(captureManager.capturedCount) / 8")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            
            Spacer()
            
            if captureManager.capturedCount >= 2 {
                Button(action: { captureManager.createPanorama() }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.sasOrange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                }
            } else {
                Color.clear.frame(width: 70, height: 44)
            }
        }
        .padding()
    }
    
    private var instructionsView: some View {
        VStack(spacing: 8) {
            if captureManager.capturedCount == 0 {
                Text("📸 Tap to take first photo")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("Then rotate ~45° for each shot")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else if captureManager.capturedCount < 8 {
                Text("Rotate and tap to capture")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("\(8 - captureManager.capturedCount) more needed")
                    .font(.caption)
                    .foregroundColor(.sasOrange)
            } else {
                Text("✅ Tap Done to create panorama")
                    .font(.subheadline)
                    .foregroundColor(.sasSuccess)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    private var captureButton: some View {
        HStack(spacing: 60) {
            // Reset
            Button(action: { captureManager.reset() }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                    Text("Reset")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(width: 60)
            }
            .opacity(captureManager.capturedCount > 0 ? 1 : 0.3)
            .disabled(captureManager.capturedCount == 0)
            
            // Capture
            Button(action: { captureManager.capturePhoto() }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 5)
                        .frame(width: 85, height: 85)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundColor(.black)
                }
            }
            
            // Create
            Button(action: { captureManager.createPanorama() }) {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    Text("Create")
                        .font(.caption)
                }
                .foregroundColor(captureManager.capturedCount >= 2 ? .sasSuccess : .gray)
                .frame(width: 60)
            }
            .opacity(captureManager.capturedCount >= 2 ? 1 : 0.3)
            .disabled(captureManager.capturedCount < 2)
        }
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .sasOrange))
                    .scaleEffect(2)
                
                Text("Creating panorama...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Rotation Guide View
struct RotationGuideView: View {
    let currentAngle: Double
    let capturedAngles: [Double]
    let targetCount: Int
    
    var body: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
            
            // Target markers (8 positions)
            ForEach(0..<targetCount, id: \.self) { index in
                let angle = Double(index) * (360.0 / Double(targetCount))
                let isCaptured = capturedAngles.contains { abs($0 - angle) < 25 || abs($0 - angle) > 335 }
                
                Circle()
                    .fill(isCaptured ? Color.sasSuccess : Color.white.opacity(0.5))
                    .frame(width: isCaptured ? 16 : 10, height: isCaptured ? 16 : 10)
                    .offset(y: -95)
                    .rotationEffect(.degrees(angle))
            }
            
            // Current position (white dot)
            Circle()
                .fill(Color.sasOrange)
                .frame(width: 18, height: 18)
                .shadow(color: .sasOrange, radius: 5)
                .offset(y: -95)
                .rotationEffect(.degrees(currentAngle))
            
            // Center crosshair
            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(.white.opacity(0.5))
            
            // Angle text
            Text("\(Int(currentAngle))°")
                .font(.caption)
                .foregroundColor(.white)
                .offset(y: 40)
        }
    }
}

// MARK: - Camera Preview (UIKit wrapper)
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var captureManager: PanoramaCaptureManager
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = captureManager.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update if needed
    }
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Panorama Capture Manager
class PanoramaCaptureManager: NSObject, ObservableObject {
    @Published var capturedCount = 0
    @Published var capturedAngles: [Double] = []
    @Published var currentYaw: Double = 0
    @Published var isProcessing = false
    @Published var isMotionActive = false
    @Published var completedImage: UIImage?
    @Published var showError = false
    @Published var errorMessage = ""
    
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private let motionManager = CMMotionManager()
    private var capturedImageData: [Data] = []  // Store compressed data, not UIImage
    private var referenceYaw: Double?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high  // Use .high instead of .photo to save memory
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No camera available")
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("Camera input error: \(error)")
            session.commitConfiguration()
            return
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.05
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            self.isMotionActive = true
            
            var yaw = -motion.attitude.yaw * 180 / .pi  // Inverted for correct direction
            
            // Set reference on first reading
            if self.referenceYaw == nil {
                self.referenceYaw = yaw
            }
            
            // Normalize to 0-360 from reference
            yaw = yaw - (self.referenceYaw ?? 0)
            if yaw < 0 { yaw += 360 }
            if yaw >= 360 { yaw -= 360 }
            
            self.currentYaw = yaw
        }
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isMotionActive = false
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // Haptic
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func reset() {
        capturedImageData = []
        capturedAngles = []
        capturedCount = 0
        completedImage = nil
        referenceYaw = nil
    }
    
    func createPanorama() {
        guard capturedImageData.count >= 2 else { return }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            autoreleasepool {
                let result = self.stitchImages()
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if let result = result {
                        self.completedImage = result
                    } else {
                        self.errorMessage = "Failed to create panorama"
                        self.showError = true
                    }
                }
            }
        }
    }
    
    private func stitchImages() -> UIImage? {
        // Load and scale images one at a time to save memory
        var scaledImages: [UIImage] = []
        
        for data in capturedImageData {
            autoreleasepool {
                if let image = UIImage(data: data) {
                    let scaled = scaleImage(image, maxHeight: 600)
                    scaledImages.append(scaled)
                }
            }
        }
        
        guard !scaledImages.isEmpty else { return nil }
        
        // Calculate dimensions
        let overlap: CGFloat = 0.3
        var totalWidth: CGFloat = 0
        let height = scaledImages.first?.size.height ?? 600
        
        for (i, img) in scaledImages.enumerated() {
            if i == 0 {
                totalWidth += img.size.width
            } else {
                totalWidth += img.size.width * (1 - overlap)
            }
        }
        
        // Create panorama
        UIGraphicsBeginImageContextWithOptions(CGSize(width: totalWidth, height: height), true, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        var xOffset: CGFloat = 0
        for (i, img) in scaledImages.enumerated() {
            img.draw(at: CGPoint(x: xOffset, y: 0))
            xOffset += img.size.width * (i == 0 ? (1 - overlap) : (1 - overlap))
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func scaleImage(_ image: UIImage, maxHeight: CGFloat) -> UIImage {
        let scale = maxHeight / image.size.height
        if scale >= 1 { return image }
        
        let newSize = CGSize(width: image.size.width * scale, height: maxHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result ?? image
    }
}

// MARK: - Photo Delegate
extension PanoramaCaptureManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation() else {
            print("Photo capture error: \(error?.localizedDescription ?? "unknown")")
            return
        }
        
        // Compress immediately to save memory
        autoreleasepool {
            if let image = UIImage(data: data),
               let compressed = image.jpegData(compressionQuality: 0.5) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.capturedImageData.append(compressed)
                    self.capturedAngles.append(self.currentYaw)
                    self.capturedCount = self.capturedImageData.count
                }
            }
        }
    }
}
