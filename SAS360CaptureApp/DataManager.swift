//
//  DataManager.swift
//  SAS360Capture
//
//  Manages data persistence and app state
//

import Foundation
import SwiftUI
import Combine

class DataManager: ObservableObject {
    // MARK: - Published Properties
    @Published var customers: [Customer] = []
    @Published var unassignedTours: [Tour] = []
    @Published var settings: AppSettings = AppSettings()
    @Published var cameraState: CameraConnectionState = .disconnected
    @Published var cameraInfo: CameraInfo?
    
    // MARK: - File Paths
    private let documentsPath: URL
    private let customersFile: URL
    private let unassignedToursFile: URL
    private let settingsFile: URL
    private let imagesFolder: URL
    
    // MARK: - Initialization
    init() {
        // Set up file paths
        documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        customersFile = documentsPath.appendingPathComponent("customers.json")
        unassignedToursFile = documentsPath.appendingPathComponent("unassigned_tours.json")
        settingsFile = documentsPath.appendingPathComponent("settings.json")
        imagesFolder = documentsPath.appendingPathComponent("Images")
        
        // Create images folder if needed
        try? FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
        
        // Load data
        loadData()
    }
    
    // MARK: - Data Loading
    private func loadData() {
        // Load customers
        if let data = try? Data(contentsOf: customersFile),
           let decoded = try? JSONDecoder().decode([Customer].self, from: data) {
            customers = decoded
        }
        
        // Load unassigned tours
        if let data = try? Data(contentsOf: unassignedToursFile),
           let decoded = try? JSONDecoder().decode([Tour].self, from: data) {
            unassignedTours = decoded
        }
        
        // Load settings
        if let data = try? Data(contentsOf: settingsFile),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }
    
