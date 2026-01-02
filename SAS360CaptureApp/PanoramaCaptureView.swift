//
//  PanoramaCaptureView.swift
//  SAS360Capture
//
//  Matterport-style panorama capture using ARKit for stable world-anchored dots
//

import SwiftUI
import ARKit
import SceneKit
import Combine

struct PanoramaCaptureView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var captureManager = ARPanoramaCaptureManager()
    
    var onComplete: (UIImage) -> Void
    
    var body: some View {
        ZStack {
            // AR View with camera and overlaid dots
            ARPanoramaViewContainer(captureManager: captureManager)
                .ignoresSafeArea()
            
            // Dotted line from center to next target (2D overlay)
            if let targetScreenPos = captureManager.nextTargetScreenPosition {
                DottedLineOverlay(targetPosition: targetScreenPos)
            }
            
            // Center reticle (SwiftUI overlay - always centered)
            ReticleOverlay(
                isSettling: captureManager.isSettling,
                isCapturing: captureManager.isCapturing,
                progress: captureManager.captureProgress
            )
            
            // Top bar
            VStack {
                topBar
                Spacer()
            }
            
            // Instructions at bottom
            VStack {
                Spacer()
                instructionsView
                    .padding(.bottom, 60)
            }
            
            // Processing overlay
            if captureManager.isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            captureManager.startSession()
        }
        .onDisappear {
            captureManager.pauseSession()
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
            
            // Pass indicator
            VStack(spacing: 2) {
                Text(captureManager.currentPass == .level ? "Level Pass" : "Tilt Up 30°")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(captureManager.currentPassCaptured) / \(captureManager.photosPerPass)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
            
            Spacer()
            
            // Undo button
            Button(action: { captureManager.undoLastCapture() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                        .font(.caption)
                }
                .font(.title3)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            }
            .opacity(captureManager.capturedCount > 0 ? 1 : 0.3)
            .disabled(captureManager.capturedCount == 0)
        }
        .padding()
    }
    
    private var instructionsView: some View {
        VStack(spacing: 8) {
            if !captureManager.isARReady {
                Text("Initializing AR...")
                    .font(.headline)
                    .foregroundColor(.sasOrange)
                Text("Move phone slowly to scan environment")
                    .font(.caption)
                    .foregroundColor(.white)
            } else if captureManager.currentPass == .tiltedUp && captureManager.currentPassCaptured == 0 {
                Text("Tilt phone up ~30°")
                    .font(.headline)
                    .foregroundColor(.sasOrange)
                Text("Then aim at the next dot")
                    .font(.caption)
                    .foregroundColor(.white)
            } else if captureManager.isSettling {
                Text("Hold steady...")
                    .font(.headline)
                    .foregroundColor(.sasOrange)
            } else if captureManager.isCapturing {
                Text("Capturing...")
                    .font(.headline)
                    .foregroundColor(.sasSuccess)
            } else {
                Text("Aim at next dot")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Hold steady to capture")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .sasOrange))
                    .scaleEffect(2)
                
                Text("Creating panorama...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("This may take a moment")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Dotted Line Overlay
struct DottedLineOverlay: View {
    let targetPosition: CGPoint
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            // Only draw if target is not at center (i.e., not already aligned)
            let distance = hypot(targetPosition.x - center.x, targetPosition.y - center.y)
            
            if distance > 50 {
                Path { path in
                    path.move(to: center)
                    path.addLine(to: targetPosition)
                }
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                .foregroundColor(Color.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Reticle Overlay (SwiftUI)
struct ReticleOverlay: View {
    let isSettling: Bool
    let isCapturing: Bool
    let progress: Double
    
    var color: Color {
        if isCapturing { return .sasSuccess }
        if isSettling { return .sasOrange }
        return .white
    }
    
    var body: some View {
        ZStack {
            // Progress ring
            if progress > 0 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.sasOrange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
            }
            
            // Outer ring
            Circle()
                .stroke(color, lineWidth: 3)
                .frame(width: 70, height: 70)
            
            // Crosshairs
            Rectangle()
                .fill(color)
                .frame(width: 24, height: 2)
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 24)
        }
        .opacity(0.9)
    }
}

// MARK: - AR View Container
struct ARPanoramaViewContainer: UIViewRepresentable {
    @ObservedObject var captureManager: ARPanoramaCaptureManager
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session.delegate = context.coordinator
        arView.automaticallyUpdatesLighting = true
        arView.rendersContinuously = true
        
        captureManager.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(captureManager: captureManager)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        let captureManager: ARPanoramaCaptureManager
        
        init(captureManager: ARPanoramaCaptureManager) {
            self.captureManager = captureManager
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            captureManager.processFrame(frame)
        }
        
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            DispatchQueue.main.async {
                switch camera.trackingState {
                case .normal:
                    self.captureManager.isARReady = true
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Capture Pass Enum
enum ARCapturePass {
    case level
    case tiltedUp
}

// MARK: - Target Info
class ARTargetInfo {
    var node: SCNNode
    var isCaptured: Bool = false
    let worldPosition: SIMD3<Float>
    
    init(node: SCNNode, worldPosition: SIMD3<Float>) {
        self.node = node
        self.worldPosition = worldPosition
    }
}

// MARK: - AR Panorama Capture Manager
class ARPanoramaCaptureManager: ObservableObject {
    // Published state
    @Published var capturedCount = 0
    @Published var isProcessing = false
    @Published var completedImage: UIImage?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var captureProgress: Double = 0
    @Published var isSettling = false
    @Published var isCapturing = false
    @Published var currentPass: ARCapturePass = .level
    @Published var isARReady = false
    @Published var nextTargetScreenPosition: CGPoint?
    
    // AR View reference
    weak var arView: ARSCNView?
    
    // Targets
    let photosPerPass = 7
    private var levelTargets: [ARTargetInfo] = []
    private var tiltedTargets: [ARTargetInfo] = []
    private var hasPlacedTargets = false
    
    // Captured data
    private var capturedImageData: [Data] = []
    private var capturedAngles: [(yaw: Float, pitch: Float)] = []
    
    // Alignment tracking
    private var settleStartTime: Date?
    private var captureStartTime: Date?
    private let settlingDuration: TimeInterval = 0.5
    private let captureDuration: TimeInterval = 1.0
    private let alignmentThreshold: Float = 0.12  // Radians (~7 degrees)
    
    // Distance to place dots (in meters)
    private let dotDistance: Float = 2.5
    
    var currentPassTargets: [ARTargetInfo] {
        currentPass == .level ? levelTargets : tiltedTargets
    }
    
    var currentPassCaptured: Int {
        currentPassTargets.filter { $0.isCaptured }.count
    }
    
    var nextTargetIndex: Int? {
        currentPassTargets.firstIndex(where: { !$0.isCaptured })
    }
    
    // MARK: - Session Control
    func startSession() {
        guard let arView = arView else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true
        
        // Select a video format without aggressive cropping
        // Look for 1920x1440 or similar 4:3 format which uses more of the sensor
        let supportedFormats = ARWorldTrackingConfiguration.supportedVideoFormats
        if let preferredFormat = supportedFormats.first(where: { format in
            // 4:3 formats use more of the sensor = wider effective FOV
            let ratio = format.imageResolution.width / format.imageResolution.height
            return ratio < 1.5 // 4:3 = 1.33, 16:9 = 1.78
        }) {
            configuration.videoFormat = preferredFormat
        }
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        hasPlacedTargets = false
        isARReady = false
    }
    
    func pauseSession() {
        arView?.session.pause()
    }
    
    // MARK: - Frame Processing
    func processFrame(_ frame: ARFrame) {
        // Wait for good tracking before placing targets
        if !hasPlacedTargets && frame.camera.trackingState == .normal {
            placeTargetsInWorld(from: frame)
            hasPlacedTargets = true
        }
        
        guard hasPlacedTargets else { return }
        
        // Update visual appearance of targets
        updateTargetVisuals(frame: frame)
        
        // Update next target screen position for dotted line
        updateNextTargetScreenPosition(frame: frame)
        
        // Check if we're aligned with next target
        checkAlignment(frame: frame)
    }
    
    private func placeTargetsInWorld(from frame: ARFrame) {
        guard let arView = arView else { return }
        
        let cameraTransform = frame.camera.transform
        let cameraPos = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        
        // Get initial forward direction (horizontal only)
        let forward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let horizontalForward = normalize(SIMD3<Float>(forward.x, 0, forward.z))
        let initialYaw = atan2(horizontalForward.x, horizontalForward.z)
        
        let angleStep = Float.pi * 2 / Float(photosPerPass)
        
        // Create level targets (around horizon) - CLOCKWISE (negative angle)
        for i in 0..<photosPerPass {
            let yaw = initialYaw - Float(i) * angleStep  // Negative for clockwise
            
            let x = cameraPos.x + dotDistance * sin(yaw)
            let y = cameraPos.y  // Same height as camera
            let z = cameraPos.z + dotDistance * cos(yaw)
            
            let worldPos = SIMD3<Float>(x, y, z)
            let node = createTargetNode()
            node.position = SCNVector3(x, y, z)
            node.look(at: SCNVector3(cameraPos.x, cameraPos.y, cameraPos.z))
            
            arView.scene.rootNode.addChildNode(node)
            levelTargets.append(ARTargetInfo(node: node, worldPosition: worldPos))
        }
        
        // Create tilted targets (25° up, offset by half step) - CLOCKWISE
        let tiltAngle: Float = 25 * .pi / 180
        for i in 0..<photosPerPass {
            let yaw = initialYaw - Float(i) * angleStep - (angleStep / 2)  // Negative for clockwise
            
            let horizontalDist = dotDistance * cos(tiltAngle)
            let x = cameraPos.x + horizontalDist * sin(yaw)
            let y = cameraPos.y + dotDistance * sin(tiltAngle)
            let z = cameraPos.z + horizontalDist * cos(yaw)
            
            let worldPos = SIMD3<Float>(x, y, z)
            let node = createTargetNode()
            node.position = SCNVector3(x, y, z)
            node.look(at: SCNVector3(cameraPos.x, cameraPos.y, cameraPos.z))
            node.isHidden = true  // Hide until level pass done
            
            arView.scene.rootNode.addChildNode(node)
            tiltedTargets.append(ARTargetInfo(node: node, worldPosition: worldPos))
        }
    }
    
    private func createTargetNode() -> SCNNode {
        let node = SCNNode()
        
        // Main ring
        let ringGeometry = SCNTorus(ringRadius: 0.08, pipeRadius: 0.012)
        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = UIColor.white
        ringMaterial.emission.contents = UIColor.white.withAlphaComponent(0.5)
        ringGeometry.materials = [ringMaterial]
        
        let ringNode = SCNNode(geometry: ringGeometry)
        ringNode.name = "ring"
        node.addChildNode(ringNode)
        
        // Center sphere
        let sphereGeometry = SCNSphere(radius: 0.025)
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = UIColor.white
        sphereMaterial.emission.contents = UIColor.white.withAlphaComponent(0.5)
        sphereGeometry.materials = [sphereMaterial]
        
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.name = "center"
        node.addChildNode(sphereNode)
        
        return node
    }
    
    private func updateNextTargetScreenPosition(frame: ARFrame) {
        guard let arView = arView,
              let targetIndex = nextTargetIndex else {
            DispatchQueue.main.async {
                self.nextTargetScreenPosition = nil
            }
            return
        }
        
        let target = currentPassTargets[targetIndex]
        let worldPos = target.worldPosition
        
        // Project world position to screen coordinates
        let screenPos = arView.projectPoint(SCNVector3(worldPos.x, worldPos.y, worldPos.z))
        
        // Check if point is in front of camera (z < 1 means in front)
        if screenPos.z < 1 {
            DispatchQueue.main.async {
                self.nextTargetScreenPosition = CGPoint(x: CGFloat(screenPos.x), y: CGFloat(screenPos.y))
            }
        } else {
            // Target is behind camera, don't show line
            DispatchQueue.main.async {
                self.nextTargetScreenPosition = nil
            }
        }
    }
    
    private func updateTargetVisuals(frame: ARFrame) {
        // Find the next uncaptured target index for current pass
        let nextIdx = nextTargetIndex
        
        // Update level targets
        for (index, target) in levelTargets.enumerated() {
            let isNext = (currentPass == .level && index == nextIdx)
            updateNodeAppearance(target.node, isCaptured: target.isCaptured, isNext: isNext)
            target.node.isHidden = false
        }
        
        // Update tilted targets
        for (index, target) in tiltedTargets.enumerated() {
            let isNext = (currentPass == .tiltedUp && index == nextIdx)
            updateNodeAppearance(target.node, isCaptured: target.isCaptured, isNext: isNext)
            target.node.isHidden = (currentPass == .level)
        }
    }
    
    private func updateNodeAppearance(_ node: SCNNode, isCaptured: Bool, isNext: Bool) {
        let color: UIColor
        let scale: Float
        
        if isCaptured {
            color = UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0)  // Green
            scale = 1.0
        } else if isNext {
            color = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)  // Orange
            scale = 1.3
        } else {
            color = UIColor.white.withAlphaComponent(0.6)
            scale = 0.8
        }
        
        node.scale = SCNVector3(scale, scale, scale)
        
        for child in node.childNodes {
            if let geometry = child.geometry {
                geometry.materials.first?.diffuse.contents = color
                geometry.materials.first?.emission.contents = color.withAlphaComponent(0.5)
            }
        }
    }
    
    // MARK: - Alignment Check
    private func checkAlignment(frame: ARFrame) {
        guard let targetIndex = nextTargetIndex, !isCapturing else {
            resetAlignmentState()
            return
        }
        
        let target = currentPassTargets[targetIndex]
        
        // Camera info
        let cameraTransform = frame.camera.transform
        let cameraPos = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let cameraForward = -normalize(SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z))
        
        // Direction to target
        let toTarget = normalize(target.worldPosition - cameraPos)
        
        // Angle between camera forward and target
        let dotProduct = simd_dot(cameraForward, toTarget)
        let clampedDot = max(-1.0, min(1.0, dotProduct))
        let angle = acos(clampedDot)
        
        if angle < alignmentThreshold {
            // Aligned with target
            if settleStartTime == nil {
                settleStartTime = Date()
            }
            
            let settleElapsed = Date().timeIntervalSince(settleStartTime!)
            
            if settleElapsed >= settlingDuration {
                // Done settling, start capture countdown
                DispatchQueue.main.async { self.isSettling = false }
                
                if captureStartTime == nil {
                    captureStartTime = Date()
                }
                
                let captureElapsed = Date().timeIntervalSince(captureStartTime!)
                let progress = min(captureElapsed / captureDuration, 1.0)
                
                DispatchQueue.main.async { self.captureProgress = progress }
                
                if progress >= 1.0 {
                    capturePhoto(frame: frame, targetIndex: targetIndex)
                }
            } else {
                // Still settling
                DispatchQueue.main.async {
                    self.isSettling = true
                    self.captureProgress = 0
                }
            }
        } else {
            resetAlignmentState()
        }
    }
    
    private func resetAlignmentState() {
        settleStartTime = nil
        captureStartTime = nil
        DispatchQueue.main.async {
            self.isSettling = false
            self.captureProgress = 0
        }
    }
    
    // MARK: - Photo Capture
    private func capturePhoto(frame: ARFrame, targetIndex: Int) {
        guard !isCapturing else { return }
        
        DispatchQueue.main.async { self.isCapturing = true }
        
        // Capture the image
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            
            if let compressed = uiImage.jpegData(compressionQuality: 0.8) {
                capturedImageData.append(compressed)
                
                // Store angles
                let cameraForward = -SIMD3<Float>(frame.camera.transform.columns.2.x, frame.camera.transform.columns.2.y, frame.camera.transform.columns.2.z)
                let yaw = atan2(cameraForward.x, cameraForward.z)
                let pitch = asin(cameraForward.y)
                capturedAngles.append((yaw: yaw, pitch: pitch))
            }
        }
        
        // Mark as captured
        if currentPass == .level {
            levelTargets[targetIndex].isCaptured = true
        } else {
            tiltedTargets[targetIndex].isCaptured = true
        }
        
        DispatchQueue.main.async {
            self.capturedCount += 1
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        // Reset and check completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            self.isCapturing = false
            self.captureProgress = 0
            self.settleStartTime = nil
            self.captureStartTime = nil
            
            if self.currentPassCaptured >= self.photosPerPass {
                if self.currentPass == .level {
                    self.currentPass = .tiltedUp
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.createPanorama()
                    }
                }
            }
        }
    }
    
    func undoLastCapture() {
        if currentPass == .level {
            if let index = levelTargets.lastIndex(where: { $0.isCaptured }) {
                levelTargets[index].isCaptured = false
            }
        } else {
            if let index = tiltedTargets.lastIndex(where: { $0.isCaptured }) {
                tiltedTargets[index].isCaptured = false
            } else {
                // Go back to level pass
                currentPass = .level
                if let index = levelTargets.lastIndex(where: { $0.isCaptured }) {
                    levelTargets[index].isCaptured = false
                }
            }
        }
        
        if !capturedImageData.isEmpty {
            capturedImageData.removeLast()
            capturedAngles.removeLast()
        }
        
        capturedCount = max(0, capturedCount - 1)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Panorama Creation
    func createPanorama() {
        guard capturedImageData.count >= 2 else { return }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let result = self.stitchImagesWithBlending()
            
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
    
    private func stitchImagesWithBlending() -> UIImage? {
        // Sort by yaw angle (ascending for left-to-right panorama)
        let sortedPairs = zip(capturedImageData, capturedAngles)
            .sorted { $0.1.yaw < $1.1.yaw }
        
        var images: [UIImage] = []
        
        for (data, _) in sortedPairs {
            if let image = UIImage(data: data) {
                // Scale for memory efficiency
                let scaled = scaleImage(image, maxHeight: 1200)
                images.append(scaled)
            }
        }
        
        guard images.count >= 2 else { return images.first }
        
        // Calculate overlap percentage based on FOV and number of images
        // With 7 images covering 360°, each image covers ~51°
        // iPhone wide camera is ~65-70° FOV, so there should be ~15° overlap
        let overlapPercent: CGFloat = 0.25  // 25% overlap
        
        // Calculate final dimensions
        let imageWidth = images.first!.size.width
        let imageHeight = images.first!.size.height
        let effectiveWidth = imageWidth * (1 - overlapPercent)
        let totalWidth = effectiveWidth * CGFloat(images.count - 1) + imageWidth
        
        // Create output image
        UIGraphicsBeginImageContextWithOptions(CGSize(width: totalWidth, height: imageHeight), true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Fill with black
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: totalWidth, height: imageHeight))
        
        // Draw each image with blending
        for (index, image) in images.enumerated() {
            let xOffset = CGFloat(index) * effectiveWidth
            
            if index == 0 {
                // First image - draw fully
                image.draw(at: CGPoint(x: xOffset, y: 0))
            } else {
                // Create gradient mask for blending
                let overlapWidth = imageWidth * overlapPercent
                
                // Draw the image
                image.draw(at: CGPoint(x: xOffset, y: 0))
                
                // Apply gradient blend in overlap region
                if index > 0 {
                    let gradientRect = CGRect(x: xOffset, y: 0, width: overlapWidth, height: imageHeight)
                    
                    // Draw previous image's edge into overlap with gradient alpha
                    let prevImage = images[index - 1]
                    
                    // Create gradient
                    let colors = [UIColor.white.cgColor, UIColor.clear.cgColor]
                    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
                    
                    context.saveGState()
                    context.clip(to: gradientRect)
                    
                    // Draw cropped portion of previous image
                    let cropRect = CGRect(x: prevImage.size.width - overlapWidth, y: 0, width: overlapWidth, height: imageHeight)
                    if let croppedCG = prevImage.cgImage?.cropping(to: cropRect) {
                        let croppedImage = UIImage(cgImage: croppedCG)
                        
                        // Apply gradient mask
                        context.clip(to: gradientRect, mask: createGradientMask(size: gradientRect.size))
                        croppedImage.draw(in: gradientRect)
                    }
                    
                    context.restoreGState()
                }
            }
        }
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result
    }
    
    private func createGradientMask(size: CGSize) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: Int(size.width), space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        
        let colors = [UIColor.white.cgColor, UIColor.black.cgColor]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: 0), options: [])
        
        return context.makeImage()!
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

