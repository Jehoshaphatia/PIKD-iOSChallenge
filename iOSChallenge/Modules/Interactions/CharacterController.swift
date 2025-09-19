//
//  CharacterController.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import RealityKit
import UIKit

/** 
 Controls gesture interactions for a character entity in AR, managing animations,
 transformations, and physics via PhysicsManager with FeedbackManager integration.
 */
final class CharacterController: NSObject {
    private weak var arView: ARView?
    private var character: ModelEntity?

    /**
     Initializes a new character controller.
     - Parameters:
       - arView: Target ARView for gesture handling
       - character: ModelEntity to control
     */
    init(arView: ARView, character: ModelEntity) {
        self.arView = arView
        self.character = character
        super.init()

        PhysicsManager.addPhysics(to: character)
        GestureBinder.bindGestures(
            on: arView,
            tap: { [weak self] in self?.handleTap() },
            swipe: { [weak self] dir in self?.handleSwipe(dir) },
            pinch: { [weak self] scale in self?.handlePinch(scale) },
            pan: { [weak self] translation in self?.handlePan(translation) }
        )
    }

    /** Applies jump animation, physics impulse, and feedback on tap */
    private func handleTap() {
        guard let character = character else { return }

        if let anim = character.availableAnimations.first(where: { $0.name == "Jump" }) {
            character.playAnimation(anim, transitionDuration: 0.15)
        }
        
        PhysicsManager.applyImpulse(character, impulse: [0, 2, 0])
        FeedbackManager.jump(on: character)
    }

    /** Rotates character by 45° on left swipe */
    private func handleSwipe(_ direction: UISwipeGestureRecognizer.Direction) {
        guard let character = character else { return }

        if direction == .left {
            character.orientation *= simd_quatf(angle: .pi/4, axis: [0,1,0])
            FeedbackManager.turn(on: character)
        }
    }

    /** Updates character scale based on pinch gesture */
    private func handlePinch(_ scale: CGFloat) {
        guard let character = character else { return }
        
        character.scale = SIMD3<Float>(repeating: Float(scale))
        FeedbackManager.scale(on: character)
    }

    /** Translates character position based on pan gesture */
    private func handlePan(_ translation: CGPoint) {
        guard let character = character else { return }
        
        let delta = SIMD3<Float>(Float(translation.x) * 0.001, 0, Float(-translation.y) * 0.001)
        character.position += delta
        FeedbackManager.walkStep(on: character)
    }
}



