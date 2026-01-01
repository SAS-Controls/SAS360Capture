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
    @State private var showingPanoramaCapture = false
    
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
                toolbarView
                
                GeometryReader { geometry in
                    ZStack {
                        Color.sasCardBg
                        
                        canvasContent
                            .scaleEffect(canvasScale)
                            .offset(canvasOffset)
                        
                        shapesLayer
                            .scaleEffect(canvasScale)
                            .offset(canvasOffset)
                        
                        labelsLayer
                            .scaleEffect(canvasScale)
                            .offset(canvasOffset)
                        
                        hotspotsLayer
                            .scaleEffect(canvasScale)
                            .offset(canvasOffset)
                        
                        if let start = currentDrawStart, let end = currentDrawEnd {
                            drawingPreview(from: start, to: end)
                                .scaleEffect(canvasScale)
                                .offset(canvasOffset)
                        }
                    }
                    .clipped()
                    .gesture(canvasGesture(in: geometry))
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                canvasScale = max(0.5, min(3.0, scale))
                            }
                    )
                }
            }
        }
        .navigationTitle(tour.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingViewer = true }) {
                        Label("Preview Tour", systemImage: "eye")
                    }
                    Button(action: { showingImagePicker = true }) {
                        Label("Import Floor Plan", systemImage: "photo")
                    }
                    Button(action: { showingCameraConnection = true }) {
                        Label("Connect Camera", systemImage: "camera")
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
                        showingHotspotEditor = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingPhotoImporter = true
                        }
                    },
                    onQuickScan: {
                        showingHotspotEditor = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingPanoramaCapture = true
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showingPanoramaCapture) {
            PanoramaCaptureView { capturedImage in
                if let hotspot = selectedHotspot,
                   let index = hotspots.firstIndex(where: { $0.id == hotspot.id }) {
                    if let path = savePanoramaImage(capturedImage, for: hotspot) {
                        hotspots[index].photo360Path = path
                        saveTour()
                    }
                }
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
    
    private func savePanoramaImage(_ image: UIImage, for hotspot: Hotspot) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileName = "\(tour.id)_\(hotspot.id)_pano.jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: filePath)
            return filePath.path
        } catch {
            print("Error saving panorama: \(error)")
            return nil
        }
    }
    
    private var toolbarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DrawingTool.allCases, id: \.self) { tool in
                    toolButton(tool)
                }
                
                Divider()
                    .frame(height: 30)
                    .padding(.horizontal, 8)
                
                Button(action: { canvasScale = max(0.5, canvasScale - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(.sasTextPrimary)
                        .padding(8)
                        .background(Color.sasCardBg)
                        .cornerRadius(8)
                }
                
                Button(action: { canvasScale = min(3.0, canvasScale + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(.sasTextPrimary)
                        .padding(8)
                        .background(Color.sasCardBg)
                        .cornerRadius(8)
                }
                
                Button(action: { canvasScale = 1.0; canvasOffset = .zero }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.sasTextPrimary)
                        .padding(8)
                        .background(Color.sasCardBg)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.sasDarkBg)
    }
    
    private func toolButton(_ tool: DrawingTool) -> some View {
        Button(action: { selectedTool = tool }) {
            HStack(spacing: 4) {
                Image(systemName: iconForTool(tool))
                Text(tool.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedTool == tool ? Color.sasOrange : Color.sasCardBg)
            .foregroundColor(selectedTool == tool ? .white : .sasTextPrimary)
            .cornerRadius(8)
        }
    }
    
    private func iconForTool(_ tool: DrawingTool) -> String {
        switch tool {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .rectangle: return "rectangle"
        case .line: return "line.diagonal"
        case .label: return "textformat"
        case .hotspot: return "mappin.circle"
        }
    }
    
    private var canvasContent: some View {
        ZStack {
            GridPattern()
                .stroke(Color.sasBorder.opacity(0.3), lineWidth: 0.5)
                .frame(width: 2000, height: 2000)
            
            if let image = floorPlanImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 800, maxHeight: 800)
            }
        }
    }
    
    private var shapesLayer: some View {
        ZStack {
            ForEach(shapes) { shape in
                ShapeView(shape: shape)
            }
        }
    }
    
    private var labelsLayer: some View {
        ZStack {
            ForEach(labels) { label in
                Text(label.text)
                    .font(.caption)
                    .padding(4)
                    .background(Color.sasCardBg.opacity(0.8))
                    .cornerRadius(4)
                    .foregroundColor(.sasTextPrimary)
                    .position(label.position.cgPoint)
            }
        }
    }
    
    private var hotspotsLayer: some View {
        ZStack {
            ForEach(hotspots) { hotspot in
                HotspotMarker(
                    hotspot: hotspot,
                    isSelected: selectedHotspot?.id == hotspot.id,
                    onTap: {
                        selectedHotspot = hotspot
                        showingHotspotEditor = true
                    }
                )
                .position(hotspot.position.cgPoint)
                .offset(draggedHotspot?.id == hotspot.id ? dragOffset : .zero)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if selectedTool == .select {
                                draggedHotspot = hotspot
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            if let dragged = draggedHotspot,
                               let index = hotspots.firstIndex(where: { $0.id == dragged.id }) {
                                let newPos = CGPoint(
                                    x: dragged.position.x + Double(value.translation.width / canvasScale),
                                    y: dragged.position.y + Double(value.translation.height / canvasScale)
                                )
                                hotspots[index].position = CodablePoint(newPos)
                                saveTour()
                            }
                            draggedHotspot = nil
                            dragOffset = .zero
                        }
                )
            }
        }
    }
    
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
    
    private func canvasGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let location = CGPoint(
                    x: (value.location.x - canvasOffset.width) / canvasScale,
                    y: (value.location.y - canvasOffset.height) / canvasScale
                )
                
                switch selectedTool {
                case .select:
                    canvasOffset = CGSize(
                        width: canvasOffset.width + value.translation.width * 0.1,
                        height: canvasOffset.height + value.translation.height * 0.1
                    )
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
                let location = CGPoint(
                    x: (value.location.x - canvasOffset.width) / canvasScale,
                    y: (value.location.y - canvasOffset.height) / canvasScale
                )
                
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
                    showingHotspotEditor = true
                    saveTour()
                }
                
                currentDrawStart = nil
                currentDrawEnd = nil
            }
    }
    
    private func loadTourData() {
        // Load from floorPlanDrawing if it exists
        if let drawing = tour.floorPlanDrawing {
            shapes = drawing.shapes
            labels = drawing.labels
        }
        hotspots = tour.hotspots
        
        if let imagePath = tour.floorPlanImagePath {
            floorPlanImage = UIImage(contentsOfFile: imagePath)
        }
    }
    
    private func saveTour() {
        // Save shapes and labels to floorPlanDrawing
        var drawing = tour.floorPlanDrawing ?? FloorPlanDrawing()
        drawing.shapes = shapes
        drawing.labels = labels
        tour.floorPlanDrawing = drawing
        tour.hotspots = hotspots
        
        // Use correct updateTour signature based on assignment
        if tour.isAssigned, let customer = customer, let facility = facility, let project = project {
            dataManager.updateTour(tour, in: project, in: facility, in: customer)
        } else {
            dataManager.updateUnassignedTour(tour)
        }
    }
    
    private func loadFloorPlanImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        self.floorPlanImage = image
                        self.saveFloorPlanImage(image)
                    }
                case .failure(let error):
                    print("Error loading image: \(error)")
                }
            }
        }
    }
    
    private func saveFloorPlanImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileName = "\(tour.id)_floorplan.jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: filePath)
            tour.floorPlanImagePath = filePath.path
            saveTour()
        } catch {
            print("Error saving floor plan: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let gridSize: CGFloat = 50
        
        for x in stride(from: 0, through: rect.width, by: gridSize) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        for y in stride(from: 0, through: rect.height, by: gridSize) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

struct ShapeView: View {
    let shape: DrawingShape
    
    var body: some View {
        switch shape.type {
        case .rectangle:
            Rectangle()
                .stroke(Color.sasBlue, lineWidth: 2)
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
            .stroke(Color.sasBlue, lineWidth: 2)
        case .polygon, .arc:
            // Placeholder for future shape types
            EmptyView()
        }
    }
}

struct HotspotMarker: View {
    let hotspot: Hotspot
    let isSelected: Bool
    var onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(hotspot.photo360Path != nil ? Color.sasSuccess : Color.sasOrange)
                    .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                
                Image(systemName: hotspot.photo360Path != nil ? "checkmark" : "camera")
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundColor(.white)
            }
            
            Text(hotspot.name)
                .font(.caption2)
                .foregroundColor(.sasTextPrimary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.sasCardBg.opacity(0.9))
                .cornerRadius(4)
        }
        .onTapGesture(perform: onTap)
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
    var onQuickScan: () -> Void
    
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
                        
                        // 360 Photo Section
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
                                
                                HStack(spacing: 12) {
                                    Button(action: onQuickScan) {
                                        HStack {
                                            Image(systemName: "camera.viewfinder")
                                            Text("Quick Scan")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.sasOrange)
                                    }
                                    
                                    Divider().frame(height: 20)
                                    
                                    Button(action: onImportPhoto) {
                                        HStack {
                                            Image(systemName: "photo")
                                            Text("Import")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.sasBlue)
                                    }
                                }
                            } else {
                                VStack(spacing: 12) {
                                    Button(action: onQuickScan) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.viewfinder")
                                                .font(.system(size: 36))
                                                .foregroundColor(.sasOrange)
                                            Text("Quick Scan")
                                                .font(.headline)
                                                .foregroundColor(.sasTextPrimary)
                                            Text("Capture 360° panorama with your phone")
                                                .font(.caption)
                                                .foregroundColor(.sasTextSecondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(Color.sasCardBg)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.sasOrange, lineWidth: 2)
                                        )
                                    }
                                    
                                    Button(action: onImportPhoto) {
                                        HStack {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 20))
                                            Text("Import from Library")
                                                .font(.subheadline)
                                        }
                                        .foregroundColor(.sasBlue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.sasCardBg)
                                        .cornerRadius(10)
                                    }
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
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
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
