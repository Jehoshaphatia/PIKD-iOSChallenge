//
//  DebugUtils.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import RealityKit
import ARKit

extension Entity {
    /**
     Prints a comprehensive formatted hierarchy of the entity and its children, including entity names,
     types, components, and available animations for ModelEntity instances.
     
     - Parameter level: Indentation level for formatting (defaults to 0)
     - Parameter showComponents: Whether to include component information (defaults to true)
     */
    func printHierarchy(level: Int = 0, showComponents: Bool = true) {
        let indent = String(repeating: "  ", count: level)
        let typeName = String(describing: type(of: self))
        let displayName = name.isEmpty ? "<unnamed>" : name
        
        // Enhanced prefix for better visual hierarchy
        let prefix = level == 0 ? "1" : "2"
        
        print("\(indent)\(prefix) \(displayName) [\(typeName)]")
        
        // Show component information if requested
        if showComponents {
            printComponentInfo(indent: indent + "  ")
        }
        
        // Show ModelEntity specific information
        if let model = self as? ModelEntity {
            printModelInfo(model: model, indent: indent + "  ")
        }
        
        // Recursively print children
        for child in children {
            child.printHierarchy(level: level + 1, showComponents: showComponents)
        }
    }
    
    /**
     Prints component information for debugging purposes.
     
     - Parameter indent: The indentation string to use
     */
    private func printComponentInfo(indent: String) {
        var componentFlags: [String] = []
        
        // Check for common components
        if components[CollisionComponent.self] != nil {
            componentFlags.append("COLLISION")
        }
        if components[PhysicsBodyComponent.self] != nil {
            componentFlags.append("PHYSICS")
        }
        if components[ModelComponent.self] != nil {
            componentFlags.append("MODEL")
        }
        if components[Transform.self] != nil {
            componentFlags.append("TRANSFORM")
        }
        
        if !componentFlags.isEmpty {
            print("\(indent) Components: \(componentFlags.joined(separator: ", "))")
        }
        
        // Show position for entities with transforms
        let position = transform.translation
        print("\(indent)Position: (\(String(format: "%.2f", position.x)), \(String(format: "%.2f", position.y)), \(String(format: "%.2f", position.z)))")
    }
    
    /**
     Prints ModelEntity specific information.
     
     - Parameter model: The ModelEntity to inspect
     - Parameter indent: The indentation string to use
     */
    private func printModelInfo(model: ModelEntity, indent: String) {
        let animations = model.availableAnimations.compactMap { $0.name }
        
        if animations.isEmpty {
            print("\(indent)Animations: None")
        } else {
            print("\(indent)Animations: \(animations.joined(separator: ", "))")
        }
        
        // Show material count if available
        if let modelComponent = model.components[ModelComponent.self] {
            let materialCount = modelComponent.materials.count
            print("\(indent)Materials: \(materialCount)")
        }
    }
    
    /**
     Finds and prints all entities in the hierarchy that match a given name.
     
     - Parameter name: The name to search for
     - Parameter caseSensitive: Whether the search should be case sensitive (defaults to false)
     */
    func findAndPrintEntities(named name: String, caseSensitive: Bool = false) {
        findEntitiesRecursive(named: name, caseSensitive: caseSensitive, level: 0)
    }
    
    /**
     Recursive helper for finding entities by name.
     */
    private func findEntitiesRecursive(named searchName: String, caseSensitive: Bool, level: Int) {
        let entityName = self.name
        let matches = caseSensitive ? 
            entityName == searchName : 
            entityName.lowercased() == searchName.lowercased()
        
        if matches {
            let indent = String(repeating: "  ", count: level)
            print("\(indent)Found: \(entityName) [\(String(describing: type(of: self)))]")
        }
        
        for child in children {
            child.findEntitiesRecursive(named: searchName, caseSensitive: caseSensitive, level: level + 1)
        }
    }
    
    /**
     Prints performance-relevant information about the entity hierarchy.
     */
    func printPerformanceInfo() {
        var entityCount = 0
        var modelEntityCount = 0
        var animationCount = 0
        
        collectPerformanceStats(entityCount: &entityCount, 
                               modelEntityCount: &modelEntityCount, 
                               animationCount: &animationCount)
        
        print("Performance Summary:")
        print("Total Entities: \(entityCount)")
        print("Model Entities: \(modelEntityCount)")
        print("Total Animations: \(animationCount)")
    }
    
    /**
     Recursive helper for collecting performance statistics.
     */
    private func collectPerformanceStats(entityCount: inout Int, 
                                       modelEntityCount: inout Int, 
                                       animationCount: inout Int) {
        entityCount += 1
        
        if let model = self as? ModelEntity {
            modelEntityCount += 1
            animationCount += model.availableAnimations.count
        }
        
        for child in children {
            child.collectPerformanceStats(entityCount: &entityCount, 
                                        modelEntityCount: &modelEntityCount, 
                                        animationCount: &animationCount)
        }
    }
}

// MARK: - ARCamera.TrackingState Debug Extension

extension ARCamera.TrackingState {
    /// Human-readable description of the tracking state for debugging
    var description: String {
        switch self {
        case .normal:
            return "Normal"
        case .notAvailable:
            return "Not Available"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "Limited (Excessive Motion)"
            case .insufficientFeatures:
                return "Limited (Insufficient Features)"
            case .initializing:
                return "Limited (Initializing)"
            case .relocalizing:
                return "Limited (Relocalizing)"
            @unknown default:
                return "Limited (Unknown Reason)"
            }
        @unknown default:
            return "Unknown State"
        }
    }
}
