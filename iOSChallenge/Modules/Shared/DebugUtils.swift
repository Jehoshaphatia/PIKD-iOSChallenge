//
//  DebugUtils.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import RealityKit

extension Entity {
    /**
     Prints a formatted hierarchy of the entity and its children, including entity names,
     types, and available animations for ModelEntity instances.
     
     - Parameter level: Indentation level for formatting (defaults to 0)
     */
    func printHierarchy(level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        let typeName = String(describing: type(of: self))
        
        print("\(indent)Entity: \(name.isEmpty ? "(unnamed)" : name) [\(typeName)]")
        
        if let model = self as? ModelEntity {
            let anims: [String] = model.availableAnimations.compactMap { $0.name }
            
            if anims.isEmpty {
                print("\(indent)  No animations")
            } else {
                print("\(indent)  Animations: \(anims.joined(separator: ", "))")
            }
        }
        
        for child in children {
            child.printHierarchy(level: level + 1)
        }
    }
}
