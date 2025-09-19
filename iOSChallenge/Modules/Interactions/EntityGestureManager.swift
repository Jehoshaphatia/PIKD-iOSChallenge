//
//  EntityGestureManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 19/09/2025.
//

import UIKit
import RealityKit

/** 
 Manages tap, pinch, and pan gestures for specific entities in an ARView.
 Uses hit-testing to target specific entities for interaction.
 */
final class EntityGestureManager: NSObject {
    private weak var arView: ARView?
    private weak var targetEntity: Entity?
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var pinchGestureRecognizer: UIPinchGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    /** 
     - Parameters:
        - arView: ARView for gesture recognition
        - target: Entity to manage gestures for
     */
    init(arView: ARView, target: Entity) {
        super.init()
        self.arView = arView
        self.targetEntity = target
        
        setupGestures()
    }
    
    // Sets up tap, pinch and pan gesture recognizers
    private func setupGestures() {
        guard let arView = arView else { return }
        
        // Create gesture recognizers
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        
        // Set delegates for simultaneous recognition
        tapGestureRecognizer.delegate = self
        pinchGestureRecognizer.delegate = self
        panGestureRecognizer.delegate = self
        
        // Add to ARView
        arView.addGestureRecognizer(tapGestureRecognizer)
        arView.addGestureRecognizer(pinchGestureRecognizer)
        arView.addGestureRecognizer(panGestureRecognizer)
        
        print("Gesture recognizers added for entity: \(targetEntity?.name ?? "unknown")")
    }
    
    /** 
     Applies an upward impulse to the target entity when tapped.
     - Parameter gesture: Tap gesture recognizer
     */
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = arView,
              let targetEntity = targetEntity else { 
            print("Tap gesture: Missing arView or targetEntity")
            return 
        }
        
        let tapLocation = gesture.location(in: arView)
        print("Tap detected at \(tapLocation) for entity: \(targetEntity.name)")
        
        // Hit test to see if tap hits our specific entity
        if let hitEntity = arView.entity(at: tapLocation) {
            print("Hit entity: \(hitEntity.name) (looking for: \(targetEntity.name))")
            
            if hitEntity == targetEntity || isDescendant(entity: hitEntity, of: targetEntity) {
                print("Hit matches target entity!")
                
                // Apply impulse and feedback
                if let modelEntity = targetEntity as? ModelEntity {
                    // Temporarily make dynamic for impulse, then back to kinematic
                    if var physicsBody = modelEntity.components[PhysicsBodyComponent.self] {
                        physicsBody.mode = .dynamic
                        modelEntity.components[PhysicsBodyComponent.self] = physicsBody
                        
                        PhysicsManager.applyImpulse(modelEntity, impulse: [0, 2, 0])
                        
                        // Reset to kinematic after a short delay to prevent falling
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if var resetPhysicsBody = modelEntity.components[PhysicsBodyComponent.self] {
                                resetPhysicsBody.mode = .kinematic
                                modelEntity.components[PhysicsBodyComponent.self] = resetPhysicsBody
                            }
                        }
                    }
                }
                FeedbackManager.jump(on: targetEntity)
                
                print("Tapped \(targetEntity.name) (EntityGestureManager)")
            } else {
                print("Hit entity doesn't match target")
            }
        } else {
            print("No entity hit at tap location")
        }
    }
    
    /** 
     Scales the target entity within a range of 0.1 to 2.0.
     - Parameter gesture: Pinch gesture recognizer
     */
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let arView = arView,
              let targetEntity = targetEntity else { return }
        
        let center = gesture.location(in: arView)
        
        // Hit test to see if pinch is on our entity
        if let hitEntity = arView.entity(at: center),
           hitEntity == targetEntity || isDescendant(entity: hitEntity, of: targetEntity) {
            
            if gesture.state == .changed {
                let newScale = Float(gesture.scale) * targetEntity.scale.x
                targetEntity.scale = SIMD3<Float>(repeating: max(0.1, min(newScale, 2.0)))
                
                if gesture.state == .began {
                    FeedbackManager.scale(on: targetEntity)
                    print("Scaled \(targetEntity.name) (EntityGestureManager)")
                }
            }
            
            if gesture.state == .ended {
                gesture.scale = 1.0 // Reset for next time
            }
        }
    }
    
    /** 
     Translates the target entity based on pan gesture movement.
     - Parameter gesture: Pan gesture recognizer
     */
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let arView = arView,
              let targetEntity = targetEntity else { return }
        
        let center = gesture.location(in: arView)
        
        // Hit test to see if pan is on our entity
        if let hitEntity = arView.entity(at: center),
           hitEntity == targetEntity || isDescendant(entity: hitEntity, of: targetEntity) {
            
            if gesture.state == .changed {
                let translation = gesture.translation(in: arView)
                let delta = SIMD3<Float>(Float(translation.x) * 0.001, 0, Float(-translation.y) * 0.001)
                targetEntity.position += delta
                
                gesture.setTranslation(.zero, in: arView) // Reset translation
                
                if gesture.state == .began {
                    FeedbackManager.walkStep(on: targetEntity)
                    print("Moved \(targetEntity.name) (EntityGestureManager)")
                }
            }
        }
    }
    
    /** 
     - Parameters:
        - entity: Entity to check
        - parent: Potential parent entity
     - Returns: Whether entity is a descendant of parent
     */
    private func isDescendant(entity: Entity, of parent: Entity) -> Bool {
        var current = entity.parent
        while let currentEntity = current {
            if currentEntity == parent {
                return true
            }
            current = currentEntity.parent
        }
        return false
    }
    
    deinit {
        // Clean up gesture recognizers
        if let arView = arView {
            arView.removeGestureRecognizer(tapGestureRecognizer)
            arView.removeGestureRecognizer(pinchGestureRecognizer)
            arView.removeGestureRecognizer(panGestureRecognizer)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension EntityGestureManager: UIGestureRecognizerDelegate {
    /** Enables simultaneous gesture recognition */
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow multiple gestures to work together
        return true
    }
}
