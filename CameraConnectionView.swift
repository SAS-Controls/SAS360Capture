//
//  CameraConnectionView.swift
//  SAS360Capture
//
//  Insta360 Camera connection and capture
//

import SwiftUI
import Combine
import AVFoundation

struct CameraConnectionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var cameraManager = Insta360CameraManager()
    
    var onPhotoCaptured: ((UIImage) -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    connectionStatusCard
                    
                    if cameraManager.isConnected {
                        cameraInfoCard
                        captureControls
                    } else {
                        connectionInstructions
                    }
                    
                    Spacer()
                    
                    if !cameraManager.statusLog.isEmpty {
                        statusLogView
                    }
                }
                .padding()
            }
            .navigationTitle("Insta360 Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
            .onAppear {
                cameraManager.startDetecting()
            }
            .onDisappear {
                cameraManager.stopDetecting()
            }
            .onChange(of: cameraManager.capturedPhoto) { _, photo in
                if let photo = photo {
                    onPhotoCaptured?(photo)
                }
            }
        }
    }
    
    private var connectionStatusCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(.sasTextPrimary)
                
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.sasTextSecondary)
            }
            
            Spacer()
            
            if cameraManager.isConnected {
                Button(action: { cameraManager.disconnect() }) {
                    Text("Disconnect")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.sasError)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else if !cameraManager.isDetecting {
                Button(action: { cameraManager.startDetecting() }) {
                    Text("Connect")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.sasBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.sasCardBg)
        .cornerRadius(12)
        .padding(.bottom)
    }
    
    private var statusColor: Color {
        switch cameraManager.connectionState {
        case .connected: return .sasSuccess
        case .detecting: return .sasWarning
        case .disconnected: return .sasTextSecondary
        case .failed: return .sasError
        }
    }
    
    private var statusTitle: String {
        switch cameraManager.connectionState {
        case .connected: return "Connected"
        case .detecting: return "Searching..."
        case .disconnected: return "Not Connected"
        case .failed: return "Connection Failed"
        }
    }
    
    private var statusSubtitle: String {
        switch cameraManager.connectionState {
        case .connected: return "Insta360 camera ready"
        case .detecting: return "Looking for Insta360 camera"
        case .disconnected: return "Tap Connect to start"
        case .failed: return cameraManager.errorMessage
        }
    }
    
    private var cameraInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.sasBlue)
                Text("Insta360 Camera")
                    .font(.headline)
                    .foregroundColor(.sasTextPrimary)
                Spacer()
            }
            
            if let state = cameraManager.captureStateDescription {
                HStack {
                    Text("Status:")
                        .foregroundColor(.sasTextSecondary)
                    Spacer()
                    Text(state)
                        .foregroundColor(.sasOrange)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color.sasCardBg)
        .cornerRadius(12)
        .padding(.bottom)
    }
    
    private var captureControls: some View {
        VStack(spacing: 16) {
            Text("Capture")
                .font(.headline)
                .foregroundColor(.sasTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: { cameraManager.capturePhoto() }) {
                ZStack {
                    Circle()
                        .stroke(Color.sasOrange, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(cameraManager.isCapturing ? Color.gray : Color.sasOrange)
                        .frame(width: 65, height: 65)
                    
                    if cameraManager.isCapturing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(cameraManager.isCapturing)
            
            Text(cameraManager.isCapturing ? "Capturing 360° photo..." : "Tap to capture 360° photo")
                .font(.caption)
                .foregroundColor(.sasTextSecondary)
        }
        .padding()
        .background(Color.sasCardBg)
        .cornerRadius(12)
    }
    
    private var connectionInstructions: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 50))
                .foregroundColor(.sasTextSecondary)
            
            Text("Connect Your Insta360")
                .font(.headline)
                .foregroundColor(.sasTextPrimary)
            
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: 1, text: "Turn on your Insta360 camera")
                instructionRow(number: 2, text: "Connect camera to iPhone via WiFi or USB")
                instructionRow(number: 3, text: "Tap Connect above")
            }
            .padding()
            .background(Color.sasCardBg)
            .cornerRadius(12)
            
            if cameraManager.isDetecting {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .sasOrange))
                    Text("Searching for camera...")
                        .foregroundColor(.sasTextSecondary)
                }
            }
        }
        .padding()
        .background(Color.sasCardBg)
        .cornerRadius(12)
    }
    
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.sasBlue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.sasTextPrimary)
        }
    }
    
    private var statusLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity Log")
                .font(.caption)
                .foregroundColor(.sasTextSecondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cameraManager.statusLog, id: \.self) { log in
                        Text(log)
                            .font(.caption2)
                            .foregroundColor(.sasTextSecondary)
                    }
                }
            }
            .frame(maxHeight: 80)
        }
        .padding()
        .background(Color.sasCardBg)
        .cornerRadius(12)
    }
}

// MARK: - Connection State
enum Insta360ConnectionState {
    case disconnected
    case detecting
    case connected
    case failed
}

// MARK: - Insta360 Camera Manager
class Insta360CameraManager: NSObject, ObservableObject {
    @Published var connectionState: Insta360ConnectionState = .disconnected
    @Published var isCapturing = false
    @Published var capturedPhoto: UIImage?
    @Published var errorMessage = ""
    @Published var statusLog: [String] = []
    @Published var captureStateDescription: String?
    
