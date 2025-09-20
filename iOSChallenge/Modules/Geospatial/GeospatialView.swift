//
//  GeospatialView.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI
import RealityKit
import ARKit

/** 
 * Primary view for the Geospatial AR experience that anchors 3D content to real-world coordinates.
 * Integrates ARKit's geospatial tracking with RealityKit for precise model placement.
 */
struct GeospatialView: View {
    @StateObject private var manager = GeospatialManager()

    var body: some View {
        ARContainerOverlay(
            arContent: GeospatialARViewContainer(manager: manager),
            trackingStatus: manager.trackingStatus,
            navigationStatus: manager.navigationStatus,
            onboardingTitle: "Geospatial AR",
            onboardingHints: [
                "Soldier placed at real GPS coordinates",
                "Uses VPS or GPS positioning for accuracy", 
                "Walk around to see stable GPS anchoring",
                "Tap → Make soldier jump",
                "Swipe → Rotate soldier",
                "Pinch → Scale soldier", 
                "Pan → Move soldier",
                "Follow blue waypoints to reach the soldier"
            ],
            onboardingKey: "GeospatialOnboardingShown",
            sessionProvider: { manager.getARSession() }
        )
        .overlay(alignment: .top) {
            VStack(spacing: 4) {
                if manager.inFallback {
                    Text("Running in World Tracking (VPS unavailable here). Navigation may be limited.")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                
                if !manager.estimatedPositioningError.isEmpty {
                    Text(manager.estimatedPositioningError)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                }
            }
            .padding(.top, 60)
        }
                .alert(manager.inFallback ? "World Tracking Mode" : "Geotracking unavailable",
               isPresented: $manager.showAlert) {
            if manager.inFallback {
                Button("Continue") {
                    manager.userAcknowledged = true
                }
            } else {
                Button("OK") { }
            }
        } message: {
            Text(manager.alertMessage)
        }
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            debugMenu
        }
        .overlay(alignment: .bottomLeading) {
            if manager.showManualAdjustment && manager.inFallback {
                manualAdjustmentControls
            }
        }
        #endif
    }
    
    #if DEBUG
    @ViewBuilder
    private var debugMenu: some View {
        VStack(spacing: 8) {
            Button(action: {
                manager.printSceneHierarchy()
            }) {
                Image(systemName: "tree")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Button(action: {
                manager.printPerformanceInfo()
            }) {
                Image(systemName: "speedometer")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            if manager.inFallback {
                Button(action: {
                    manager.showManualAdjustment.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    manager.placeSoldierAtNearbyTestLocation()
                }) {
                    Image(systemName: "location.circle")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.bottom, 100)
        .padding(.trailing, 20)
    }
    
    @ViewBuilder
    private var manualAdjustmentControls: some View {
        VStack(spacing: 8) {
            Text("Manual Position Adjustment")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
            
            HStack(spacing: 8) {
                // Forward/Backward
                VStack(spacing: 4) {
                    Button("↑") {
                        manager.adjustSoldierPosition(offset: SIMD3<Float>(0, 0, -0.5))
                    }
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(4)
                    
                    Button("↓") {
                        manager.adjustSoldierPosition(offset: SIMD3<Float>(0, 0, 0.5))
                    }
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(4)
                }
                
                // Left/Right
                VStack(spacing: 4) {
                    Button("←") {
                        manager.adjustSoldierPosition(offset: SIMD3<Float>(-0.5, 0, 0))
                    }
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.green.opacity(0.7))
                    .cornerRadius(4)
                    
                    Button("→") {
                        manager.adjustSoldierPosition(offset: SIMD3<Float>(0.5, 0, 0))
                    }
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.green.opacity(0.7))
                    .cornerRadius(4)
                }
                
                // Up/Down
                VStack(spacing: 4) {
                    Button("↗") {
                        manager.adjustSoldierPosition(offset: SIMD3<Float>(0, 0.5, 0))
                    }
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.orange.opacity(0.7))
                    .cornerRadius(4)
                    
                    Button("↘") {
                        manager.adjustSoldierPosition(offset: SIMD3<Float>(0, -0.5, 0))
                    }
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.orange.opacity(0.7))
                    .cornerRadius(4)
                }
            }
            
            Button("Reset") {
                manager.resetManualAdjustment()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.7))
            .cornerRadius(6)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .padding(.bottom, 100)
        .padding(.leading, 20)
    }
    #endif
}

/** 
 * SwiftUI container for RealityKit's ARView that manages geospatial AR content.
 */
struct GeospatialARViewContainer: UIViewRepresentable {
    let manager: GeospatialManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        manager.setupAR(in: arView)

        manager.placeSoldierAt(
            lat: GeoConfig.beccasBeautyBar.latitude,
            lon: GeoConfig.beccasBeautyBar.longitude,
            altitude: GeoConfig.beccasBeautyBar.altitude
        )

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // View updates handled by GeospatialManager
    }
}

