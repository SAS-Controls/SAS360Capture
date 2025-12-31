//
//  CustomerListView.swift
//  SAS360Capture
//
//  Customer list with add, edit, and delete functionality
//

import SwiftUI

struct CustomerListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddCustomer = false
    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return dataManager.customers
        }
        return dataManager.customers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            Color.sasDarkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                if dataManager.customers.isEmpty {
                    emptyStateView
                } else {
                    // Search bar
                    searchBar
                    
                    // Customer list
                    List {
                        ForEach(filteredCustomers) { customer in
                            NavigationLink(destination: FacilityListView(customer: customer)) {
                                CustomerRow(customer: customer)
                            }
                            .listRowBackground(Color.sasCardBg)
                        }
                        .onDelete(perform: deleteCustomers)
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, $editMode)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddCustomer) {
            AddCustomerSheet { customer in
                dataManager.addCustomer(customer)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    SASLogo(size: 36)
                    Text("Customers")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.sasTextPrimary)
                }
            }
            
            Spacer()
            
            if !dataManager.customers.isEmpty {
                Button(editMode == .active ? "Done" : "Edit") {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }
                .foregroundColor(.sasOrange)
                .padding(.trailing, 8)
            }
            
            Button(action: { showingAddCustomer = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.sasOrange)
            }
        }
        .padding()
        .background(Color.sasCardBg)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.sasTextSecondary)
            TextField("Search customers", text: $searchText)
                .foregroundColor(.sasTextPrimary)
        }
        .padding(10)
        .background(Color.sasCardBg)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.sasBlue.opacity(0.5))
            
            Text("No Customers Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.sasTextPrimary)
            
            Text("Add your first customer to start\norganizing virtual tours")
                .font(.subheadline)
                .foregroundColor(.sasTextSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddCustomer = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Customer")
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
    
    private func deleteCustomers(at offsets: IndexSet) {
        for index in offsets {
            let customer = filteredCustomers[index]
            dataManager.deleteCustomer(customer)
        }
    }
}

// MARK: - Customer Row
struct CustomerRow: View {
    let customer: Customer
    
    var totalTours: Int {
        customer.facilities.flatMap { $0.projects }.flatMap { $0.tours }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(Color.sasBlue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(customer.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.sasBlue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.name)
                    .font(.headline)
                    .foregroundColor(.sasTextPrimary)
                
                Text("\(customer.facilities.count) facilities • \(totalTours) tours")
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

// MARK: - Add Customer Sheet
struct AddCustomerSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var notes = ""
    var onCreate: (Customer) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sasDarkBg.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Customer Name")
                            .font(.subheadline)
                            .foregroundColor(.sasTextSecondary)
                        
                        TextField("e.g., ABC Manufacturing", text: $name)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.sasCardBg)
                            .cornerRadius(10)
                            .foregroundColor(.sasTextPrimary)
                    }
                    .padding(.horizontal)
                    
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
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Create button
                    Button(action: createCustomer) {
                        Text("Add Customer")
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
            .navigationTitle("New Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sasOrange)
                }
            }
        }
    }
    
    private func createCustomer() {
        let customer = Customer(name: name, notes: notes)
        onCreate(customer)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CustomerListView()
            .environmentObject(DataManager())
    }
}
