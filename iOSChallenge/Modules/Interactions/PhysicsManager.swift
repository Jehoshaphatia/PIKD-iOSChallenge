//
//  PhysicsManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import RealityKit

/** Manages physics and collision components for interactive RealityKit entities in the AR scene. */
enum PhysicsManager {
    
    /**
     Configures an entity with physics and collision components.
     
     - Parameters:
        - entity: Target model entity
        - mode: Physics body mode (defaults to kinematic)
     */
    static func addPhysics(to entity: ModelEntity, mode: PhysicsBodyMode = .kinematic) {
        entity.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
            massProperties: .default,
            material: .default,
            mode: mode
        )
        
        entity.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateBox(size: [0.2, 0.2, 0.2])]
        )
    }
    
    /**
     Applies a physics impulse to move an entity.
     
     - Parameters:
        - entity: Target model entity
        - impulse: 3D vector force to apply
     */
    static func applyImpulse(_ entity: ModelEntity, impulse: SIMD3<Float>) {
        entity.applyLinearImpulse(impulse, relativeTo: nil)
    }
}
