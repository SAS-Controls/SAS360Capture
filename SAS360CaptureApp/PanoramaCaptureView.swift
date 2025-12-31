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
                        targetCount: 8,
                        isAligned: captureManager.isAlignedWithTarget
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
                Text("Align circle with green dot")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("Then tap to capture")
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
            
            // Capture - only enabled when aligned
            Button(action: { captureManager.capturePhoto() }) {
                ZStack {
                    Circle()
                        .stroke(captureManager.canCapture ? Color.white : Color.gray, lineWidth: 5)
                        .frame(width: 85, height: 85)
                    
                    Circle()
                        .fill(captureManager.canCapture ? Color.white : Color.gray.opacity(0.5))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundColor(captureManager.canCapture ? .black : .gray)
                }
            }
            .disabled(!captureManager.canCapture)
            
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
    let isAligned: Bool
    
    private let alignmentCircleSize: CGFloat = 40
    
    var body: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
            
            // Target markers (8 positions) - green dots
            ForEach(0..<targetCount, id: \.self) { index in
                let angle = Double(index) * (360.0 / Double(targetCount))
                let isCaptured = isAngleCaptured(angle)
                
                Circle()
                    .fill(isCaptured ? Color.sasSuccess : Color.sasSuccess.opacity(0.6))
                    .frame(width: 14, height: 14)
                    .offset(y: -95)
                    .rotationEffect(.degrees(angle))
            }
            
            // Alignment circle - moves with current position
            Circle()
                .stroke(isAligned ? Color.sasSuccess : Color.white.opacity(0.8), lineWidth: 3)
                .frame(width: alignmentCircleSize, height: alignmentCircleSize)
                .offset(y: -95)
                .rotationEffect(.degrees(currentAngle))
            
            // Degree display
            Text("\(Int(currentAngle))°")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .offset(y: 30)
        }
    }
    
    private func isAngleCaptured(_ targetAngle: Double) -> Bool {
        for captured in capturedAngles {
            let diff = abs(captured - targetAngle)
            if diff < 25 || diff > 335 {
                return true
            }
        }
        return false
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var captureManager: PanoramaCaptureManager
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = captureManager.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    
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
    @Published var isAlignedWithTarget = false
    
    var canCapture: Bool {
        if capturedCount == 0 {
            return isAlignedWithTarget
        }
        return isAlignedWithTarget && !isCurrentPositionCaptured()
    }
    
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private let motionManager = CMMotionManager()
    private var capturedImageData: [Data] = []
    private var referenceYaw: Double?
    
    private let targetAngles: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
    private let alignmentThreshold: Double = 15.0
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
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
    
    // WORKING MOTION CODE FROM YESTERDAY - DO NOT CHANGE
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.05
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            self.isMotionActive = true
            
            // Negative sign for correct direction (rotate right = clockwise on screen)
            var yaw = -motion.attitude.yaw * 180 / .pi
            
            // Set reference on first reading
            if self.referenceYaw == nil {
                self.referenceYaw = yaw
            }
            
            // Normalize to 0-360 from reference
            yaw = yaw - (self.referenceYaw ?? 0)
            if yaw < 0 { yaw += 360 }
            if yaw >= 360 { yaw -= 360 }
            
            self.currentYaw = yaw
            self.updateAlignment()
        }
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isMotionActive = false
    }
    
    private func updateAlignment() {
        isAlignedWithTarget = targetAngles.contains { target in
            let diff = abs(currentYaw - target)
            return diff < alignmentThreshold || diff > (360 - alignmentThreshold)
        }
    }
    
    private func isCurrentPositionCaptured() -> Bool {
        for captured in capturedAngles {
            let diff = abs(currentYaw - captured)
            if diff < 25 || diff > 335 {
                return true
            }
        }
        return false
    }
    
    func capturePhoto() {
        guard canCapture else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        
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
        // Sort images by capture angle
        let sortedPairs = zip(capturedImageData, capturedAngles)
            .sorted { $0.1 < $1.1 }
        
        var scaledImages: [UIImage] = []
        
        for (data, _) in sortedPairs {
            autoreleasepool {
                if let image = UIImage(data: data) {
                    let scaled = scaleImage(image, maxHeight: 600)
                    scaledImages.append(scaled)
                }
            }
        }
        
        guard !scaledImages.isEmpty else { return nil }
        
        // Simple side-by-side concatenation for now
        // OpenCV stitching was hanging - will debug separately
        let height = scaledImages.first?.size.height ?? 600
        let totalWidth = scaledImages.reduce(0) { $0 + $1.size.width }
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: totalWidth, height: height), true, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        var xOffset: CGFloat = 0
        for img in scaledImages {
            img.draw(at: CGPoint(x: xOffset, y: 0))
            xOffset += img.size.width
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
