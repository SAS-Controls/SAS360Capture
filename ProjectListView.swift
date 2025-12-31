//
//  ProjectListView.swift
//  SAS360Capture
//
//  Project list for a facility with add, edit, and delete functionality
//

import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State var customer: Customer
    @State var facility: Facility
    @State private var showingAddProject = false
    @State private var editMode: EditMode = .inactive
    
    // Get updated facility from dataManager
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
                if currentFacility.projects.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(currentFacility.projects) { project in
                            NavigationLink(destination: TourListView(
                                customer: currentCustomer,
                                facility: currentFacility,
                                project: project
                            )) {
                                ProjectRow(project: project)
                            }
                            .listRowBackground(Color.sasCardBg)
                        }
                        .onDelete(perform: deleteProjects)
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, $editMode)
                }
            }
        }
        .navigationTitle(currentFacility.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !currentFacility.projects.isEmpty {
                        Button(editMode == .active ? "Done" : "Edit") {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }
                        .foregroundColor(.sasOrange)
                    }
                    
                    Button(action: { showingAddProject = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.sasOrange)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectSheet { project in
                dataManager.addProject(project, to: currentFacility, in: currentCustomer)
                // Update local state
                if let cust = dataManager.customers.first(where: { $0.id == customer.id }),
                   let fac = cust.facilities.first(where: { $0.id == facility.id }) {
                    customer = cust
                    facility = fac
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.sasBlue.opacity(0.5))
            
            Text("No Projects Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.sasTextPrimary)
            
            Text("Add a project to organize\nyour virtual tours")
                .font(.subheadline)
                .foregroundColor(.sasTextSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddProject = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Project")
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
    
    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = currentFacility.projects[index]
            dataManager.deleteProject(project, from: currentFacility, in: currentCustomer)
        }
        // Update local state
        if let cust = dataManager.customers.first(where: { $0.id == customer.id }),
           let fac = cust.facilities.first(where: { $0.id == facility.id }) {
            customer = cust
            facility = fac
        }
    }
}

// MARK: - Project Row
struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.sasOrange.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "doc.text")
                        .foregroundColor(.sasOrange)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.sasTextPrimary)
                
                if !project.description.isEmpty {
                    Text(project.description)
                        .font(.caption)
                        .foregroundColor(.sasTextSecondary)
                        .lineLimit(1)
                } else {
                    Text("\(project.tours.count) tours")
                        .font(.caption)
                        .foregroundColor(.sasTextSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.sasTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Project Sheet
struct AddProjectSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    var onCreate: (Project) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Name")
                            .font(.subheadline)
                            .foregroundColor(.sasTextSecondary)
                        
                        TextField("e.g., Line 4 Retrofit, Control Room Update", text: $name)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.sasCardBg)
                            .cornerRadius(10)
                            .foregroundColor(.sasTextPrimary)
                    }
                    .padding(.horizontal)
                    
                    // Description input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.sasTextSecondary)
                        
                        TextField("Brief project description", text: $description, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.sasCardBg)
                            .cornerRadius(10)
                            .foregroundColor(.sasTextPrimary)
                            .lineLimit(3...6)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Create button
                    Button(action: createProject) {
                        Text("Add Project")
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
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
        }
    }
    
    private func createProject() {
        let project = Project(name: name, description: description)
        onCreate(project)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProjectListView(
            customer: Customer(name: "Test Customer"),
            facility: Facility(name: "Test Facility")
        )
        .environmentObject(DataManager())
    }
}
