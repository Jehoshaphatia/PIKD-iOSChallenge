//
//  ARCoachingOverlayView.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI
import ARKit
import RealityKit

/** SwiftUI wrapper for ARCoachingOverlayView providing geo-tracking guidance in AR experiences */
struct CoachingOverlay: UIViewRepresentable {
    /** The ARView providing the AR session for coaching */
    weak var arView: ARView?

    /** Creates and configures the coaching overlay view 
     - Parameter context: View creation context
     - Returns: Configured ARCoachingOverlayView for geo-tracking
     */
    func makeUIView(context: Context) -> ARCoachingOverlayView {
        let overlay = ARCoachingOverlayView()
        overlay.session = arView?.session
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.goal = .geoTracking
        return overlay
    }

    func updateUIView(_ uiView: ARCoachingOverlayView, context: Context) {
    }
}
