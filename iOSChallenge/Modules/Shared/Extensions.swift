//
//  Extensions.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import RealityKit
import UIKit
import ImageIO
import MapKit

// MARK: - Entity Extensions

extension Entity {
    /** 
     Recursively finds the first ModelEntity in the hierarchy and ensures proper collision detection.
     
     - Returns: The first ModelEntity found with collision component, or nil if none exists.
     - Note: Automatically generates collision shapes from mesh or falls back to bounding box with 5cm minimum size.
     */
    func findFirstModelEntity() -> ModelEntity? {
        if let me = self as? ModelEntity {
            if me.components[CollisionComponent.self] == nil {
                if me.model?.mesh != nil {
                    me.generateCollisionShapes(recursive: false)
                }
                
                if me.components[CollisionComponent.self] == nil {
                    let extents = me.visualBounds(relativeTo: nil).extents
                    let safeExtents = SIMD3<Float>(
                        max(extents.x, 0.05),
                        max(extents.y, 0.05),
                        max(extents.z, 0.05)
                    )
                    me.components[CollisionComponent.self] = CollisionComponent(
                        shapes: [.generateBox(size: safeExtents)]
                    )
                    print("Warning: Used fallback box collision for ModelEntity: \(me.name) (size: \(safeExtents))")
                } else {
                    print("Generated collision shapes for ModelEntity: \(me.name)")
                }
            }
            return me
        }
        for child in children {
            if let found = child.findFirstModelEntity() { return found }
        }
        return nil
    }
    
    /** 
     Ensures all ModelEntities in the hierarchy have proper collision components.
     Applies collision detection recursively through the entire entity hierarchy.
     */
    func ensureAllModelEntitiesHaveCollision() {
        if let me = self as? ModelEntity {
            if me.components[CollisionComponent.self] == nil {
                if me.model?.mesh != nil {
                    me.generateCollisionShapes(recursive: false)
                }
                
                if me.components[CollisionComponent.self] == nil {
                    let extents = me.visualBounds(relativeTo: nil).extents
                    let safeExtents = SIMD3<Float>(
                        max(extents.x, 0.05),
                        max(extents.y, 0.05),
                        max(extents.z, 0.05)
                    )
                    me.components[CollisionComponent.self] = CollisionComponent(
                        shapes: [.generateBox(size: safeExtents)]
                    )
                    print("Warning: Used fallback box collision for ModelEntity: \(me.name) (size: \(safeExtents))")
                } else {
                    print("Generated collision shapes for ModelEntity: \(me.name)")
                }
            }
        }
        
                // Recursively apply to all children
        for child in children {
            child.ensureAllModelEntitiesHaveCollision()
        }
    }
}

// MARK: - RealityKit Transform Extensions
extension Transform {
    /** Returns the translation component of the transform matrix as SIMD3<Float>. */
    var translation: SIMD3<Float> {
        return SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
    }
}

// MARK: - simd_float4x4 Extensions
extension simd_float4x4 {
    /** Returns the upper-left 3x3 portion of the 4x4 matrix. */
    var upperLeft: simd_float3x3 {
        return simd_float3x3(
            SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z),
            SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z),
            SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z)
        )
    }
}

// MARK: - CGImagePropertyOrientation Extensions

extension CGImagePropertyOrientation {
    /** Initializes CGImagePropertyOrientation from UIDeviceOrientation for vision processing. */
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown: self = .left
        case .landscapeLeft: self = .up
        case .landscapeRight: self = .down
        default: self = .right
        }
    }
}

// MARK: - MKPolyline Extensions
extension MKPolyline {
    /** Returns an array of coordinates representing the polyline's path. */
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid,
                                              count: self.pointCount)
        self.getCoordinates(&coords, range: NSRange(location: 0, length: self.pointCount))
        return coords
    }
}