    private var liteCameraManager: INSLiteCameraManager?
    private var photoCapturer: INSLitePhotoCapturer?
    private var currentCaptureSession: INSLiteCaptureSession?
    private var stateObservation: NSKeyValueObservation?
    
    var isConnected: Bool { connectionState == .connected }
    var isDetecting: Bool { connectionState == .detecting }
    
    override init() {
        super.init()
    }
    
    deinit {
        stopDetecting()
    }
    
    // MARK: - Camera Detection
    func startDetecting() {
        log("Starting camera detection...")
        connectionState = .detecting
        
        liteCameraManager = INSLiteCameraManager(previewView: nil)
        
        // KVO on cameraState
        stateObservation = liteCameraManager?.observe(\.cameraState, options: [.new, .initial]) { [weak self] manager, _ in
            DispatchQueue.main.async {
                self?.handleCameraStateChange(manager.cameraState)
            }
        }
        
        liteCameraManager?.startDetecting()
    }
    
    func stopDetecting() {
        log("Stopping detection")
        stateObservation?.invalidate()
        stateObservation = nil
        liteCameraManager?.disconnect()
        liteCameraManager = nil
        connectionState = .disconnected
    }
    
    func disconnect() {
        log("Disconnecting camera")
        liteCameraManager?.disconnect()
        connectionState = .disconnected
        captureStateDescription = nil
    }
    
    private func handleCameraStateChange(_ state: INSLiteCameraState) {
        switch state {
        case .noConnection:
            log("No camera connected")
            if connectionState == .detecting {
                // Keep detecting
            } else {
                connectionState = .disconnected
            }
            
        case .failed:
            log("Camera detection failed")
            connectionState = .failed
            errorMessage = "Could not connect to camera"
            
        case .connected:
            log("Camera connected!")
            connectionState = .connected
            setupPhotoCapturer()
            
        @unknown default:
            log("Unknown camera state")
        }
    }
    
    // MARK: - Photo Capture
    private func setupPhotoCapturer() {
        photoCapturer = INSLitePhotoCapturer()
        photoCapturer?.delegate = self
        log("Photo capturer ready")
    }
    
    func capturePhoto() {
        guard isConnected, let capturer = photoCapturer else {
            log("Cannot capture - not connected")
            return
        }
        
        log("Starting 360° capture...")
        isCapturing = true
        capturedPhoto = nil
        
        let options = INSLitePhotoCaptureOptions.default()
        let session = INSLiteCaptureSession(options: options)
        currentCaptureSession = session
        
        capturer.runCaptureSession(session)
    }
    
    func cancelCapture() {
        guard let session = currentCaptureSession else { return }
        log("Cancelling capture")
        photoCapturer?.cancelCaptureSession(session)
        isCapturing = false
    }
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            self.statusLog.append(logEntry)
            if self.statusLog.count > 20 {
                self.statusLog.removeFirst()
            }
        }
        print("Insta360: \(message)")
    }
}

// MARK: - INSLitePhotoCapturerDelegate
extension Insta360CameraManager: INSLitePhotoCapturerDelegate {
    
    func capturer(_ capturer: INSLitePhotoCapturer, didComplete captureSession: INSLiteCaptureSession, with photo: INSLitePhoto) {
        log("Capture complete!")
        
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = false
            self?.captureStateDescription = "Complete"
            
            // Get the image from the photo object
            // Note: The actual property name may vary - check SDK documentation
            if let image = photo.value(forKey: "image") as? UIImage {
                self?.capturedPhoto = image
                self?.log("360° photo captured successfully")
            } else if let imageData = photo.value(forKey: "imageData") as? Data,
                      let image = UIImage(data: imageData) {
                self?.capturedPhoto = image
                self?.log("360° photo captured successfully")
            } else {
                self?.log("Warning: Could not extract image from photo result")
            }
        }
        
        currentCaptureSession = nil
    }
    
    func capturer(_ capturer: INSLitePhotoCapturer, didCancel captureSession: INSLiteCaptureSession, with error: Error) {
        log("Capture cancelled: \(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = false
            self?.errorMessage = error.localizedDescription
            self?.captureStateDescription = "Cancelled"
        }
        
        currentCaptureSession = nil
    }
    
    func capturer(_ capturer: INSLitePhotoCapturer, didUpdate captureSession: INSLiteCaptureSession, state: INSLiteCaptureState, info: [AnyHashable: Any]?) {
        let stateDescription = descriptionForCaptureState(state)
        log("Capture state: \(stateDescription)")
        
        DispatchQueue.main.async { [weak self] in
            self?.captureStateDescription = stateDescription
        }
    }
    
    private func descriptionForCaptureState(_ state: INSLiteCaptureState) -> String {
        switch state {
        case .notStarted: return "Not Started"
        case .detectFirstDevice: return "Detecting front lens..."
        case .switchToSecondDevice: return "Switching to back lens..."
        case .detectSecondDevice: return "Detecting back lens..."
        case .prepareFirstPhoto: return "Preparing front capture..."
        case .captureFirstPhoto: return "Capturing front..."
        case .switchToFirstDevice: return "Switching to front lens..."
        case .prepareSecondPhoto: return "Preparing back capture..."
        case .captureSecondPhoto: return "Capturing back..."
        case .captureComplete: return "Stitching 360° photo..."
        @unknown default: return "Processing..."
        }
    }
}

#Preview {
    CameraConnectionView()
        .environmentObject(DataManager())
}
