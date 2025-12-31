//
//  SettingsView.swift
//  SAS360Capture
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var settings: AppSettings = AppSettings()
    @State private var showingAbout = false
    @State private var showingClearDataAlert = false
    
    var body: some View {
        ZStack {
            Color.sasDarkBg.ignoresSafeArea()
            
            List {
                // User section
                Section {
                    HStack {
                        Text("Author Name")
                            .foregroundColor(.sasTextPrimary)
                        Spacer()
                        TextField("Your name", text: $settings.authorName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.sasTextSecondary)
                    }
                } header: {
                    Text("User")
                        .foregroundColor(.sasOrange)
                }
                .listRowBackground(Color.sasCardBg)
                
                // Capture section
                Section {
                    Toggle("High Resolution Capture", isOn: $settings.highResolutionCapture)
                        .tint(.sasOrange)
                    
                    Toggle("Haptic Feedback", isOn: $settings.hapticFeedbackEnabled)
                        .tint(.sasOrange)
                    
                    Toggle("Auto-Save Tours", isOn: $settings.autoSaveEnabled)
                        .tint(.sasOrange)
                } header: {
                    Text("Capture")
                        .foregroundColor(.sasOrange)
                }
                .listRowBackground(Color.sasCardBg)
                
                // Viewer section
                Section {
                    Toggle("Show Hotspot Labels", isOn: $settings.showHotspotLabels)
                        .tint(.sasOrange)
                    
                    Picker("Transition Style", selection: $settings.defaultTransitionStyle) {
                        ForEach(AppSettings.TransitionStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                } header: {
                    Text("Viewer")
                        .foregroundColor(.sasOrange)
                }
                .listRowBackground(Color.sasCardBg)
                
                // Data section
                Section {
                    Button(action: { showingClearDataAlert = true }) {
                        HStack {
                            Text("Clear All Data")
                            Spacer()
                            Image(systemName: "trash")
                        }
                        .foregroundColor(.sasError)
                    }
                } header: {
                    Text("Data")
                        .foregroundColor(.sasOrange)
                } footer: {
                    Text("This will delete all customers, facilities, projects, tours, and images.")
                        .foregroundColor(.sasTextSecondary)
                }
                .listRowBackground(Color.sasCardBg)
                
                // About section
                Section {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Text("About")
                                .foregroundColor(.sasTextPrimary)
                            Spacer()
                            Image(systemName: "info.circle")
                                .foregroundColor(.sasTextSecondary)
                        }
                    }
                    
                    HStack {
                        Text("Version")
                            .foregroundColor(.sasTextPrimary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.sasTextSecondary)
                    }
                } header: {
                    Text("About")
                        .foregroundColor(.sasOrange)
                }
                .listRowBackground(Color.sasCardBg)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .onAppear {
            settings = dataManager.settings
        }
        .onChange(of: settings) { _, newValue in
            dataManager.updateSettings(newValue)
        }
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This action cannot be undone. All customers, facilities, projects, tours, and images will be permanently deleted.")
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    private func clearAllData() {
        // Delete all customers (which cascades to everything)
        for customer in dataManager.customers {
            dataManager.deleteCustomer(customer)
        }
        
        // Delete unassigned tours
        for tour in dataManager.unassignedTours {
            dataManager.deleteUnassignedTour(tour)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Logo
                    SASLogo(size: 100)
                        .padding(.top, 40)
                    
                    Text("SAS 360 Capture")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.sasTextPrimary)
                    
                    Text("Virtual Facility Tour Capture")
                        .font(.subheadline)
                        .foregroundColor(.sasTextSecondary)
                    
                    Divider()
                        .padding(.horizontal, 40)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "camera.fill", title: "360° Capture", description: "Capture immersive 360° photos with Insta360 cameras")
                        
                        FeatureRow(icon: "map.fill", title: "Floor Plans", description: "Draw floor plans and place navigation hotspots")
                        
                        FeatureRow(icon: "eye.fill", title: "Virtual Tours", description: "Walk through facilities remotely with linked hotspots")
                        
                        FeatureRow(icon: "note.text", title: "Annotations", description: "Add notes and detail photos within 360° views")
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Company info
                    VStack(spacing: 8) {
                        Text("Southern Automation Solutions")
                            .font(.headline)
                            .foregroundColor(.sasOrange)
                        
                        Text("Industrial Automation & Controls")
                            .font(.caption)
                            .foregroundColor(.sasTextSecondary)
                    }
                    .padding(.bottom, 40)
                }
            }
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.sasBlue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.sasTextPrimary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.sasTextSecondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(DataManager())
    }
}