// MARK: - MKRoute Extensions
extension MKRoute {
    /** 
     Calculates the minimum distance from a coordinate to any point on the route.
     
     - Parameter coord: The coordinate to measure distance from
     - Returns: The shortest distance in meters from the coordinate to the route
     */
    func distance(to coord: CLLocationCoordinate2D) -> CLLocationDistance {
        var minDist = CLLocationDistance(Double.greatestFiniteMagnitude)
        let polyCoords = polyline.coordinates()
        for i in 0..<polyCoords.count-1 {
            let segmentStart = MKMapPoint(polyCoords[i])
            let segmentEnd = MKMapPoint(polyCoords[i+1])
            let userPoint = MKMapPoint(coord)
            let dist = userPoint.distance(toSegment: (segmentStart, segmentEnd))
            minDist = min(minDist, dist)
        }
        return minDist
    }
}

// MARK: - MKMapPoint Extensions

extension MKMapPoint {
    /** 
     Calculates the perpendicular distance from this point to a line segment.
     
     - Parameter segment: Tuple of two MKMapPoints defining the line segment
     - Returns: The shortest distance from the point to the line segment
     */
    func distance(toSegment segment: (MKMapPoint, MKMapPoint)) -> CLLocationDistance {
        let dx = segment.1.x - segment.0.x
        let dy = segment.1.y - segment.0.y
        if dx == 0 && dy == 0 {
            return self.distance(to: segment.0)
        }
        let t = max(0, min(1, ((self.x - segment.0.x) * dx + (self.y - segment.0.y) * dy) / (dx*dx + dy*dy)))
        let projX = segment.0.x + t * dx
        let projY = segment.0.y + t * dy
        return hypot(self.x - projX, self.y - projY)
    }
}

// MARK: - CLLocationCoordinate2D Extensions
extension CLLocationCoordinate2D {
    /** Calculates the great-circle distance in meters to another coordinate. */
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
    
    /** Calculates the initial bearing in radians to another coordinate. */
    func bearing(to coordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = self.latitude * .pi / 180.0
        let lat2 = coordinate.latitude * .pi / 180.0
        let deltaLon = (coordinate.longitude - self.longitude) * .pi / 180.0
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        return atan2(y, x)
    }
    
    /** 
     Converts GPS coordinates to AR world position relative to user location.
     
     - Parameters:
       - userLocation: The current user's GPS coordinates
       - heading: The user's compass heading in radians (default: 0)
     - Returns: SIMD3<Float> position in AR world space (meters)
     */
    func toARPosition(from userLocation: CLLocationCoordinate2D, heading: Double = 0) -> SIMD3<Float> {
        let distance = userLocation.distance(from: self)
        let bearing = userLocation.bearing(to: self)
        let adjustedBearing = bearing - heading
        
        let x = Float(distance * sin(adjustedBearing))
        let z = -Float(distance * cos(adjustedBearing))
        
        return SIMD3<Float>(x, 0, z)
    }
}

// MARK: - CLLocation Extensions

extension CLLocation {
    /** Returns the initial bearing in radians to another location. */
    func bearing(to location: CLLocation) -> Double {
        return self.coordinate.bearing(to: location.coordinate)
    }
}

// MARK: - AnimationResource Extensions
extension AnimationResource {
    /** 
     Creates a pulsing scale animation resource.
     
     Generates a smooth 0.8s scale animation from 1.0 to 1.3. Falls back to a no-op animation
     if generation fails.
     
     - Returns: An AnimationResource for the pulse effect, or nil if generation fails completely
     */
    static func makePulseAnimation() -> AnimationResource? {
        let from = Transform(scale: SIMD3<Float>(repeating: 1.0))
        let to   = Transform(scale: SIMD3<Float>(repeating: 1.3))

        let animation = FromToByAnimation<Transform>(
            name: "pulse",
            from: from,
            to: to,
            duration: 0.8,
            bindTarget: .transform
        )

        do {
            return try AnimationResource.generate(with: animation)
        } catch {
            print("Failed to generate pulse animation: \(error.localizedDescription)")

            
            let noop = FromToByAnimation<Transform>(
                name: "noop",
                from: Transform(scale: SIMD3<Float>(repeating: 1.0)),
                to:   Transform(scale: SIMD3<Float>(repeating: 1.0)),
                duration: 0.01,
                bindTarget: .transform
            )
            return try? AnimationResource.generate(with: noop)
        }
    }
}

// MARK: - ARView Extensions
extension ARView {
    /** Removes all anchors from the current AR scene. */
    func clearAllAnchors() {
        for anchor in scene.anchors { scene.removeAnchor(anchor) }
    }
}


