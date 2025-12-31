//
//  FacilityListView.swift
//  SAS360Capture
//
//  Facility list for a customer with add, edit, and delete functionality
//

import SwiftUI

struct FacilityListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State var customer: Customer
    @State private var showingAddFacility = false
    @State private var editMode: EditMode = .inactive
    
    // Get updated customer from dataManager
    var currentCustomer: Customer {
        dataManager.customers.first { $0.id == customer.id } ?? customer
    }
    
    var body: some View {
        ZStack {
            Color.sasDarkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if currentCustomer.facilities.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(currentCustomer.facilities) { facility in
                            NavigationLink(destination: ProjectListView(customer: currentCustomer, facility: facility)) {
                                FacilityRow(facility: facility)
                            }
                            .listRowBackground(Color.sasCardBg)
                        }
                        .onDelete(perform: deleteFacilities)
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, $editMode)
                }
            }
        }
        .navigationTitle(currentCustomer.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !currentCustomer.facilities.isEmpty {
                        Button(editMode == .active ? "Done" : "Edit") {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }
                        .foregroundColor(.sasOrange)
                    }
                    
                    Button(action: { showingAddFacility = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.sasOrange)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddFacility) {
            AddFacilitySheet { facility in
                dataManager.addFacility(facility, to: currentCustomer)
                // Update local state
                if let updated = dataManager.customers.first(where: { $0.id == customer.id }) {
                    customer = updated
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "building")
                .font(.system(size: 60))
                .foregroundColor(.sasBlue.opacity(0.5))
            
            Text("No Facilities Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.sasTextPrimary)
            
            Text("Add a facility location for\n\(currentCustomer.name)")
                .font(.subheadline)
                .foregroundColor(.sasTextSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddFacility = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Facility")
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
    
    private func deleteFacilities(at offsets: IndexSet) {
        for index in offsets {
            let facility = currentCustomer.facilities[index]
            dataManager.deleteFacility(facility, from: currentCustomer)
        }
        // Update local state
        if let updated = dataManager.customers.first(where: { $0.id == customer.id }) {
            customer = updated
        }
    }
}

// MARK: - Facility Row
struct FacilityRow: View {
    let facility: Facility
    
    var totalTours: Int {
        facility.projects.flatMap { $0.tours }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.sasBlue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "building")
                        .foregroundColor(.sasBlue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(facility.name)
                    .font(.headline)
                    .foregroundColor(.sasTextPrimary)
                
                if !facility.address.isEmpty {
                    Text(facility.address)
                        .font(.caption)
                        .foregroundColor(.sasTextSecondary)
                        .lineLimit(1)
                } else {
                    Text("\(facility.projects.count) projects • \(totalTours) tours")
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

// MARK: - Add Facility Sheet
struct AddFacilitySheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var notes = ""
    var onCreate: (Facility) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Name input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Facility Name")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            TextField("e.g., Main Plant, Building A", text: $name)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.sasCardBg)
                                .cornerRadius(10)
                                .foregroundColor(.sasTextPrimary)
                        }
                        
                        // Address input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            TextField("Street address", text: $address)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.sasCardBg)
                                .cornerRadius(10)
                                .foregroundColor(.sasTextPrimary)
                        }
                        
                        // Notes input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.sasTextSecondary)
                            
                            TextField("Any additional information", text: $notes, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.sasCardBg)
                                .cornerRadius(10)
                                .foregroundColor(.sasTextPrimary)
                                .lineLimit(3...6)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Create button
                        Button(action: createFacility) {
                            Text("Add Facility")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(name.isEmpty ? Color.gray : Color.sasOrange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(name.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Facility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
        }
    }
    
    private func createFacility() {
        let facility = Facility(name: name, address: address, notes: notes)
        onCreate(facility)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        FacilityListView(customer: Customer(name: "Test Customer"))
            .environmentObject(DataManager())
    }
}
