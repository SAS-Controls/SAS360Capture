//
//  Viewer360View.swift
//  SAS360Capture
//
//  360° panoramic photo viewer with hotspot navigation and annotations
//

import SwiftUI
import SceneKit

struct Viewer360View: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @Binding var tour: Tour
    let customer: Customer?
    let facility: Facility?
    let project: Project?
    
    @State private var currentHotspot: Hotspot?
    @State private var showingAnnotationDetail = false
    @State private var showingAddAnnotation = false
    @State private var selectedAnnotation: Annotation?
    @State private var tapPosition: SphericalPosition?
    
    // Camera control
    @State private var yaw: Double = 0
    @State private var pitch: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let hotspot = currentHotspot,
               let path = hotspot.photo360Path,
               let image = UIImage(contentsOfFile: path) {
                // 360° viewer
                SceneView360(
                    image: image,
                    yaw: $yaw,
                    pitch: $pitch,
                    annotations: hotspot.annotations,
                    onAnnotationTap: { annotation in
                        selectedAnnotation = annotation
                        showingAnnotationDetail = true
                    },
                    onDoubleTap: { position in
                        tapPosition = position
                        showingAddAnnotation = true
                    }
                )
                .ignoresSafeArea()
                
                // Overlay controls
                overlayControls
                
                // Navigation hotspots
                navigationOverlay
                
            } else if tour.hotspots.isEmpty {
                emptyStateView
            } else {
                selectHotspotView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .principal) {
                Text(currentHotspot?.name ?? tour.name)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if currentHotspot == nil {
                currentHotspot = tour.hotspots.first { $0.photo360Path != nil }
            }
        }
        .sheet(isPresented: $showingAnnotationDetail) {
            if let annotation = selectedAnnotation {
                AnnotationDetailSheet(
                    annotation: annotation,
                    onDelete: {
                        deleteAnnotation(annotation)
                    }
                )
            }
        }
        .sheet(isPresented: $showingAddAnnotation) {
            AddAnnotationSheet(
                position: tapPosition ?? SphericalPosition(yaw: yaw, pitch: pitch),
                onSave: { annotation in
                    addAnnotation(annotation)
                }
            )
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Photos Yet")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Add hotspots and import 360° photos\nto preview your tour")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Select Hotspot View
    private var selectHotspotView: some View {
        VStack(spacing: 20) {
            Text("Select a Hotspot")
                .font(.title2)
                .foregroundColor(.white)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(tour.hotspots.filter { $0.photo360Path != nil }) { hotspot in
                        Button(action: { currentHotspot = hotspot }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.sasOrange)
                                Text(hotspot.name)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.sasCardBg)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            
            if tour.hotspots.filter({ $0.photo360Path != nil }).isEmpty {
                Text("No hotspots have 360° photos yet")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Overlay Controls
    private var overlayControls: some View {
        VStack {
            Spacer()
            
            HStack {
                // Minimap
                Button(action: {}) {
                    Image(systemName: "map")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Add annotation
                Button(action: {
                    tapPosition = SphericalPosition(yaw: yaw, pitch: pitch)
                    showingAddAnnotation = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.sasOrange)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Navigation Overlay
    private var navigationOverlay: some View {
        VStack {
            Spacer()
            
            if let current = currentHotspot {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(current.linkedHotspotIds, id: \.self) { linkedId in
                            if let linked = tour.hotspots.first(where: { $0.id == linkedId }) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        currentHotspot = linked
                                        yaw = 0
                                        pitch = 0
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.sasOrange)
                                        Text(linked.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Annotation Actions
    private func addAnnotation(_ annotation: Annotation) {
        guard var hotspot = currentHotspot,
              let index = tour.hotspots.firstIndex(where: { $0.id == hotspot.id }) else {
            return
        }
        
        hotspot.annotations.append(annotation)
        tour.hotspots[index] = hotspot
        currentHotspot = hotspot
        saveTour()
    }
    
    private func deleteAnnotation(_ annotation: Annotation) {
        guard var hotspot = currentHotspot,
              let index = tour.hotspots.firstIndex(where: { $0.id == hotspot.id }) else {
            return
        }
        
        hotspot.annotations.removeAll { $0.id == annotation.id }
        tour.hotspots[index] = hotspot
        currentHotspot = hotspot
        saveTour()
    }
    
    private func saveTour() {
        if tour.isAssigned, let customer = customer, let facility = facility, let project = project {
            dataManager.updateTour(tour, in: project, in: facility, in: customer)
        } else {
            dataManager.updateUnassignedTour(tour)
        }
    }
}

// MARK: - Add Annotation Sheet
struct AddAnnotationSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    let position: SphericalPosition
    var onSave: (Annotation) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var category: Annotation.AnnotationCategory = .general
    @State private var tagsText = ""
    @State private var annotationType: Annotation.AnnotationType = .note
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            TextField("e.g., Main Panel, Pump #3", text: $title)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.sasCardBg)
                                .cornerRadius(10)
                                .foregroundColor(.sasTextPrimary)
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            Picker("Category", selection: $category) {
                                ForEach(Annotation.AnnotationCategory.allCases, id: \.self) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.sasCardBg)
                            .cornerRadius(10)
                            .tint(.sasOrange)
                        }
                        
                        // Tags
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags (comma separated)")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            TextField("e.g., motor, VFD, line 4", text: $tagsText)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.sasCardBg)
                                .cornerRadius(10)
                                .foregroundColor(.sasTextPrimary)
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            TextField("Detailed notes about this location...", text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.sasCardBg)
                                .cornerRadius(10)
                                .foregroundColor(.sasTextPrimary)
                                .lineLimit(4...8)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Add Annotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAnnotation()
                    }
                    .foregroundColor(.sasOrange)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveAnnotation() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let annotation = Annotation(
            type: annotationType,
            position: position,
            content: description,
            title: title,
            description: description,
            category: category,
            tags: tags,
            author: dataManager.settings.authorName
        )
        
        onSave(annotation)
        dismiss()
    }
}

// MARK: - Annotation Detail Sheet
struct AnnotationDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let annotation: Annotation
    var onDelete: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        if !annotation.title.isEmpty {
                            Text(annotation.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.sasTextPrimary)
                        }
                        
                        // Category badge
                        HStack {
                            Text(annotation.category.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.sasBlue.opacity(0.2))
                                .foregroundColor(.sasBlue)
                                .cornerRadius(12)
                            
                            Spacer()
                        }
                        
                        // Tags
                        if !annotation.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(annotation.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.sasOrange.opacity(0.2))
                                            .foregroundColor(.sasOrange)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Description
                        if !annotation.description.isEmpty {
                            Text(annotation.description)
                                .font(.body)
                                .foregroundColor(.sasTextPrimary)
                        } else if !annotation.content.isEmpty {
                            Text(annotation.content)
                                .font(.body)
                                .foregroundColor(.sasTextPrimary)
                        }
                        
                        Divider()
                        
                        // Metadata
                        VStack(alignment: .leading, spacing: 8) {
                            if !annotation.author.isEmpty {
                                HStack {
                                    Image(systemName: "person")
                                        .foregroundColor(.sasTextSecondary)
                                    Text(annotation.author)
                                        .foregroundColor(.sasTextSecondary)
                                }
                                .font(.caption)
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.sasTextSecondary)
                                Text(annotation.createdAt.formatted())
                                    .foregroundColor(.sasTextSecondary)
                            }
                            .font(.caption)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Delete button
                        Button(action: {
                            onDelete()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Annotation")
                            }
                            .foregroundColor(.sasError)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.sasError.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Annotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
        }
    }
}

// MARK: - SceneKit 360 View
struct SceneView360: UIViewRepresentable {
    let image: UIImage
    @Binding var yaw: Double
    @Binding var pitch: Double
    let annotations: [Annotation]
    var onAnnotationTap: (Annotation) -> Void
    var onDoubleTap: (SphericalPosition) -> Void
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = createScene()
        scnView.allowsCameraControl = false
        scnView.backgroundColor = .black
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scnView.addGestureRecognizer(doubleTap)
        
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        scnView.addGestureRecognizer(singleTap)
        
        context.coordinator.scnView = scnView
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        if let cameraNode = scnView.scene?.rootNode.childNode(withName: "camera", recursively: false) {
            cameraNode.eulerAngles = SCNVector3(
                Float(pitch * .pi / 180),
                Float(-yaw * .pi / 180),
                0
            )
        }
        context.coordinator.updateAnnotations(annotations, in: scnView.scene)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createScene() -> SCNScene {
        let scene = SCNScene()
        
        let sphere = SCNSphere(radius: 10)
        sphere.segmentCount = 96
        
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.isDoubleSided = true
        material.cullMode = .front
        sphere.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.name = "sphere"
        sphereNode.scale = SCNVector3(-1, 1, 1)
        scene.rootNode.addChildNode(sphereNode)
        
        let camera = SCNCamera()
        camera.fieldOfView = 75
        camera.zNear = 0.1
        camera.zFar = 100
        
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 100
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        return scene
    }
    
    class Coordinator: NSObject {
        var parent: SceneView360
        weak var scnView: SCNView?
        private var annotationNodes: [UUID: SCNNode] = [:]
        
        init(_ parent: SceneView360) {
            self.parent = parent
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            
            parent.yaw -= Double(translation.x) * 0.2
            parent.pitch += Double(translation.y) * 0.2
            parent.pitch = max(-85, min(85, parent.pitch))
            
            if parent.yaw > 360 { parent.yaw -= 360 }
            if parent.yaw < 0 { parent.yaw += 360 }
            
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            let position = SphericalPosition(yaw: parent.yaw, pitch: parent.pitch)
            parent.onDoubleTap(position)
        }
        
        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = scnView else { return }
            let location = gesture.location(in: scnView)
            
            let hitResults = scnView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            
            for result in hitResults {
                if let annotationId = result.node.name,
                   let uuid = UUID(uuidString: annotationId),
                   let annotation = parent.annotations.first(where: { $0.id == uuid }) {
                    parent.onAnnotationTap(annotation)
                    return
                }
            }
        }
        
        func updateAnnotations(_ annotations: [Annotation], in scene: SCNScene?) {
            guard let scene = scene else { return }
            
            for (id, node) in annotationNodes {
                if !annotations.contains(where: { $0.id == id }) {
                    node.removeFromParentNode()
                    annotationNodes.removeValue(forKey: id)
                }
            }
            
            for annotation in annotations {
                if annotationNodes[annotation.id] == nil {
                    let node = createAnnotationNode(for: annotation)
                    scene.rootNode.addChildNode(node)
                    annotationNodes[annotation.id] = node
                }
            }
        }
        
        private func createAnnotationNode(for annotation: Annotation) -> SCNNode {
            let radius: Float = 8.0
            let yawRad = Float(annotation.position.yaw * .pi / 180)
            let pitchRad = Float(annotation.position.pitch * .pi / 180)
            
            let x = radius * cos(pitchRad) * sin(yawRad)
            let y = radius * sin(pitchRad)
            let z = -radius * cos(pitchRad) * cos(yawRad)
            
            let sphere = SCNSphere(radius: 0.3)
            let material = SCNMaterial()
            material.diffuse.contents = annotation.type == .note ? UIColor.systemBlue : UIColor.systemGreen
            material.emission.contents = annotation.type == .note ? UIColor.systemBlue : UIColor.systemGreen
            material.emission.intensity = 0.5
            sphere.materials = [material]
            
            let node = SCNNode(geometry: sphere)
            node.name = annotation.id.uuidString
            node.position = SCNVector3(x, y, z)
            
            let constraint = SCNBillboardConstraint()
            node.constraints = [constraint]
            
            return node
        }
    }
}
