//
//  MainTabView.swift
//  SAS360Capture
//
//  Main navigation with tabs for Projects, Quick Scan, Camera, and Settings
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Projects Tab
            NavigationStack {
                CustomerListView()
            }
            .tabItem {
                Label("Projects", systemImage: "folder.fill")
            }
            .tag(0)
            
            // Quick Scan Tab
            NavigationStack {
                QuickScanView()
            }
            .tabItem {
                Label("Quick Scan", systemImage: "viewfinder")
            }
            .tag(1)
            
            // Camera Tab
            NavigationStack {
                CameraConnectionView()
            }
            .tabItem {
                Label("Camera", systemImage: "camera.fill")
            }
            .tag(2)
            
            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .accentColor(.sasOrange)
    }
}

// MARK: - Quick Scan View
struct QuickScanView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNewScan = false
    @State private var showingPanoramaCapture = false
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        ZStack {
            Color.sasDarkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                if dataManager.unassignedTours.isEmpty {
                    emptyStateView
                } else {
                    // Unassigned tours list
                    List {
                        ForEach(dataManager.unassignedTours) { tour in
                            NavigationLink(destination: FloorPlanEditorView(
                                customer: nil,
                                facility: nil,
                                project: nil,
                                tour: tour
                            )) {
                                UnassignedTourRow(tour: tour)
                            }
                            .listRowBackground(Color.sasCardBg)
                        }
                        .onDelete(perform: deleteTours)
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, $editMode)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewScan) {
            NewQuickScanSheet { tour in
                dataManager.addUnassignedTour(tour)
            }
        }
        .fullScreenCover(isPresented: $showingPanoramaCapture) {
            PanoramaCaptureView { image in
                // Create a new tour with the captured panorama
                var tour = Tour(name: defaultTourName(), isAssigned: false)
                let hotspot = Hotspot(name: "Capture 1", position: CodablePoint(x: 200, y: 200))
                tour.hotspots.append(hotspot)
                dataManager.addUnassignedTour(tour)
                
                // Save the image
                if let hotspotIndex = tour.hotspots.firstIndex(where: { $0.id == hotspot.id }),
                   let path = dataManager.save360Image(image, for: tour.id, hotspotId: hotspot.id) {
                    var updatedTour = tour
                    updatedTour.hotspots[hotspotIndex].photo360Path = path
                    dataManager.updateUnassignedTour(updatedTour)
                }
            }
        }
    }
    
    private func defaultTourName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: Date())
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    SASLogo(size: 36)
                    Text("Quick Scan")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.sasTextPrimary)
                }
                Text("Capture first, organize later")
                    .font(.caption)
                    .foregroundColor(.sasTextSecondary)
            }
            
            Spacer()
            
            if !dataManager.unassignedTours.isEmpty {
                Button(editMode == .active ? "Done" : "Edit") {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }
                .foregroundColor(.sasOrange)
            }
            
            Menu {
                Button(action: { showingNewScan = true }) {
                    Label("New Tour", systemImage: "map")
                }
                Button(action: { showingPanoramaCapture = true }) {
                    Label("iPhone Panorama", systemImage: "pano")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.sasOrange)
            }
        }
        .padding()
        .background(Color.sasCardBg)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.sasOrange.opacity(0.5))
            
            Text("No Quick Scans")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.sasTextPrimary)
            
            Text("Start capturing 360° tours without\nsetting up a full project structure")
                .font(.subheadline)
                .foregroundColor(.sasTextSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button(action: { showingNewScan = true }) {
                    HStack {
                        Image(systemName: "map")
                        Text("New Tour")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.sasOrange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: { showingPanoramaCapture = true }) {
                    HStack {
                        Image(systemName: "pano")
                        Text("iPhone Scan")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.sasBlue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func deleteTours(at offsets: IndexSet) {
        for index in offsets {
            let tour = dataManager.unassignedTours[index]
            dataManager.deleteUnassignedTour(tour)
        }
    }
}

// MARK: - Unassigned Tour Row
struct UnassignedTourRow: View {
    let tour: Tour
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.sasBlue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.sasBlue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tour.name)
                    .font(.headline)
                    .foregroundColor(.sasTextPrimary)
                
                Text("\(tour.hotspots.count) hotspots • \(tour.lastModifiedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.sasTextSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.sasTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New Quick Scan Sheet
struct NewQuickScanSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var tourName = ""
    var onCreate: (Tour) -> Void
    
    private var defaultName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scan Name")
                            .font(.subheadline)
                            .foregroundColor(.sasTextSecondary)
                        
                        TextField(defaultName, text: $tourName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.sasCardBg)
                            .cornerRadius(10)
                            .foregroundColor(.sasTextPrimary)
                    }
                    .padding(.horizontal)
                    
                    Text("Leave blank to use current date/time")
                        .font(.caption)
                        .foregroundColor(.sasTextSecondary)
                    
                    Spacer()
                    
                    // Create button
                    Button(action: createScan) {
                        Text("Start Scanning")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.sasOrange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
            }
            .navigationTitle("New Quick Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
        }
    }
    
    private func createScan() {
        let name = tourName.isEmpty ? defaultName : tourName
        let tour = Tour(name: name, isAssigned: false)
        onCreate(tour)
        dismiss()
    }
}

#Preview {
    MainTabView()
        .environmentObject(DataManager())
}
