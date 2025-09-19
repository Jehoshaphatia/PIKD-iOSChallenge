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
    private var cancellables = Set<AnyCancellable>()
    @Published var navigationStatus: String = "Navigation: Idle"

    private var locationManager = CLLocationManager()
    private var currentUserLocation: CLLocationCoordinate2D?
    private var deviceHeading: Double = 0

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

    // Tuning for world-tracking fallback
    private let minSpawnDistance: CLLocationDistance = 1.5     // avoid zero-distance spawn
    private let maxSpawnDistance: CLLocationDistance = 30.0    // keep within a comfortable AR range

    /** Initializes AR session with VPS when available, falling back to world tracking.
        - Parameter view: The `ARView` for rendering and session management
    */
    func setupAR(in view: ARView) {
        self.arView = view
        availabilityResolved = false

        // Ensure a clean scene on each (re)setup to avoid leftover entities from a prior mode
        arView.clearAllAnchors()

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
                self.inFallback = true
                self.alertMessage = "This device does not support AR GeoTracking. Falling back to World Tracking."
                self.showAlert = true
                self.userAcknowledged = false
                self.availabilityResolved = true
                self.arView.clearAllAnchors()
            }
            let fallback = ARWorldTrackingConfiguration()
            fallback.planeDetection = [.horizontal]
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

        // Compute relative AR position from user to target
        var worldPos = coordinate.toARPosition(from: userLocation, heading: deviceHeading)
        var planar = hypot(Double(worldPos.x), Double(worldPos.z))

        // If we’re effectively at the target (distance ~ 0), push it slightly forward
        if planar < minSpawnDistance {
            let cam = arView.cameraTransform
            let fwd = simd_normalize(SIMD3<Float>(-cam.matrix.columns.2.x,
                                                  -cam.matrix.columns.2.y,
                                                  -cam.matrix.columns.2.z))
            worldPos = cam.translation + fwd * Float(minSpawnDistance)
        } else if planar > maxSpawnDistance {
            // Clamp to a reasonable draw distance in world-tracking
            let dir = simd_normalize(SIMD3<Float>(worldPos.x, 0, worldPos.z))
            worldPos = dir * Float(maxSpawnDistance)
            planar = Double(maxSpawnDistance)
        }

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
        currentUserLocation = loc.coordinate
        // If we were waiting for a fix, try to place now
        attemptDeferredPlacement()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        deviceHeading = newHeading.trueHeading * .pi / 180.0
        
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
}