    // MARK: - Data Saving
    func saveData() {
        // Save customers
        if let data = try? JSONEncoder().encode(customers) {
            try? data.write(to: customersFile)
        }
        
        // Save unassigned tours
        if let data = try? JSONEncoder().encode(unassignedTours) {
            try? data.write(to: unassignedToursFile)
        }
        
        // Save settings
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsFile)
        }
    }
    
    // MARK: - Customer Operations
    func addCustomer(_ customer: Customer) {
        customers.append(customer)
        saveData()
    }
    
    func updateCustomer(_ customer: Customer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            var updated = customer
            updated.lastModifiedAt = Date()
            customers[index] = updated
            saveData()
        }
    }
    
    func deleteCustomer(_ customer: Customer) {
        // Delete all associated images
        for facility in customer.facilities {
            for project in facility.projects {
                for tour in project.tours {
                    deleteTourImages(tour)
                }
            }
        }
        customers.removeAll { $0.id == customer.id }
        saveData()
    }
    
    // MARK: - Facility Operations
    func addFacility(_ facility: Facility, to customer: Customer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[index].facilities.append(facility)
            customers[index].lastModifiedAt = Date()
            saveData()
        }
    }
    
    func updateFacility(_ facility: Facility, in customer: Customer) {
        if let custIndex = customers.firstIndex(where: { $0.id == customer.id }),
           let facIndex = customers[custIndex].facilities.firstIndex(where: { $0.id == facility.id }) {
            var updated = facility
            updated.lastModifiedAt = Date()
            customers[custIndex].facilities[facIndex] = updated
            customers[custIndex].lastModifiedAt = Date()
            saveData()
        }
    }
    
    func deleteFacility(_ facility: Facility, from customer: Customer) {
        if let custIndex = customers.firstIndex(where: { $0.id == customer.id }) {
            // Delete associated images
            for project in facility.projects {
                for tour in project.tours {
                    deleteTourImages(tour)
                }
            }
            customers[custIndex].facilities.removeAll { $0.id == facility.id }
            customers[custIndex].lastModifiedAt = Date()
            saveData()
        }
    }
    
    // MARK: - Project Operations
    func addProject(_ project: Project, to facility: Facility, in customer: Customer) {
        if let custIndex = customers.firstIndex(where: { $0.id == customer.id }),
           let facIndex = customers[custIndex].facilities.firstIndex(where: { $0.id == facility.id }) {
            customers[custIndex].facilities[facIndex].projects.append(project)
            customers[custIndex].facilities[facIndex].lastModifiedAt = Date()
            customers[custIndex].lastModifiedAt = Date()
            saveData()
        }
    }
    
    func updateProject(_ project: Project, in facility: Facility, in customer: Customer) {
        if let custIndex = customers.firstIndex(where: { $0.id == customer.id }),
           let facIndex = customers[custIndex].facilities.firstIndex(where: { $0.id == facility.id }),
           let projIndex = customers[custIndex].facilities[facIndex].projects.firstIndex(where: { $0.id == project.id }) {
            var updated = project
            updated.lastModifiedAt = Date()
            customers[custIndex].facilities[facIndex].projects[projIndex] = updated
            customers[custIndex].facilities[facIndex].lastModifiedAt = Date()
            customers[custIndex].lastModifiedAt = Date()
            saveData()
        }
    }
    
    func deleteProject(_ project: Project, from facility: Facility, in customer: Customer) {
        if let custIndex = customers.firstIndex(where: { $0.id == customer.id }),
           let facIndex = customers[custIndex].facilities.firstIndex(where: { $0.id == facility.id }) {
            // Delete associated images
            for tour in project.tours {
                deleteTourImages(tour)
            }
            customers[custIndex].facilities[facIndex].projects.removeAll { $0.id == project.id }
            customers[custIndex].facilities[facIndex].lastModifiedAt = Date()
            customers[custIndex].lastModifiedAt = Date()
            saveData()
        }
    }
    
    // MARK: - Tour Operations
    func addTour(_ tour: Tour, to project: Project, in facility: Facility, in customer: Customer) {
        if let custIndex = customers.firstIndex(where: { $0.id == customer.id }),
           let facIndex = customers[custIndex].facilities.firstIndex(where: { $0.id == facility.id }),
           let projIndex = customers[custIndex].facilities[facIndex].projects.firstIndex(where: { $0.id == project.id }) {
            customers[custIndex].facilities[facIndex].projects[projIndex].tours.append(tour)
            customers[custIndex].facilities[facIndex].projects[projIndex].lastModifiedAt = Date()
            customers[custIndex].facilities[facIndex].lastModifiedAt = Date()
            customers[custIndex].lastModifiedAt = Date()
            saveData()
        }
    }
    
    func updateTour(_ tour: Tour, in project: Project, in facility: Facility, in customer: Customer) {
        if let custIndex = customers.firstIndex(where: { $0.id == customer.id }),
           let facIndex = customers[custIndex].facilities.firstIndex(where: { $0.id == facility.id }),
           let projIndex = customers[custIndex].facilities[facIndex].projects.firstIndex(where: { $0.id == project.id }),
           let tourIndex = customers[custIndex].facilities[facIndex].projects[projIndex].tours.firstIndex(where: { $0.id == tour.id }) {
            var updated = tour
            updated.lastModifiedAt = Date()
            customers[custIndex].facilities[facIndex].projects[projIndex].tours[tourIndex] = updated
            customers[custIndex].facilities[facIndex].projects[projIndex].lastModifiedAt = Date()
            customers[custIndex].facilities[facIndex].lastModifiedAt = Date()
            customers[custIndex].lastModifiedAt = Date()
            saveData()
        }
    }
    
    func deleteTour(_ tour: Tour, from project: Project, in facility: Facility, in customer: Customer) {
        if let custIndex = customers.firstIndex(where: { $0.id == customer.id }),
           let facIndex = customers[custIndex].facilities.firstIndex(where: { $0.id == facility.id }),
           let projIndex = customers[custIndex].facilities[facIndex].projects.firstIndex(where: { $0.id == project.id }) {
            deleteTourImages(tour)
            customers[custIndex].facilities[facIndex].projects[projIndex].tours.removeAll { $0.id == tour.id }
            customers[custIndex].facilities[facIndex].projects[projIndex].lastModifiedAt = Date()
            customers[custIndex].facilities[facIndex].lastModifiedAt = Date()
            customers[custIndex].lastModifiedAt = Date()
            saveData()
        }
    }
    
    // MARK: - Unassigned Tour Operations
    func addUnassignedTour(_ tour: Tour) {
        var newTour = tour
        newTour.isAssigned = false
        unassignedTours.append(newTour)
        saveData()
    }
    
    func updateUnassignedTour(_ tour: Tour) {
        if let index = unassignedTours.firstIndex(where: { $0.id == tour.id }) {
            var updated = tour
            updated.lastModifiedAt = Date()
            unassignedTours[index] = updated
            saveData()
        }
    }
    
    func deleteUnassignedTour(_ tour: Tour) {
        deleteTourImages(tour)
        unassignedTours.removeAll { $0.id == tour.id }
        saveData()
    }
    
    func assignTour(_ tour: Tour, to project: Project, in facility: Facility, in customer: Customer) {
        var assignedTour = tour
        assignedTour.isAssigned = true
        addTour(assignedTour, to: project, in: facility, in: customer)
        unassignedTours.removeAll { $0.id == tour.id }
        saveData()
    }
    
    // MARK: - Image Operations
    func saveImage(_ image: UIImage, for tourId: UUID, hotspotId: UUID? = nil) -> String? {
        let tourFolder = imagesFolder.appendingPathComponent(tourId.uuidString)
        try? FileManager.default.createDirectory(at: tourFolder, withIntermediateDirectories: true)
        
        let filename: String
        if let hotspotId = hotspotId {
            filename = "\(hotspotId.uuidString).jpg"
        } else {
            filename = "floorplan.jpg"
        }
        
        let filePath = tourFolder.appendingPathComponent(filename)
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: filePath)
            return filePath.path
        }
        return nil
    }
    
    func loadImage(from path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
    }
    
    func save360Image(_ image: UIImage, for tourId: UUID, hotspotId: UUID) -> String? {
        let tourFolder = imagesFolder.appendingPathComponent(tourId.uuidString)
        try? FileManager.default.createDirectory(at: tourFolder, withIntermediateDirectories: true)
        
        let filename = "360_\(hotspotId.uuidString).jpg"
        let filePath = tourFolder.appendingPathComponent(filename)
        
        // Use higher quality for 360 photos
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: filePath)
            return filePath.path
        }
        return nil
    }
    
    func saveDetailPhoto(_ image: UIImage, for tourId: UUID, annotationId: UUID) -> String? {
        let tourFolder = imagesFolder.appendingPathComponent(tourId.uuidString)
        let detailsFolder = tourFolder.appendingPathComponent("details")
        try? FileManager.default.createDirectory(at: detailsFolder, withIntermediateDirectories: true)
        
        let filename = "\(annotationId.uuidString).jpg"
        let filePath = detailsFolder.appendingPathComponent(filename)
        
        if let data = image.jpegData(compressionQuality: 0.95) {
            try? data.write(to: filePath)
            return filePath.path
        }
        return nil
    }
    
    private func deleteTourImages(_ tour: Tour) {
        let tourFolder = imagesFolder.appendingPathComponent(tour.id.uuidString)
        try? FileManager.default.removeItem(at: tourFolder)
    }
    
    // MARK: - Settings
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveData()
    }
}
