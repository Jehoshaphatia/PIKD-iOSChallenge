//
//  DetectionView.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI
import RealityKit
import ARKit
import Vision

/**
 * DetectionView provides the main UI for the object detection AR experience.
 * Integrates with ObjectDetectionManager for real-time detection and AR model placement.
 */
struct DetectionView: View {
    @StateObject private var manager = ObjectDetectionManager()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Main AR container with coaching overlay and onboarding
            ARContainerOverlay(
                arContent: DetectionARViewContainer(manager: manager),
                trackingStatus: manager.trackingStatus,
                navigationStatus: nil,                 // Navigation not used in detection mode
                onboardingTitle: "Object Detection",
                onboardingHints: [
                    "Point your camera at real objects",
                    "Recognized objects appear as AR models",
                    "Tap detected models to interact"
                ],
                onboardingKey: "DetectionOnboardingShown",
                sessionProvider: { manager.arViewInstance()?.session }
            )

            // Detection status overlay - shows current detection state
            if manager.isDetectionRunning {
                if manager.detectionStatus == "No detection yet" {
                    ProgressView("Scanning for objects…")
                        .font(.caption)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding()
                } else {
                    Text(manager.detectionStatus)
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding()
                }
            } else {
                Text("Detection paused")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding()
            }
        }
        .onAppear {
            print("DetectionView appeared - starting detection timer")
            manager.startDetectionTimer()
        }
        .onDisappear {
            print("DetectionView disappeared - stopping detection timer")
            manager.stopDetectionTimer()
        }
    }
}

/**
 * DetectionARViewContainer is a UIViewRepresentable wrapper for ARView.
 * Bridges SwiftUI and UIKit for ARView integration.
 */
struct DetectionARViewContainer: UIViewRepresentable {
    /// Reference to the object detection manager for AR session configuration
    let manager: ObjectDetectionManager
    
    /**
     * Creates the ARView instance and configures it for object detection.
     */
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        manager.setupAR(in: arView)
        return arView
    }

    /**
     * Updates the ARView when SwiftUI state changes.
     */
    func updateUIView(_ uiView: ARView, context: Context) {}
}
