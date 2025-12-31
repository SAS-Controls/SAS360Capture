//
//  SAS360CaptureApp.swift
//  SAS360Capture
//
//  Main app entry point for SAS 360 Capture
//  A Matterport-style virtual tour capture application
//

import SwiftUI

@main
struct SAS360CaptureApp: App {
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataManager)
                .preferredColorScheme(.dark)
        }
    }
}
