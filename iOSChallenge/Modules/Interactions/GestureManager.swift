//
//  GestureManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import UIKit
import RealityKit

/** 
 A manager class that handles gesture interactions for 3D models in AR.
 
 Coordinates tap, swipe, and pinch gestures with physics and haptic feedback
 through `PhysicsManager` and `FeedbackManager` integration.
 */
final class GestureManager: NSObject {
    private weak var arView: ARView?
    private weak var target: ModelEntity?

    /**
     Initializes gesture recognition for a 3D model in AR.
     
     - Parameters:
       - arView: Target AR view for gesture recognition
       - target: 3D model to receive gesture interactions
     */
    init(arView: ARView, target: ModelEntity) {
        super.init()
        self.arView = arView
        self.target = target

        GestureBinder.bindGestures(
            on: arView,
            tap: { [weak self] in self?.handleTap() },
            swipe: { [weak self] dir in self?.handleSwipe(dir) },
            pinch: { [weak self] scale in self?.handlePinch(scale) }
        )
    }

    /** Applies vertical impulse and haptic feedback on tap */
    private func handleTap() {
        guard let target = target else { return }
        PhysicsManager.applyImpulse(target, impulse: [0, 2, 0])
        FeedbackManager.jump(on: target)
    }

    /** 
     Rotates model around Y-axis based on swipe direction
     - Parameter direction: Left or right swipe direction
     */
    private func handleSwipe(_ direction: UISwipeGestureRecognizer.Direction) {
        guard let target = target else { return }
        let angle: Float = (direction == .left) ? .pi/8 : -.pi/8
        target.transform.rotation *= simd_quatf(angle: angle, axis: [0,1,0])
        FeedbackManager.turn(on: target)
    }

    /** 
     Adjusts model scale with bounds checking (0.1 to 2.0)
     - Parameter scale: Pinch gesture scale factor
     */
    private func handlePinch(_ scale: CGFloat) {
        guard let target = target else { return }
        let newScale = Float(scale) * target.scale.x
        target.scale = SIMD3<Float>(repeating: max(0.1, min(newScale, 2.0)))
        FeedbackManager.scale(on: target)
    }
}


