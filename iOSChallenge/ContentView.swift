//
//  ContentView.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI

/** Main view controller providing navigation between AR features:
    - Geospatial tracking with character placement
    - Object detection with real-time YOLO analysis
*/
struct ContentView: View {
    /** Sets up the view with styled tab bar configuration */
    init() {
        // Style tab bar globally
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    /** TabView-based navigation interface */
    var body: some View {
        TabView {
            GeospatialView()
                .tabItem { Label("Geo", systemImage: "location") }

            DetectionView()
                .tabItem { Label("Detect", systemImage: "camera.viewfinder") }
        }

    }
}

#Preview {
    ContentView()
}
