//
//  CoachingOverlayRepresentable.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI
import ARKit

/** 
 A SwiftUI representable wrapper that provides AR coaching overlays to guide users through AR setup and tracking.
 Integrates ARCoachingOverlayView into SwiftUI view hierarchy with geospatial tracking support.
*/
struct CoachingOverlayRepresentable: UIViewRepresentable {
    /** The AR session that provides tracking state and configuration for the coaching overlay */
    let session: ARSession?

    /** 
     Creates and returns a configured ARCoachingOverlayView instance.
     Automatically sets up geospatial tracking goal and flexible layout constraints.
    */
    func makeUIView(context: Context) -> ARCoachingOverlayView {
        let overlay = ARCoachingOverlayView()
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.goal = .geoTracking
        overlay.session = session
        return overlay
    }

    func updateUIView(_ uiView: ARCoachingOverlayView, context: Context) {}
}

