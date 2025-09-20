//
//  GeospatialManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import ARKit
import RealityKit
import CoreLocation
import SwiftUI
import Combine

/** GeospatialManager
 
    Core manager class for geospatial AR character placement with ARKit VPS and GPS fallback.
    Handles session management, placement coordination, and navigation state bridging.
    
    Key Features:
    - VPS-based character placement with GPS-relative fallback
    - Real-time status updates and navigation integration
    - Automatic session management and error recovery
*/
final class GeospatialManager: NSObject, ObservableObject, ARSessionDelegate, CLLocationManagerDelegate {

    private var arView: ARView!
    private var characterController: CharacterController?

    private var navigationManager = NavigationManager()
    private var performanceManager = PerformanceManager.shared
    private var cancellables = Set<AnyCancellable>()
    @Published var navigationStatus: String = "Navigation: Idle"

    private var locationManager = CLLocationManager()
    private var currentUserLocation: CLLocationCoordinate2D?
    private var deviceHeading: Double = 0

    // API rate limiting properties
    private var lastDirectionsRequest = Date.distantPast
    private let directionsRequestCooldown: TimeInterval = 1.0 // 1 second between requests

    // Target coordinate (always set by placeSoldierAt)
    private var targetCoordinate: CLLocationCoordinate2D?

    // Placement state
    private var soldierPlaced = false
    private var deferredCoordinate: CLLocationCoordinate2D?   // set when we need to retry later
    @Published var userAcknowledged = false                    // set from the alert’s Continue button

    // UX / status
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var trackingStatus: String = "Initializing…"
    @Published var inFallback: Bool = false
    @Published private(set) var availabilityResolved: Bool = false
    @Published var gpsAccuracy: CLLocationAccuracy = -1
    @Published var estimatedPositioningError: String = ""
    @Published var showManualAdjustment: Bool = false
    @Published var manualOffset: SIMD3<Float> = SIMD3<Float>(0, 0, 0)

    // Tuning for world-tracking fallback
    private let minSpawnDistance: CLLocationDistance = 1.5     // avoid zero-distance spawn (only when user is at exact target location)
    
    // GPS accuracy improvements
    private var lastKnownAccurateLocation: CLLocation?
    private var gpsAccuracyThreshold: CLLocationAccuracy = 10.0 // Only use GPS readings within 10m accuracy
    private var locationUpdateCount = 0
    private let minLocationUpdates = 3 // Require multiple GPS readings for better accuracy

    /** Initializes AR session with VPS when available, falling back to world tracking.
        - Parameter view: The `ARView` for rendering and session management
    */
    func setupAR(in view: ARView) {
        print("Setting up optimized geospatial AR...")
        
        self.arView = view
        DispatchQueue.main.async {
            self.availabilityResolved = false
        }

        // Apply performance optimizations
        performanceManager.optimizeARView(view)

        // Ensure a clean scene on each (re)setup to avoid leftover entities from a prior mode
        arView.clearAllAnchors()

        // Set up memory management notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: .performanceManagerMemoryWarning,
            object: nil
        )

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()

