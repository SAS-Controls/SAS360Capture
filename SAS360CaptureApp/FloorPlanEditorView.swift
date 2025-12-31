//
//  FloorPlanEditorView.swift
//  SAS360Capture
//
//  Floor plan drawing and hotspot placement editor
//

import SwiftUI
import PhotosUI

struct FloorPlanEditorView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    let customer: Customer?
    let facility: Facility?
    let project: Project?
    @State var tour: Tour
    
    // Editor state
    @State private var selectedTool: DrawingTool = .select
    @State private var shapes: [DrawingShape] = []
    @State private var labels: [DrawingLabel] = []
    @State private var hotspots: [Hotspot] = []
    @State private var selectedHotspot: Hotspot?
    @State private var draggedHotspot: Hotspot?
    @State private var dragOffset: CGSize = .zero
    
    // Drawing state
    @State private var currentDrawStart: CGPoint?
    @State private var currentDrawEnd: CGPoint?
    
    // Canvas state
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero
    
    // Sheets
    @State private var showingPhotoImporter = false
    @State private var showingCameraConnection = false
    @State private var showingHotspotEditor = false
    @State private var showingViewer = false
    @State private var showingLabelInput = false
    @State private var newLabelText = ""
    @State private var newLabelPosition: CGPoint = .zero
    
    // Floor plan image
    @State private var floorPlanImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    enum DrawingTool: String, CaseIterable {
        case select = "Select"
        case rectangle = "Rectangle"
        case line = "Line"
        case label = "Label"
        case hotspot = "Hotspot"
    }
    
    var body: some View {
        ZStack {
            Color.sasDarkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toolbar
                toolbarView
                
                // Canvas
                GeometryReader { geometry in
                    ZStack {
                        Color.sasCardBg
                        
                        // Floor plan image or grid
                        canvasContent
                            .scaleEffect(canvasScale)
                            .offset(canvasOffset)
                        
                        // Drawing shapes
                        shapesLayer
                            .scaleEffect(canvasScale)
                            .offset(canvasOffset)
                        
                        // Labels
                        labelsLayer
                            .scaleEffect(canvasScale)
                            .offset(canvasOffset)
                        
                        // Hotspots
                        hotspotsLayer
                            .scaleEffect(canvasScale)
                            .offset(canvasOffset)
                        
                        // Current drawing preview
                        if let start = currentDrawStart, let end = currentDrawEnd {
                            drawingPreview(from: start, to: end)
                                .scaleEffect(canvasScale)
                                .offset(canvasOffset)
                        }
                    }
                    .clipped()
                    .gesture(canvasGesture(in: geometry))
                    .gesture(MagnificationGesture()
                        .onChanged { value in
                            canvasScale = min(max(value, 0.5), 3.0)
                        }
                    )
                }
                
                // Bottom bar
                bottomBar
            }
        }
        .navigationTitle(tour.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingImagePicker = true }) {
                        Label("Import Floor Plan", systemImage: "photo")
                    }
                    Button(action: { showingViewer = true }) {
                        Label("Preview Tour", systemImage: "eye")
                    }
                    Button(action: saveTour) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.sasOrange)
                }
            }
        }
        .onAppear {
            loadTourData()
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            loadFloorPlanImage(from: newValue)
        }
        .sheet(isPresented: $showingPhotoImporter) {
            PhotoImporterView(tourId: tour.id) { image, path in
                if let hotspot = selectedHotspot,
                   let index = hotspots.firstIndex(where: { $0.id == hotspot.id }) {
                    hotspots[index].photo360Path = path
                    saveTour()
                }
            }
        }
        .sheet(isPresented: $showingCameraConnection) {
            CameraConnectionView()
        }
        .sheet(isPresented: $showingHotspotEditor) {
            if let hotspot = selectedHotspot {
                HotspotEditorSheet(
                    hotspot: hotspot,
                    allHotspots: hotspots,
                    onSave: { updated in
                        if let index = hotspots.firstIndex(where: { $0.id == updated.id }) {
                            hotspots[index] = updated
                            saveTour()
                        }
                    },
                    onDelete: {
                        hotspots.removeAll { $0.id == hotspot.id }
                        selectedHotspot = nil
                        saveTour()
                    },
                    onImportPhoto: {
                        showingPhotoImporter = true
                    }
                )
            }
        }
        .sheet(isPresented: $showingViewer) {
            NavigationStack {
                Viewer360View(
                    tour: $tour,
                    customer: customer,
                    facility: facility,
                    project: project
                )
            }
        }
        .alert("Add Label", isPresented: $showingLabelInput) {
            TextField("Label text", text: $newLabelText)
            Button("Cancel", role: .cancel) { newLabelText = "" }
            Button("Add") {
                if !newLabelText.isEmpty {
                    let label = DrawingLabel(text: newLabelText, position: CodablePoint(newLabelPosition))
                    labels.append(label)
                    newLabelText = ""
                    saveTour()
                }
            }
        }
    }
    
    // MARK: - Toolbar
    private var toolbarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DrawingTool.allCases, id: \.self) { tool in
                    toolButton(tool)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.sasBorder)
                
                Button(action: { canvasScale = min(canvasScale * 1.2, 3.0) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(.sasTextSecondary)
                }
                
                Button(action: { canvasScale = max(canvasScale / 1.2, 0.5) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(.sasTextSecondary)
                }
                
                Button(action: {
                    canvasScale = 1.0
                    canvasOffset = .zero
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.sasTextSecondary)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 50)
        .background(Color.sasCardBg)
    }
    
    private func toolButton(_ tool: DrawingTool) -> some View {
        Button(action: { selectedTool = tool }) {
            VStack(spacing: 4) {
                Image(systemName: iconForTool(tool))
                    .font(.system(size: 18))
                Text(tool.rawValue)
                    .font(.caption2)
            }
            .foregroundColor(selectedTool == tool ? .sasOrange : .sasTextSecondary)
            .frame(width: 60, height: 44)
            .background(selectedTool == tool ? Color.sasOrange.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
    }
    
    private func iconForTool(_ tool: DrawingTool) -> String {
        switch tool {
        case .select: return "hand.point.up"
        case .rectangle: return "rectangle"
        case .line: return "line.diagonal"
        case .label: return "textformat"
        case .hotspot: return "mappin.circle"
        }
    }
    
    // MARK: - Canvas Content
    private var canvasContent: some View {
        Group {
            if let image = floorPlanImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                GridPattern()
                    .stroke(Color.sasBorder.opacity(0.3), lineWidth: 0.5)
            }
        }
    }
    
    // MARK: - Shapes Layer
    private var shapesLayer: some View {
        ForEach(shapes) { shape in
            ShapeView(shape: shape)
        }
    }
    
    // MARK: - Labels Layer
    private var labelsLayer: some View {
        ForEach(labels) { label in
            Text(label.text)
                .font(.system(size: label.fontSize))
                .foregroundColor(.sasTextPrimary)
                .padding(4)
                .background(Color.sasDarkBg.opacity(0.7))
                .cornerRadius(4)
                .position(label.position.cgPoint)
        }
    }
    
    // MARK: - Hotspots Layer
    private var hotspotsLayer: some View {
        ForEach(hotspots) { hotspot in
            HotspotMarker(
                hotspot: hotspot,
                isSelected: selectedHotspot?.id == hotspot.id,
                isDragging: draggedHotspot?.id == hotspot.id
            )
            .position(
                draggedHotspot?.id == hotspot.id
                    ? CGPoint(x: hotspot.position.x + dragOffset.width,
                              y: hotspot.position.y + dragOffset.height)
                    : hotspot.position.cgPoint
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if selectedTool == .select {
                            draggedHotspot = hotspot
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if let index = hotspots.firstIndex(where: { $0.id == hotspot.id }) {
                            hotspots[index].position = CodablePoint(
                                x: hotspot.position.x + value.translation.width,
                                y: hotspot.position.y + value.translation.height
                            )
                            saveTour()
                        }
                        draggedHotspot = nil
                        dragOffset = .zero
                    }
            )
            .onTapGesture {
                selectedHotspot = hotspot
                if selectedTool == .select {
                    showingHotspotEditor = true
                }
            }
        }
    }
    
    // MARK: - Drawing Preview
    private func drawingPreview(from start: CGPoint, to end: CGPoint) -> some View {
        Group {
            switch selectedTool {
            case .rectangle:
                Rectangle()
                    .stroke(Color.sasBlue, lineWidth: 2)
                    .frame(width: abs(end.x - start.x), height: abs(end.y - start.y))
                    .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            case .line:
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(Color.sasBlue, lineWidth: 2)
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Canvas Gesture
    private func canvasGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let location = adjustedLocation(value.location, in: geometry)
                
                switch selectedTool {
                case .select:
                    if draggedHotspot == nil {
                        canvasOffset = CGSize(
                            width: canvasOffset.width + value.translation.width * 0.1,
                            height: canvasOffset.height + value.translation.height * 0.1
                        )
                    }
                case .rectangle, .line:
                    if currentDrawStart == nil {
                        currentDrawStart = location
                    }
                    currentDrawEnd = location
                case .label, .hotspot:
                    break
                }
            }
            .onEnded { value in
                let location = adjustedLocation(value.location, in: geometry)
                
                switch selectedTool {
                case .select:
                    break
                case .rectangle:
                    if let start = currentDrawStart {
                        let shape = DrawingShape(
                            type: .rectangle,
                            startPoint: CodablePoint(start),
                            endPoint: CodablePoint(location)
                        )
                        shapes.append(shape)
                        saveTour()
                    }
                case .line:
                    if let start = currentDrawStart {
                        let shape = DrawingShape(
                            type: .line,
                            startPoint: CodablePoint(start),
                            endPoint: CodablePoint(location)
                        )
                        shapes.append(shape)
                        saveTour()
                    }
                case .label:
                    newLabelPosition = location
                    showingLabelInput = true
                case .hotspot:
                    let hotspot = Hotspot(
                        name: "Hotspot \(hotspots.count + 1)",
                        position: CodablePoint(location)
                    )
                    hotspots.append(hotspot)
                    selectedHotspot = hotspot
                    saveTour()
                }
                
                currentDrawStart = nil
                currentDrawEnd = nil
            }
    }
    
    private func adjustedLocation(_ location: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        return CGPoint(
            x: (location.x - centerX - canvasOffset.width) / canvasScale + centerX,
            y: (location.y - centerY - canvasOffset.height) / canvasScale + centerY
        )
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.sasOrange)
                Text("\(hotspots.count) hotspots")
                    .font(.subheadline)
                    .foregroundColor(.sasTextSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showingCameraConnection = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                        Text("Camera")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.sasBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: { showingViewer = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                        Text("Preview")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.sasOrange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.sasCardBg)
    }
    
    // MARK: - Data Operations
    private func loadTourData() {
        hotspots = tour.hotspots
        if let drawing = tour.floorPlanDrawing {
            shapes = drawing.shapes
            labels = drawing.labels
        }
        if let path = tour.floorPlanImagePath {
            floorPlanImage = UIImage(contentsOfFile: path)
        }
    }
    
    private func saveTour() {
        tour.hotspots = hotspots
        tour.floorPlanDrawing = FloorPlanDrawing(shapes: shapes, labels: labels)
        tour.lastModifiedAt = Date()
        
        if tour.isAssigned, let customer = customer, let facility = facility, let project = project {
            dataManager.updateTour(tour, in: project, in: facility, in: customer)
        } else {
            dataManager.updateUnassignedTour(tour)
        }
    }
    
    private func loadFloorPlanImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    floorPlanImage = image
                    if let path = dataManager.saveImage(image, for: tour.id) {
                        tour.floorPlanImagePath = path
                        saveTour()
                    }
                }
            }
        }
    }
}

