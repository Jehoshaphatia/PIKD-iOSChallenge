//
//  CentralGestureManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 19/09/2025.
//

import UIKit
import RealityKit

/** 
 Centralized manager for AR entity gesture interactions.
 Handles tap, pinch, and pan gestures on tracked entities in ARView.
 */
final class CentralGestureManager: NSObject {
    
    private weak var arView: ARView?
    private var trackedEntities: Set<Entity> = []
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var pinchGestureRecognizer: UIPinchGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!

    /** Initialize gesture manager
     - Parameter arView: Target ARView for gesture recognition
     */
    init(arView: ARView) {
        super.init()
        self.arView = arView
        setupGestures()
    }

    private func setupGestures() {
        guard let arView = arView else { return }

        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))

        tapGestureRecognizer.delegate = self
        pinchGestureRecognizer.delegate = self
        panGestureRecognizer.delegate = self

        arView.addGestureRecognizer(tapGestureRecognizer)
        arView.addGestureRecognizer(pinchGestureRecognizer)
        arView.addGestureRecognizer(panGestureRecognizer)

        print("Central gesture manager initialized")
    }

    /** Add entity for gesture tracking
     - Parameter entity: Entity to track
     */
    func addEntity(_ entity: Entity) {
        trackedEntities.insert(entity)
        let position = entity.position(relativeTo: nil)
        print("Added entity to tracking: '", entity.name, "' [", type(of: entity), "] at position", position)
        print("Total tracked entities: ", trackedEntities.count)
    }

    /** Remove entity from gesture tracking
     - Parameter entity: Entity to remove
     */
    func removeEntity(_ entity: Entity) {
        trackedEntities.remove(entity)
        print("Removed entity from tracking: ", entity.name)
        print("Total tracked entities: ", trackedEntities.count)
    }

    /** Handle entity tap interactions with multi-stage hit testing
     - Parameter gesture: Tap gesture recognizer
     */
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = arView else {
            print("Central tap: Missing arView")
            return
        }

        let tapLocation = gesture.location(in: arView)
        print("Central tap detected at", tapLocation)
        
        // Try multiple hit test approaches for better detection
        var hitEntity: Entity?
        
        // 1. Direct hit test using ARView.entity(at:)
        hitEntity = arView.entity(at: tapLocation)
        if let entity = hitEntity {
            print("Direct hit (entity): \(entity.name) [\(type(of: entity))]")
        }
        
        // 2. Use raycast to detect collision components more reliably
        if hitEntity == nil {
            // Convert screen point to ray
            if let raycastQuery = arView.makeRaycastQuery(from: tapLocation, allowing: .estimatedPlane, alignment: .any) {
                let raycastResults = arView.session.raycast(raycastQuery)
                if let firstResult = raycastResults.first {
                    // Check if any of our tracked entities are near this position
                    let hitPosition = SIMD3<Float>(
                        firstResult.worldTransform.columns.3.x,
                        firstResult.worldTransform.columns.3.y,
                        firstResult.worldTransform.columns.3.z
                    )
                    
                    var closestEntity: Entity?
                    var closestDistance: Float = 0.5 // 50cm search radius
                    
                    for entity in trackedEntities {
                        let distance = simd_distance(entity.position(relativeTo: nil), hitPosition)
                        if distance < closestDistance {
                            closestDistance = distance
                            closestEntity = entity
                        }
                    }
                    
                    if let closest = closestEntity {
                        hitEntity = closest
                        print("Raycast hit (closest entity): \(closest.name) at distance \(closestDistance)m")
                    }
                }
            }
        }
        
        // 3. Use physics world query for collision detection
        if hitEntity == nil {
            // Cast a ray from camera through the tap point
            let cameraTransform = arView.cameraTransform
            let cameraPosition = cameraTransform.translation
            
            // Calculate ray direction from camera through tap point
            let screenPoint = CGPoint(x: tapLocation.x / arView.bounds.width, y: tapLocation.y / arView.bounds.height)
            let normalizedPoint = CGPoint(x: screenPoint.x * 2 - 1, y: (1 - screenPoint.y) * 2 - 1)
            
            // Create ray direction (simplified)
            let rayDirection = SIMD3<Float>(
                Float(normalizedPoint.x),
                Float(normalizedPoint.y),
                -1.0 // Forward in camera space
            )
            
            // Normalize and transform to world space
            let worldDirection = simd_normalize(cameraTransform.matrix.upperLeft * rayDirection)
            
            // Check intersection with tracked entities
            for entity in trackedEntities {
                let entityPosition = entity.position(relativeTo: nil)
                let toEntity = entityPosition - cameraPosition
                let projectedDistance = simd_dot(toEntity, worldDirection)
                
                if projectedDistance > 0 { // Entity is in front of camera
                    let closestPoint = cameraPosition + worldDirection * projectedDistance
                    let distance = simd_distance(entityPosition, closestPoint)
                    
                    if distance < 0.2 { // 20cm tolerance
                        hitEntity = entity
                        print("Physics ray hit: \(entity.name) at distance \(distance)m")
                        break
                    }
                }
            }
        }
        
        // 4. expanded search around tap point
        if hitEntity == nil {
            let searchRadius: CGFloat = 30
            for offsetX in [-searchRadius, 0, searchRadius] {
                for offsetY in [-searchRadius, 0, searchRadius] {
                    let searchPoint = CGPoint(x: tapLocation.x + offsetX, y: tapLocation.y + offsetY)
                    if let foundEntity = arView.entity(at: searchPoint) {
                        hitEntity = foundEntity
                        print("Found entity with expanded search at offset (\(offsetX), \(offsetY)): \(foundEntity.name)")
                        break
                    }
                }
                if hitEntity != nil { break }
            }
        }
        
        // 5. screen space proximity to tracked entities
        if hitEntity == nil {
            var closestEntity: Entity?
            var closestDistance: CGFloat = 80 // Maximum search distance
            
            for entity in trackedEntities {
                if let screenPosition = arView.project(entity.position(relativeTo: nil)) {
                    let distance = sqrt(pow(screenPosition.x - tapLocation.x, 2) + pow(screenPosition.y - tapLocation.y, 2))
                    if distance < closestDistance {
                        closestDistance = distance
                        closestEntity = entity
                    }
                }
            }
            
            if let closest = closestEntity {
                hitEntity = closest
                print("Found closest tracked entity by screen distance: \(closest.name) (\(Int(closestDistance))px)")
            }
        }
        
        if let foundEntity = hitEntity {
            print("Hit entity: \(foundEntity.name) [\(type(of: foundEntity))]")
            
            
            // Check if this entity or any of its parents/children is in our tracked entities
            var entityToHandle: Entity?
            
            // Check the entity itself
            if trackedEntities.contains(foundEntity) {
                entityToHandle = foundEntity
                print("Direct match: \(foundEntity.name)")
            }
            
            // Check parents
            if entityToHandle == nil {
                var currentEntity: Entity? = foundEntity
                while let entity = currentEntity {
                    if trackedEntities.contains(entity) {
                        entityToHandle = entity
                        print("Parent match: \(entity.name)")
                        break
                    }
                    currentEntity = entity.parent
                }
            }
            
            // Check children (for complex USDZ hierarchies)
            if entityToHandle == nil {
                for trackedEntity in trackedEntities {
                    if isEntityDescendant(foundEntity, of: trackedEntity) {
                        entityToHandle = trackedEntity
                        print("Child match: found \(foundEntity.name) in tracked \(trackedEntity.name)")
                        break
                    }
                }
            }
            
            if let targetEntity = entityToHandle {
                print("Found tracked entity: \(targetEntity.name)")
                
                // Apply impulse and feedback - look for ModelEntity in the hierarchy
                var modelEntityToAnimate: ModelEntity?
                
                // First check if target is a ModelEntity
                if let modelEntity = targetEntity as? ModelEntity {
                    modelEntityToAnimate = modelEntity
                } else {
                    // Otherwise find first ModelEntity in the hierarchy
                    modelEntityToAnimate = targetEntity.findFirstModelEntity()
                }
                
                if let modelEntity = modelEntityToAnimate {
                    print("Animating ModelEntity: \(modelEntity.name)")
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
                } else {
                    print("No ModelEntity found for animation")
                }
                
                FeedbackManager.jump(on: targetEntity)
                
                print("Tapped \(targetEntity.name) (CentralGestureManager)")
            } else {
                print("Hit entity is not tracked")
                print("DEBUG: Available tracked entities:")
                for entity in trackedEntities {
                    print("  - \(entity.name) [\(type(of: entity))] at \(entity.position(relativeTo: nil))")
                }
            }
        } else {
            print("No entity hit at tap location")
            print("DEBUG: Available tracked entities (\(trackedEntities.count)):")
            for (index, entity) in trackedEntities.enumerated() {
                let position = entity.position(relativeTo: nil)
                let hasCollision = entity.components[CollisionComponent.self] != nil
                let hasPhysics = entity.components[PhysicsBodyComponent.self] != nil
                if let screenPos = arView.project(position) {
                    let tapDistance = sqrt(pow(screenPos.x - tapLocation.x, 2) + pow(screenPos.y - tapLocation.y, 2))
                    print("  \(index + 1). '\(entity.name)' [\(type(of: entity))] at \(position)")
                    print("     Screen: \(screenPos) (tap distance: \(Int(tapDistance))px)")
                    print("     Components: \(hasCollision ? "COLLISION" : "no-collision") \(hasPhysics ? "PHYSICS" : "no-physics")")
                } else {
                    print("  \(index + 1). '\(entity.name)' [\(type(of: entity))] at \(position) (not visible)")
                }
            }
        }
    }
    
    // Helper function to check if an entity is a descendant of another
    private func isEntityDescendant(_ entity: Entity, of ancestor: Entity) -> Bool {
        var current: Entity? = entity.parent
        while let parent = current {
            if parent == ancestor {
                return true
            }
            current = parent.parent
        }
        return false
    }
    
    /** Handle pinch-to-scale gestures on tracked entities
     - Parameter gesture: Pinch gesture recognizer
     */
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let arView = arView else { return }

        let pinchLocation = gesture.location(in: arView)

        // Use the same improved hit detection as tap
        var hitEntity: Entity?
        
        // Try entity hit test first
        hitEntity = arView.entity(at: pinchLocation)
        
        // If no hit, try screen space proximity search
        if hitEntity == nil {
            var closestEntity: Entity?
            var closestDistance: CGFloat = 50
            
            for entity in trackedEntities {
                if let screenPosition = arView.project(entity.position(relativeTo: nil)) {
                    let distance = sqrt(pow(screenPosition.x - pinchLocation.x, 2) + pow(screenPosition.y - pinchLocation.y, 2))
                    if distance < closestDistance {
                        closestDistance = distance
                        closestEntity = entity
                    }
                }
            }
            hitEntity = closestEntity
        }
        
        if let foundEntity = hitEntity {
            // Find tracked entity
            var entityToHandle: Entity?
            var currentEntity: Entity? = foundEntity
            
            while let entity = currentEntity {
                if trackedEntities.contains(entity) {
                    entityToHandle = entity
                    break
                }
                currentEntity = entity.parent
            }
            
            if let targetEntity = entityToHandle {
                if gesture.state == .changed {
                    let scale = Float(gesture.scale)
                    targetEntity.scale = [scale, scale, scale]
                    gesture.scale = 1.0
                }
                
                if gesture.state == .began {
                    FeedbackManager.scale(on: targetEntity)
                    print("Scaled \(targetEntity.name) (CentralGestureManager)")
                }
            }
        }
    }
    
    /** Handle pan-to-move gestures on tracked entities
     - Parameter gesture: Pan gesture recognizer
     */
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let arView = arView else { return }
        
        let panLocation = gesture.location(in: arView)
        
        // Use the same improved hit detection as tap
        var hitEntity: Entity?
        
        // Try entity hit test first
        hitEntity = arView.entity(at: panLocation)
        
        // If no hit, try screen space proximity search
        if hitEntity == nil {
            var closestEntity: Entity?
            var closestDistance: CGFloat = 50
            
            for entity in trackedEntities {
                if let screenPosition = arView.project(entity.position(relativeTo: nil)) {
                    let distance = sqrt(pow(screenPosition.x - panLocation.x, 2) + pow(screenPosition.y - panLocation.y, 2))
                    if distance < closestDistance {
                        closestDistance = distance
                        closestEntity = entity
                    }
                }
            }
            hitEntity = closestEntity
        }
        
        if let foundEntity = hitEntity {
            // Find tracked entity
            var entityToHandle: Entity?
            var currentEntity: Entity? = foundEntity
            
            while let entity = currentEntity {
                if trackedEntities.contains(entity) {
                    entityToHandle = entity
                    break
                }
                currentEntity = entity.parent
            }
            
            if let targetEntity = entityToHandle {
                if gesture.state == .changed {
                    let translation = gesture.translation(in: arView)
                    let delta = SIMD3<Float>(Float(translation.x) * 0.001, 0, Float(-translation.y) * 0.001)
                    targetEntity.position += delta
                    
                    gesture.setTranslation(.zero, in: arView)
                }
                
                if gesture.state == .began {
                    FeedbackManager.walkStep(on: targetEntity)
                    print("Moved \(targetEntity.name) (CentralGestureManager)")
                }
            }
        }
    }
    
    deinit {
        if let arView = arView {
            arView.removeGestureRecognizer(tapGestureRecognizer)
            arView.removeGestureRecognizer(pinchGestureRecognizer)
            arView.removeGestureRecognizer(panGestureRecognizer)
        }
        print("Central gesture manager cleaned up")
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CentralGestureManager: UIGestureRecognizerDelegate {
    /** Enable simultaneous gesture recognition
     - Returns: Always returns true to allow multiple gestures
     */
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
