//
//  TourListView.swift
//  SAS360Capture
//
//  Tour list for a project with add, edit, and delete functionality
//

import SwiftUI

struct TourListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State var customer: Customer
    @State var facility: Facility
    @State var project: Project
    @State private var showingAddTour = false
    @State private var editMode: EditMode = .inactive
    
    // Get updated project from dataManager
    var currentProject: Project {
        if let cust = dataManager.customers.first(where: { $0.id == customer.id }),
           let fac = cust.facilities.first(where: { $0.id == facility.id }),
           let proj = fac.projects.first(where: { $0.id == project.id }) {
            return proj
        }
        return project
    }
    
    var currentFacility: Facility {
        if let cust = dataManager.customers.first(where: { $0.id == customer.id }),
           let fac = cust.facilities.first(where: { $0.id == facility.id }) {
            return fac
        }
        return facility
    }
    
    var currentCustomer: Customer {
        dataManager.customers.first { $0.id == customer.id } ?? customer
    }
    
    var body: some View {
        ZStack {
            Color.sasDarkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if currentProject.tours.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(currentProject.tours) { tour in
                            NavigationLink(destination: FloorPlanEditorView(
                                customer: currentCustomer,
                                facility: currentFacility,
                                project: currentProject,
                                tour: tour
                            )) {
                                TourRow(tour: tour)
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
        .navigationTitle(currentProject.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !currentProject.tours.isEmpty {
                        Button(editMode == .active ? "Done" : "Edit") {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }
                        .foregroundColor(.sasOrange)
                    }
                    
                    Button(action: { showingAddTour = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.sasOrange)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTour) {
            AddTourSheet { tour in
                dataManager.addTour(tour, to: currentProject, in: currentFacility, in: currentCustomer)
                // Update local state
                if let cust = dataManager.customers.first(where: { $0.id == customer.id }),
                   let fac = cust.facilities.first(where: { $0.id == facility.id }),
                   let proj = fac.projects.first(where: { $0.id == project.id }) {
                    customer = cust
                    facility = fac
                    project = proj
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.sasOrange.opacity(0.5))
            
            Text("No Tours Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.sasTextPrimary)
            
            Text("Create a tour to start capturing\n360° photos of this area")
                .font(.subheadline)
                .foregroundColor(.sasTextSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddTour = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Tour")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.sasOrange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func deleteTours(at offsets: IndexSet) {
        for index in offsets {
            let tour = currentProject.tours[index]
            dataManager.deleteTour(tour, from: currentProject, in: currentFacility, in: currentCustomer)
        }
        // Update local state
        if let cust = dataManager.customers.first(where: { $0.id == customer.id }),
           let fac = cust.facilities.first(where: { $0.id == facility.id }),
           let proj = fac.projects.first(where: { $0.id == project.id }) {
            customer = cust
            facility = fac
            project = proj
        }
    }
}

// MARK: - Tour Row
struct TourRow: View {
    let tour: Tour
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let path = tour.floorPlanImagePath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.sasOrange.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "map")
                            .foregroundColor(.sasOrange)
                    )
            }
            
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

// MARK: - Add Tour Sheet
struct AddTourSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    var onCreate: (Tour) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tour Name")
                            .font(.subheadline)
                            .foregroundColor(.sasTextSecondary)
                        
                        TextField("e.g., First Floor, Assembly Area", text: $name)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.sasCardBg)
                            .cornerRadius(10)
                            .foregroundColor(.sasTextPrimary)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Create button
                    Button(action: createTour) {
                        Text("Create Tour")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.isEmpty ? Color.gray : Color.sasOrange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(name.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
            }
            .navigationTitle("New Tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
        }
    }
    
    private func createTour() {
        let tour = Tour(name: name)
        onCreate(tour)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        TourListView(
            customer: Customer(name: "Test Customer"),
            facility: Facility(name: "Test Facility"),
            project: Project(name: "Test Project")
        )
        .environmentObject(DataManager())
    }
}