        navigationManager.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.navigationStatus = $0 }
            .store(in: &cancellables)

    // Prefer geospatial tracking when the device supports it; otherwise use world tracking.
    guard ARGeoTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                self.arView.clearAllAnchors()
                // Update @Published properties on main thread
                self.inFallback = true
                self.alertMessage = "This device does not support AR GeoTracking. Falling back to World Tracking."
                self.showAlert = true
                self.userAcknowledged = false
                self.availabilityResolved = true
            }
            let fallback = ARWorldTrackingConfiguration()
            fallback.planeDetection = [.horizontal]
            
            // Optimize fallback configuration for performance
            if performanceManager.performanceMetrics.isLowPowerMode {
                fallback.planeDetection = []
                print("Disabled plane detection for low power mode")
            }
            
            arView.session.delegate = self
            arView.session.run(fallback)
            return
        }

        let config = ARGeoTrackingConfiguration()
        config.planeDetection = [.horizontal]

        ARGeoTrackingConfiguration.checkAvailability { [weak self] available, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if available {
                    self.inFallback = false
                    self.arView.clearAllAnchors()
                    self.arView.session.delegate = self
                    self.arView.session.run(config)
                } else {
                    self.inFallback = true
                    let fallback = ARWorldTrackingConfiguration()
                    fallback.planeDetection = [.horizontal]
                    self.arView.clearAllAnchors()
                    self.arView.session.delegate = self
                    self.arView.session.run(fallback)

                    let desc = (error?.localizedDescription.isEmpty == false)
                        ? error!.localizedDescription
                        : "AR Geo-tracking is unavailable at this location."
                    self.alertMessage = "\(desc)\nFalling back to GPS positioning mode."
                    self.showAlert = true
                    self.userAcknowledged = false
                }
                // Mark check complete and attempt any deferred placement/navigation now
                self.availabilityResolved = true
                self.attemptDeferredPlacement()
            }
        }
    }

    // MARK: - Public API

    /// Indicates that the user acknowledged the fallback alert and allows
    /// any deferred placement/navigation to proceed.
    func userDidAcknowledgeAlert() {
        userAcknowledged = true
        attemptDeferredPlacement()
    }

    /** Places a character at specified coordinates using VPS or GPS-relative positioning.
        - Parameters:
          - lat: Target latitude in degrees
          - lon: Target longitude in degrees
          - altitude: Optional VPS placement altitude (ignored in GPS mode)
    */
    func placeSoldierAt(lat: Double, lon: Double, altitude: Double = 0) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        targetCoordinate = coordinate
        soldierPlaced = false

        // If availability is not yet resolved, defer placement to avoid spawning prematurely
        guard availabilityResolved else {
            deferredCoordinate = coordinate
            return
        }

        if inFallback {
            // Defer until BOTH: user has acknowledged AND we have a GPS fix
            deferredCoordinate = coordinate
            guard userAcknowledged else {
                print("Deferring placement: awaiting user acknowledgement.")
                return
            }
            guard currentUserLocation != nil else {
                print("Deferring placement: awaiting GPS fix.")
                return
            }
            placeSoldierUsingGPS(at: coordinate)
        } else {
            // VPS path: place immediately via ARGeoAnchor
            let geoAnchor = ARGeoAnchor(coordinate: coordinate, altitude: altitude)
            arView.session.add(anchor: geoAnchor)

            // Start navigation now (it will update live)
            navigationManager.startNavigation(to: coordinate, in: arView, inFallback: false)
        }
    }

    // MARK: - Internal helpers

    /// Attempts to perform any deferred placement and navigation actions once all
    /// prerequisites are met (availability resolved, user acknowledged, GPS fix, etc.).
    private func attemptDeferredPlacement() {
        guard let coordinate = deferredCoordinate ?? targetCoordinate else { return }
        
        if inFallback {
            // In fallback mode, only place if user acknowledged AND we have GPS
            if userAcknowledged, currentUserLocation != nil, !soldierPlaced {
                placeSoldierUsingGPS(at: coordinate)
            }
            // Don't start navigation until soldier is actually placed
            if soldierPlaced, let dest = targetCoordinate {
                navigationManager.startNavigation(to: dest, in: arView, inFallback: true)
            }
        } else {
            // VPS mode - place immediately via ARGeoAnchor
            if !soldierPlaced {
                let geoAnchor = ARGeoAnchor(coordinate: coordinate, altitude: GeoConfig.defaultAltitude)
                arView.session.add(anchor: geoAnchor)
            }
            // Start navigation immediately in VPS mode
            if let dest = targetCoordinate {
                navigationManager.startNavigation(to: dest, in: arView, inFallback: false)
            }
        }
    }

    /** Places character using GPS-relative positioning with distance clamping.
        - Parameter coordinate: Target location in world space
    */
    private func placeSoldierUsingGPS(at coordinate: CLLocationCoordinate2D) {
        guard let userLocation = currentUserLocation, let arView = arView, !soldierPlaced else {
            if soldierPlaced { return }
            print("Cannot place soldier using GPS yet (missing location or ARView).")
            return
        }

        // Calculate actual distance to target
        let actualDistance = userLocation.distance(from: coordinate)
        print("Distance to target: \(String(format: "%.1f", actualDistance))m")
        print("User location: \(userLocation.latitude), \(userLocation.longitude)")
        print("Target location: \(coordinate.latitude), \(coordinate.longitude)")

        // Compute relative AR position from user to target
        var worldPos = coordinate.toARPosition(from: userLocation, heading: deviceHeading)
        
        // Apply manual offset if user has adjusted position
        worldPos += manualOffset
        
        let planar = hypot(Double(worldPos.x), Double(worldPos.z))
        
        // Only handle the case where we're too close to the target (distance ~ 0)
        // This prevents the soldier from spawning inside the user
        if planar < minSpawnDistance {
            let cam = arView.cameraTransform
            let fwd = simd_normalize(SIMD3<Float>(-cam.matrix.columns.2.x,
                                                  -cam.matrix.columns.2.y,
                                                  -cam.matrix.columns.2.z))
            worldPos = cam.translation + fwd * Float(minSpawnDistance)
            print("Target too close (\(String(format: "%.1f", planar))m), placing \(minSpawnDistance)m in front of camera")
        } else {
            print("Placing soldier at calculated GPS position: \(String(format: "%.1f", planar))m away")
        }
        
        // REMOVED: Distance clamping for far targets - this was preventing proper GPS positioning
        // The soldier should be placed at the exact GPS coordinates regardless of distance

        // Clear any prior GPS soldier
        for anchor in arView.scene.anchors {
            if anchor.children.contains(where: { $0.name == "GPSSoldier" }) {
                arView.scene.removeAnchor(anchor)
            }
        }

        let anchorEntity = AnchorEntity(world: worldPos)

        if let root = try? Entity.load(named: "toy_drummer.usdz"),
           let soldier = root.findFirstModelEntity() {
            soldier.scale = .init(repeating: 0.2)
            soldier.name = "GPSSoldier"
            anchorEntity.addChild(soldier)
            arView.scene.addAnchor(anchorEntity)

            self.characterController = CharacterController(arView: arView, character: soldier)
            soldierPlaced = true
            print("Placed soldier (GPS fallback) at ~\(Int(planar))m relative distance.")
            
            // Debug: Print scene hierarchy after GPS soldier placement
            #if DEBUG
            print("GPS Soldier placed - Scene hierarchy:")
            anchorEntity.printHierarchy()
            #endif
        } else {
            // Fallback sphere
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.1),
                materials: [SimpleMaterial(color: .orange, isMetallic: false)]
            )
            sphere.name = "GPSSoldier"
            sphere.components[CollisionComponent.self] = CollisionComponent(shapes: [.generateSphere(radius: 0.1)])
            anchorEntity.addChild(sphere)
            arView.scene.addAnchor(anchorEntity)
            soldierPlaced = true
        }
    }

    // MARK: - ARSessionDelegate (unchanged VPS path)
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let arView = arView else { return }
        // Ignore VPS geo anchors if we're in fallback or availability isn't settled yet
        let allowVPSAnchors = (!inFallback) && availabilityResolved
        for anchor in anchors {
            guard let geo = anchor as? ARGeoAnchor, allowVPSAnchors else { continue }
            let anchorEntity = AnchorEntity()
            anchorEntity.transform = Transform(matrix: geo.transform)

            if let root = try? Entity.load(named: "toy_drummer.usdz"),
               let soldier = root.findFirstModelEntity() {
                soldier.scale = .init(repeating: 0.2)
                anchorEntity.addChild(soldier)
                arView.scene.addAnchor(anchorEntity)
                self.characterController = CharacterController(arView: arView, character: soldier)
                soldierPlaced = true
                
                // Debug: Print scene hierarchy after VPS soldier placement
                #if DEBUG
                print(" VPS Soldier placed - Scene hierarchy:")
                anchorEntity.printHierarchy()
                #endif
            } else {
                let sphere = ModelEntity(mesh: .generateSphere(radius: 0.1),
                                         materials: [SimpleMaterial(color: .red, isMetallic: false)])
                sphere.components[CollisionComponent.self] = CollisionComponent(shapes: [.generateSphere(radius: 0.1)])
                anchorEntity.addChild(sphere)
                arView.scene.addAnchor(anchorEntity)
                soldierPlaced = true
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable: trackingStatus = "Tracking: Unavailable"
        case .normal:       trackingStatus = "Tracking: Ready"
        case .limited(let reason):
            switch reason {
            case .initializing:          trackingStatus = "Tracking: Initializing…"
            case .excessiveMotion:       trackingStatus = "Tracking: Limited (Excessive Motion)"
            case .insufficientFeatures:  trackingStatus = "Tracking: Limited (Low Features)"
            case .relocalizing:          trackingStatus = "Tracking: Relocalizing…"
            @unknown default:            trackingStatus = "Tracking: Limited (Unknown)"
            }
        }
    }

    /** Restarts AR session with clean state while preserving configuration. */
    func restartSession() {
        guard let arView = arView else { return }
        arView.session.pause()
        arView.clearAllAnchors()
        setupAR(in: arView)
    }
    
    /** Returns AR session for UI components like coaching overlays. */
    func getARSession() -> ARSession? {
        return arView?.session
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        // Only use GPS readings with good accuracy
        guard loc.horizontalAccuracy <= gpsAccuracyThreshold && loc.horizontalAccuracy > 0 else {
            print("GPS accuracy too low: \(loc.horizontalAccuracy)m, waiting for better signal...")
            return
        }
        
        locationUpdateCount += 1
        currentUserLocation = loc.coordinate
        
        // Store the most accurate location we've received
        if lastKnownAccurateLocation == nil || loc.horizontalAccuracy < lastKnownAccurateLocation!.horizontalAccuracy {
            lastKnownAccurateLocation = loc
        }
        
        print("GPS Update #\(locationUpdateCount): Accuracy: \(String(format: "%.1f", loc.horizontalAccuracy))m, Location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        
        // Update UI with accuracy information
        DispatchQueue.main.async {
            self.gpsAccuracy = loc.horizontalAccuracy
            self.updatePositioningErrorEstimate()
        }
        
        // If we were waiting for a fix, try to place now (but only after multiple good readings)
        if locationUpdateCount >= minLocationUpdates {
            attemptDeferredPlacement()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        deviceHeading = newHeading.trueHeading * .pi / 180.0
        
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    // MARK: - Debug Methods
    #if DEBUG
    /// Prints the complete scene hierarchy for debugging
    func printSceneHierarchy() {
        guard let arView = arView else {
            print("ARView not available for hierarchy debugging")
            return
        }
        
        print("\n === GEOSPATIAL SCENE HIERARCHY ===")
        print("AR Scene Overview:")
        
        if arView.scene.anchors.isEmpty {
            print("No anchors in scene")
        } else {
            for (index, anchor) in arView.scene.anchors.enumerated() {
                print("\n Anchor \(index + 1)/\(arView.scene.anchors.count):")
                anchor.printHierarchy()
            }
        }
        
        // Show soldier-specific information
        if let soldier = arView.scene.findEntity(named: "GPSSoldier") {
            print("\n Found GPS Soldier:")
            soldier.printHierarchy(showComponents: true)
        } else {
            print("\n GPS Soldier not found in scene")
        }
        
        print("=== END HIERARCHY ===\n")
    }
    
    // MARK: - Memory Management
    
    @objc private func handleMemoryWarning() {
        print("Memory warning in Geospatial Manager - performing cleanup...")
        
        // Clean up navigation requests
        navigationManager.cancelCurrentNavigation()
        
        // Perform AR cleanup if available
        if let arView = arView {
            performanceManager.performMemoryCleanup(arView)
        }
        
        print("Geospatial memory cleanup complete")
    }
    
    // MARK: - Rate Limited API Calls
    
    private func canMakeDirectionsRequest() -> Bool {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastDirectionsRequest)
        return timeSinceLastRequest >= directionsRequestCooldown
    }
    
    private func recordDirectionsRequest() {
        lastDirectionsRequest = Date()
    }
    
    // MARK: - GPS Accuracy Estimation
    
    private func updatePositioningErrorEstimate() {
        if inFallback {
            if gpsAccuracy > 0 {
                let estimatedError = gpsAccuracy * 1.5 // Conservative estimate: GPS error + AR tracking error
                estimatedPositioningError = "GPS positioning: ±\(String(format: "%.0f", estimatedError))m accuracy"
            } else {
                estimatedPositioningError = "GPS positioning: Waiting for signal..."
            }
        } else {
            estimatedPositioningError = "VPS positioning: Sub-meter accuracy"
        }
    }
    
    // MARK: - Location Utilities
    
    /// Creates a test location near the user's current position for testing purposes
    func createNearbyTestLocation(offsetMeters: Double = 50) -> CLLocationCoordinate2D? {
        guard let userLocation = currentUserLocation else {
            print("Cannot create test location: no user location available")
            return nil
        }
        
        // Create a location 50 meters north of current position
        let offsetLatitude = offsetMeters / 111000.0 // Rough conversion: 1 degree ≈ 111km
        let testLocation = CLLocationCoordinate2D(
            latitude: userLocation.latitude + offsetLatitude,
            longitude: userLocation.longitude
        )
        
        print("Created test location \(offsetMeters)m north of current position:")
        print("Current: \(userLocation.latitude), \(userLocation.longitude)")
        print("Test: \(testLocation.latitude), \(testLocation.longitude)")
        
        return testLocation
    }
    
    /// Places soldier at a nearby test location for development/testing
    func placeSoldierAtNearbyTestLocation() {
        guard let testLocation = createNearbyTestLocation() else { return }
        placeSoldierAt(lat: testLocation.latitude, lon: testLocation.longitude)
    }
    
    // MARK: - Manual Position Adjustment
    
    /// Allows user to manually adjust the soldier's position for better accuracy
    func adjustSoldierPosition(offset: SIMD3<Float>) {
        manualOffset += offset
        
        // If soldier is already placed, update its position
        if soldierPlaced, let coordinate = targetCoordinate {
            // Remove current soldier
            for anchor in arView.scene.anchors {
                if anchor.children.contains(where: { $0.name == "GPSSoldier" }) {
                    arView.scene.removeAnchor(anchor)
                }
            }
            soldierPlaced = false
            
            // Re-place with new offset
            if inFallback {
                placeSoldierUsingGPS(at: coordinate)
            }
        }
        
        print("Manual adjustment applied: \(offset), total offset: \(manualOffset)")
    }
    
    /// Resets manual position adjustments
    func resetManualAdjustment() {
        manualOffset = SIMD3<Float>(0, 0, 0)
        
        // Re-place soldier with original position
        if soldierPlaced, let coordinate = targetCoordinate {
            for anchor in arView.scene.anchors {
                if anchor.children.contains(where: { $0.name == "GPSSoldier" }) {
                    arView.scene.removeAnchor(anchor)
                }
            }
            soldierPlaced = false
            
            if inFallback {
                placeSoldierUsingGPS(at: coordinate)
            }
        }
        
        print("Manual adjustment reset")
    }
    
    /// Prints performance information about the scene
    func printPerformanceInfo() {
        guard let arView = arView else {
            print("ARView not available for performance debugging")
            return
        }
        
        print("\n === GEOSPATIAL PERFORMANCE INFO ===")
        
        // Overall scene stats
        let anchorCount = arView.scene.anchors.count
        print("Total Anchors: \(anchorCount)")
        
        // Analyze each anchor
        for anchor in arView.scene.anchors {
            print("\n Anchor Performance Analysis:")
            anchor.printPerformanceInfo()
        }
        
        // AR session information
        let session = arView.session
        print("\n AR Session Status:")
        print("  Tracking State: \(session.currentFrame?.camera.trackingState.description ?? "Unknown")")
        print("  Configuration: \(type(of: session.configuration))")
        
        // Location information
        if let location = currentUserLocation {
            print("\n Location Info:")
            print("  Current Location: \(location.latitude), \(location.longitude)")
            print("  Heading: \(String(format: "%.1f", deviceHeading * 180.0 / .pi))°")
            if let target = targetCoordinate {
                print("  Target Location: \(target.latitude), \(target.longitude)")
            }
        }
        
        print("=== END PERFORMANCE INFO ===\n")
    }
    #endif
}
