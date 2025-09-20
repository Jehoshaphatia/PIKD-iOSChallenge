//
//  NavigationManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import ARKit
import RealityKit
import MapKit
import CoreLocation

/** Manages AR navigation with dynamic route calculation and waypoint visualization.
    Integrates MapKit routing with RealityKit waypoints, supporting both geospatial 
    and world-space anchoring modes.
 */
final class NavigationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private var locationManager = CLLocationManager()
    private weak var arView: ARView?

    private var currentRoute: MKRoute?
    private var target: CLLocationCoordinate2D?
    private var waypointAnchors: [AnchorEntity] = []

    @Published var statusMessage: String = "Navigation: Idle"

    // Indicates whether fallback mode is active
    var inFallback: Bool = false
    var currentUserLocation: CLLocationCoordinate2D?
    var deviceHeading: Double = 0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    /** Initiates navigation to a target location
        - Parameters:
            - target: Destination coordinate
            - arView: AR view for visualization
            - inFallback: Use world-space anchoring if true
     */
    func startNavigation(to target: CLLocationCoordinate2D, in arView: ARView, inFallback: Bool = false) {
        self.arView = arView
        self.target = target
        self.inFallback = inFallback
        statusMessage = "Navigation: Calculating route..."
        recalculateRoute()
    }

    // MARK: - Location Updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last,
              let route = currentRoute,
              let _ = target else { return }

        currentUserLocation = userLocation.coordinate

        // Check if the user has strayed more than 20 meters from the route.
        let distance = route.distance(to: userLocation.coordinate)

        if distance > 20 {
            statusMessage = "Navigation: Re-routing..."
            recalculateRoute()
        }
    }


    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        deviceHeading = newHeading.trueHeading * .pi / 180.0
    }

    // MARK: - Routing

    /** Updates route and AR waypoints based on current location */
    private func recalculateRoute() {
        guard let userLocation = locationManager.location?.coordinate,
              let target = target,
              let arView = arView else {
            statusMessage = "Navigation: Missing data"
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: target))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let route = response?.routes.first else {
                if let error = error { self?.statusMessage = "Navigation error: \(error.localizedDescription)" }
                return
            }
            self.currentRoute = route
            self.clearWaypoints()
            self.addWaypoints(to: arView, polyline: route.polyline)
        }
    }

    // MARK: - Waypoint Helpers

    /** Creates color-coded AR waypoints (green=start, red=end, blue=intermediate)
        - Parameters:
            - arView: Target AR view
            - polyline: Route polyline for waypoint generation
     */
    private func addWaypoints(to arView: ARView, polyline: MKPolyline) {
        let coords = polyline.coordinates()
        statusMessage = "Navigation: \(coords.count) waypoints loaded"

        for (index, coord) in coords.enumerated() {
            var color: UIColor = .blue
            if index == 0 { color = .green }
            else if index == coords.count - 1 { color = .red }

            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.05),
                materials: [SimpleMaterial(color: color, isMetallic: false)]
            )
            if let pulse = AnimationResource.makePulseAnimation() {
                sphere.playAnimation(pulse.repeat())
            }

            var anchorEntity: AnchorEntity
            if inFallback, let userLocation = currentUserLocation {
                let worldPos = coord.toARPosition(from: userLocation, heading: deviceHeading)
                anchorEntity = AnchorEntity(world: worldPos)
            } else {
                let geoAnchor = ARGeoAnchor(coordinate: coord, altitude: GeoConfig.defaultAltitude)
                arView.session.add(anchor: geoAnchor)

                let entity = AnchorEntity()
                entity.transform = Transform(matrix: geoAnchor.transform)
                anchorEntity = entity
            }

            anchorEntity.addChild(sphere)
            arView.scene.addAnchor(anchorEntity)
            waypointAnchors.append(anchorEntity)
        }
    }

    /** Cancels current navigation and clears all waypoints */
    func cancelCurrentNavigation() {
        target = nil
        currentRoute = nil
        statusMessage = "Navigation: Cancelled"
        clearWaypoints()
    }

    private func clearWaypoints() {
        for anchor in waypointAnchors {
            arView?.scene.removeAnchor(anchor)
        }
        waypointAnchors.removeAll()
    }
}