// MARK: - Grid Pattern
struct GridPattern: Shape {
    let spacing: CGFloat = 20
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        return path
    }
}

// MARK: - Shape View
struct ShapeView: View {
    let shape: DrawingShape
    
    var body: some View {
        switch shape.type {
        case .rectangle:
            Rectangle()
                .stroke(Color.sasBlue, lineWidth: shape.strokeWidth)
                .frame(
                    width: abs(shape.endPoint.x - shape.startPoint.x),
                    height: abs(shape.endPoint.y - shape.startPoint.y)
                )
                .position(
                    x: (shape.startPoint.x + shape.endPoint.x) / 2,
                    y: (shape.startPoint.y + shape.endPoint.y) / 2
                )
        case .line:
            Path { path in
                path.move(to: shape.startPoint.cgPoint)
                path.addLine(to: shape.endPoint.cgPoint)
            }
            .stroke(Color.sasBlue, lineWidth: shape.strokeWidth)
        case .polygon, .arc:
            EmptyView()
        }
    }
}

// MARK: - Hotspot Marker
struct HotspotMarker: View {
    let hotspot: Hotspot
    let isSelected: Bool
    let isDragging: Bool
    
    var hasPhoto: Bool { hotspot.photo360Path != nil }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.sasOrange : (hasPhoto ? Color.sasSuccess : Color.sasBlue), lineWidth: 3)
                .frame(width: 36, height: 36)
            
            Circle()
                .fill(isSelected ? Color.sasOrange.opacity(0.3) : (hasPhoto ? Color.sasSuccess.opacity(0.2) : Color.sasBlue.opacity(0.2)))
                .frame(width: 30, height: 30)
            
            Image(systemName: hasPhoto ? "camera.fill" : "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .sasOrange : (hasPhoto ? .sasSuccess : .sasBlue))
        }
        .shadow(color: .black.opacity(0.3), radius: isDragging ? 8 : 4)
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - Hotspot Editor Sheet
struct HotspotEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var hotspot: Hotspot
    let allHotspots: [Hotspot]
    var onSave: (Hotspot) -> Void
    var onDelete: () -> Void
    var onImportPhoto: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hotspot Name")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            TextField("Name", text: $hotspot.name)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.sasCardBg)
                                .cornerRadius(10)
                                .foregroundColor(.sasTextPrimary)
                        }
                        
                        // 360 Photo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("360° Photo")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            if let path = hotspot.photo360Path,
                               let image = UIImage(contentsOfFile: path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                Button(action: onImportPhoto) {
                                    Text("Replace Photo")
                                        .font(.subheadline)
                                        .foregroundColor(.sasOrange)
                                }
                            } else {
                                Button(action: onImportPhoto) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 40))
                                            .foregroundColor(.sasBlue)
                                        Text("Import 360° Photo")
                                            .font(.subheadline)
                                            .foregroundColor(.sasTextSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.sasCardBg)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        
                        // Linked Hotspots
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Linked Hotspots")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            let otherHotspots = allHotspots.filter { $0.id != hotspot.id }
                            
                            if otherHotspots.isEmpty {
                                Text("No other hotspots to link")
                                    .font(.caption)
                                    .foregroundColor(.sasTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.sasCardBg)
                                    .cornerRadius(10)
                            } else {
                                ForEach(otherHotspots) { other in
                                    HStack {
                                        Text(other.name)
                                            .foregroundColor(.sasTextPrimary)
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { hotspot.linkedHotspotIds.contains(other.id) },
                                            set: { isLinked in
                                                if isLinked {
                                                    hotspot.linkedHotspotIds.append(other.id)
                                                } else {
                                                    hotspot.linkedHotspotIds.removeAll { $0 == other.id }
                                                }
                                            }
                                        ))
                                        .tint(.sasOrange)
                                    }
                                    .padding()
                                    .background(Color.sasCardBg)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                        
                        Button(action: {
                            onDelete()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Hotspot")
                            }
                            .foregroundColor(.sasError)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.sasError.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .safeAreaPadding(.horizontal)
                }
            }
            .navigationTitle("Edit Hotspot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(hotspot)
                        dismiss()
                    }
                    .foregroundColor(.sasOrange)
                }
            }
        }
    }
}
