//
//  Models.swift
//  SAS360Capture
//
//  Data models for the tour capture system
//  Hierarchy: Customer → Facility → Project → Tour → Hotspots/Annotations
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Customer
struct Customer: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var notes: String = ""
    var facilities: [Facility] = []
    var createdAt: Date = Date()
    var lastModifiedAt: Date = Date()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Customer, rhs: Customer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Facility
struct Facility: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var address: String = ""
    var notes: String = ""
    var projects: [Project] = []
    var createdAt: Date = Date()
    var lastModifiedAt: Date = Date()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Facility, rhs: Facility) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Project
struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String = ""
    var tours: [Tour] = []
    var createdAt: Date = Date()
    var lastModifiedAt: Date = Date()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tour
struct Tour: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var floorPlanImagePath: String?
    var hotspots: [Hotspot] = []
    var floorPlanDrawing: FloorPlanDrawing?
    var createdAt: Date = Date()
    var lastModifiedAt: Date = Date()
    
    // For unassigned tours (Quick Scan)
    var isAssigned: Bool = true
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Tour, rhs: Tour) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Floor Plan Drawing
struct FloorPlanDrawing: Codable, Hashable {
    var shapes: [DrawingShape] = []
    var labels: [DrawingLabel] = []
    var canvasWidth: CGFloat = 1000
    var canvasHeight: CGFloat = 1000
    
    var canvasSize: CGSize {
        get { CGSize(width: canvasWidth, height: canvasHeight) }
        set {
            canvasWidth = newValue.width
            canvasHeight = newValue.height
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(shapes)
        hasher.combine(labels)
    }
}

// MARK: - Drawing Shape
struct DrawingShape: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: ShapeType
    var startPoint: CodablePoint
    var endPoint: CodablePoint
    var strokeColor: String = "sasBlue"
    var strokeWidth: CGFloat = 2
    
    enum ShapeType: String, Codable {
        case rectangle
        case line
        case polygon
        case arc
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Drawing Label
struct DrawingLabel: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var position: CodablePoint
    var fontSize: CGFloat = 14
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Codable Point (for CGPoint compatibility)
struct CodablePoint: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
    
    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
    
    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Hotspot
struct Hotspot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var position: CodablePoint  // Position on floor plan
    var photo360Path: String?   // Path to 360° photo
    var linkedHotspotIds: [UUID] = []  // Connected hotspots for navigation
    var annotations: [Annotation] = []
    var createdAt: Date = Date()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Hotspot, rhs: Hotspot) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Annotation
struct Annotation: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: AnnotationType
    var position: SphericalPosition  // Position in 360° space
    var content: String  // Note text or detail photo path
    var title: String = ""  // Short title/name
    var description: String = ""  // Longer description
    var category: AnnotationCategory = .general
    var tags: [String] = []  // Searchable tags
    var author: String = ""
    var createdAt: Date = Date()
    
    enum AnnotationType: String, Codable {
        case note      // Text note
        case photo     // High-res detail photo
    }
    
    enum AnnotationCategory: String, Codable, CaseIterable {
        case general = "General"
        case equipment = "Equipment"
        case electrical = "Electrical"
        case mechanical = "Mechanical"
        case plumbing = "Plumbing"
        case safety = "Safety"
        case maintenance = "Maintenance"
        case issue = "Issue/Problem"
        case measurement = "Measurement"
        case reference = "Reference"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Spherical Position (for 360° space)
struct SphericalPosition: Codable, Hashable {
    var yaw: Double    // Horizontal angle (0-360)
    var pitch: Double  // Vertical angle (-90 to 90)
    
    init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }
}

// MARK: - Camera Connection State
enum CameraConnectionState: String, Codable {
    case disconnected
    case connecting
    case connected
    case error
}

// MARK: - Camera Info
struct CameraInfo: Codable {
    var model: String
    var batteryLevel: Int
    var storageUsed: Int64
    var storageTotal: Int64
    var firmwareVersion: String
    
    var batteryPercentage: Int {
        return batteryLevel
    }
    
    var storagePercentage: Double {
        guard storageTotal > 0 else { return 0 }
        return Double(storageUsed) / Double(storageTotal) * 100
    }
    
    var storageAvailableGB: Double {
        return Double(storageTotal - storageUsed) / 1_073_741_824
    }
}

// MARK: - App Settings
struct AppSettings: Codable, Equatable {
    var authorName: String = ""
    var autoSaveEnabled: Bool = true
    var highResolutionCapture: Bool = true
    var hapticFeedbackEnabled: Bool = true
    var showHotspotLabels: Bool = true
    var defaultTransitionStyle: TransitionStyle = .walk
    
    enum TransitionStyle: String, Codable, CaseIterable, Equatable {
        case instant = "Instant"
        case fade = "Fade"
        case walk = "Walk Animation"
    }
}

// Note: CGSize is already Codable in iOS 15+, so we use a wrapper for older compatibility
struct CodableSize: Codable, Hashable {
    var width: CGFloat
    var height: CGFloat
    
    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    init(_ size: CGSize) {
        self.width = size.width
        self.height = size.height
    }
    
    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}
