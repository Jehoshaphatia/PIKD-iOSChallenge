//  
//  ObjectDetectionManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import Vision
import CoreML
import UIKit
import ARKit
import RealityKit
import SwiftUI

/**
A single object detection result produced by Vision.
*/
struct DetectionResult {
    /// The identifier of the detected object.
    let label: String
    /// The model's confidence for the label in the range [0, 1].
    let confidence: VNConfidence
    /// The normalized bounding box in image coordinates (origin at bottom-left).
    let boundingBox: CGRect
}

/**
Manages real-time object detection and AR object placement.
*/
final class ObjectDetectionManager: NSObject, ObservableObject, ARSessionDelegate {
    private var model: VNCoreMLModel?
    private var arView: ARView?
    
    // MARK: - Published UI State
    /// High-level tracking status derived from ARKit camera state.
    @Published var trackingStatus: String = "Initializing…"
    /// Human-readable detection status for display in UI.
    @Published var detectionStatus: String = "No detection yet"
    /// Indicates whether the detection timer is running.
    @Published var isDetectionRunning: Bool = false
    
    // MARK: - Frame Buffers
    private var currentBuffer: CVPixelBuffer?
    private var currentCamera: ARCamera?
    private var isProcessingFrame: Bool = false
    
    // MARK: - Queues
    private let visionQueue = DispatchQueue(label: "com.objectdetection.visionQueue")
    private var detectionTimer: DispatchSourceTimer?
    
    // MARK: - Spawn Control
    private var lastSpawnTime = Date()
    private var lastSpawnedLabel = ""
    private var lastSpawnPosition = SIMD3<Float>(0, 0, 0)
    private let spawnCooldown: TimeInterval = 3.0
    private let minimumDistance: Float = 0.8
    
    // MARK: - Detection Thresholds
    private let baseConfidenceThreshold: VNConfidence = 0.65
    private let stableDetectionRequired = 1
    private var consecutiveDetections: [String: Int] = [:]
    
    // MARK: - Cleanup State
    private var spawnedAnchors: [AnchorEntity] = []
    private let maxObjectsInScene = 5
    
    // Cache for preloaded models.
    private var modelCache: [String: Entity] = [:]
    
    // Keep the central gesture manager alive for entity interactions.
    private var centralGestureManager: CentralGestureManager?
    
    // Track spawned entities by label to prevent duplicates.
    private var spawnedEntities: [String: Entity] = [:]
    
    // Enhanced duplicate prevention with expiry.
    private var entitySpawnHistory: [String: Date] = [:]
    private let entityExpiryTime: TimeInterval = 10.0

    override init() {
        super.init()
        if let mlModel = try? yolov8n(configuration: MLModelConfiguration()).model {
            self.model = try? VNCoreMLModel(for: mlModel)
        }
        
        preloadModels()
    }
    
    // MARK: - Setup
    /// Configures ARKit on the provided ARView and starts the detection timer.
    /// - Parameter view: The ARView used for session management and rendering.
    func setupAR(in view: ARView) {
        self.arView = view
        
        centralGestureManager = CentralGestureManager(arView: view)
        
        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        config.planeDetection = [.horizontal, .vertical]
        
        view.session.delegate = self
        view.session.run(config)
        
        startDetectionTimer()
    }
    
    /// Returns the configured ARView instance, if any.
    func arViewInstance() -> ARView? { arView }
    
    // MARK: - Detection Status Updates
    /// Updates the human-readable detection status on the main queue.
    /// - Parameter status: The status text to display.
    private func updateDetectionStatus(_ status: String) {
        DispatchQueue.main.async {
            self.detectionStatus = status
        }
    }

    // MARK: - Timer Control
    /// Starts the periodic detection timer, if not already running.
    func startDetectionTimer() {
        if detectionTimer != nil {
            print("Detection timer already running, skipping start")
            return
        }
        
        let timer = DispatchSource.makeTimerSource(queue: visionQueue)
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.runDetectionTick()
        }
        timer.resume()
        detectionTimer = timer
        
        DispatchQueue.main.async {
            self.isDetectionRunning = true
        }
        print("Detection timer started")
    }

    /// Stops the detection timer if it is running.
    func stopDetectionTimer() {
        detectionTimer?.cancel()
        detectionTimer = nil
        
        DispatchQueue.main.async {
            self.isDetectionRunning = false
        }
        print("Detection timer stopped")
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            switch camera.trackingState {
            case .notAvailable: self.trackingStatus = "Detection: Unavailable"
            case .normal:       self.trackingStatus = "Detection: Ready ✅"
            case .limited(let reason):
                switch reason {
                case .initializing: self.trackingStatus = "Detection: Initializing…"
                case .excessiveMotion: self.trackingStatus = "Detection: Limited (Excessive Motion)"
                case .insufficientFeatures: self.trackingStatus = "Detection: Limited (Low Features)"
                case .relocalizing: self.trackingStatus = "Detection: Relocalizing…"
                @unknown default: self.trackingStatus = "Detection: Limited (Unknown)"
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        currentCamera = frame.camera
        
        if !isProcessingFrame && currentBuffer == nil {
            currentBuffer = frame.capturedImage
        } else {
            currentBuffer = nil
        }
    }
    
    // MARK: - Detection Tick
    /// Processes the most recent captured frame and schedules detection.
    private func runDetectionTick() {
        guard let pixelBuffer = currentBuffer,
              let camera = currentCamera,
              !isProcessingFrame else { 
            currentBuffer = nil
            return 
        }
        
        cleanupExpiredEntities()
        
        isProcessingFrame = true
        let bufferToProcess = currentBuffer
        currentBuffer = nil
        
        guard let safeBuffer = bufferToProcess else {
            isProcessingFrame = false
            return
        }
        
        let orientation = CGImagePropertyOrientation.init(UIDevice.current.orientation)
        
        detectObjects(in: safeBuffer, orientation: orientation) { [weak self] results in
            guard let self = self else { return }
            
            self.isProcessingFrame = false
            self.currentBuffer = nil
            
            guard let best = results.max(by: { $0.confidence < $1.confidence }),
                  best.confidence > baseConfidenceThreshold else {
                self.updateDetectionStatus("No confident detection (\(results.count) candidates)")
                self.consecutiveDetections.removeAll()
                return
            }
            
            let detectionCount = (self.consecutiveDetections[best.label] ?? 0) + 1
            self.consecutiveDetections[best.label] = detectionCount
            
            for key in self.consecutiveDetections.keys where key != best.label {
                self.consecutiveDetections.removeValue(forKey: key)
            }
            
            if detectionCount >= self.stableDetectionRequired {
                self.updateDetectionStatus("Stable detection: \(best.label) (\(Int(best.confidence * 100))%)")
                self.placeAsset(for: best, orientation: orientation, camera: camera)
                self.consecutiveDetections.removeValue(forKey: best.label)
            } else {
                self.updateDetectionStatus("Detecting \(best.label) (\(detectionCount)/\(self.stableDetectionRequired)) - \(Int(best.confidence * 100))%")
            }
        }
    }
    
    // MARK: - Vision
    /// Runs Vision Core ML request on pixel buffer.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Captured image buffer from ARKit.
    ///   - orientation: Image orientation for Vision processing.
    ///   - completion: Handler with detection results.
    func detectObjects(in pixelBuffer: CVPixelBuffer,
                       orientation: CGImagePropertyOrientation,
                       completion: @escaping ([DetectionResult]) -> Void) {
        guard let model = model else { 
            completion([])
            return 
        }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard self != nil else { 
                completion([])
                return 
            }
            
            let results = (request.results as? [VNRecognizedObjectObservation]) ?? []
            let mapped = results.compactMap { obs -> DetectionResult? in
                guard let top = obs.labels.first else { return nil }
                return DetectionResult(label: top.identifier,
                                       confidence: top.confidence,
                                       boundingBox: obs.boundingBox)
            }
            
            DispatchQueue.main.async {
                completion(mapped)
            }
        }
        
        request.imageCropAndScaleOption = .scaleFill
        
        visionQueue.async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    // MARK: - Duplicate Prevention
    /**
    Returns true if an entity for the given label is present and not expired.
    If an entity exists but has exceeded its expiry time, it is removed and
    the method returns false.
    - Parameter label: The detection label.
    - Returns: Whether spawning should be blocked for the label.
    */
    private func alreadySpawned(_ label: String) -> Bool {
        let now = Date()
        let labelKey = label.lowercased()
        
        cleanupExpiredEntities()
        
        if let entity = spawnedEntities[labelKey], entity.scene != nil {
            if let lastSpawn = entitySpawnHistory[labelKey],
               now.timeIntervalSince(lastSpawn) < entityExpiryTime {
                return true
            } else {
                removeEntityFromScene(labelKey)
                return false
            }
        } else {
            spawnedEntities.removeValue(forKey: labelKey)
            entitySpawnHistory.removeValue(forKey: labelKey)
            return false
        }
    }
    
    /// Removes any entities whose spawn timestamps have exceeded the expiry.
    private func cleanupExpiredEntities() {
        let now = Date()
        let expiredKeys = entitySpawnHistory.compactMap { (key, date) -> String? in
            if now.timeIntervalSince(date) > entityExpiryTime {
                return key
            }
            return nil
        }
        
        for key in expiredKeys {
            removeEntityFromScene(key)
        }
    }
    
    /// Removes the entity and its anchor from the scene for the given label key.
    /// - Parameter labelKey: Lowercased detection label key.
    private func removeEntityFromScene(_ labelKey: String) {
        guard let entity = spawnedEntities[labelKey] else { return }
        
        if let anchor = entity.anchor {
            arView?.scene.removeAnchor(anchor)
            print("Removed expired \(labelKey) entity from scene")
        }
        
        spawnedEntities.removeValue(forKey: labelKey)
        entitySpawnHistory.removeValue(forKey: labelKey)
    }
    
    private func removeFromTracking(_ entity: Entity) {
        let name = entity.name.lowercased()
        if !name.isEmpty {
            spawnedEntities.removeValue(forKey: name)
            entitySpawnHistory.removeValue(forKey: name)
        }
    }

    // MARK: - Place Detected Object
    /**
    Places AR entity for detection by raycasting bounding box center.
    - Parameters:
      - detection: Detection to place.
      - orientation: Image orientation.
      - camera: Current AR camera.
    */
    private func placeAsset(for detection: DetectionResult,
                            orientation: CGImagePropertyOrientation,
                            camera: ARCamera) {
        guard let arView = self.arView else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            let timeSinceLastSpawn = now.timeIntervalSince(lastSpawnTime)
            
            let bbox = detection.boundingBox
            let center = CGPoint(x: bbox.midX, y: bbox.midY)
            let viewSize = arView.bounds.size
            let tapPoint = CGPoint(x: center.x * viewSize.width,
                                   y: (1 - center.y) * viewSize.height)
            
            let results = arView.raycast(from: tapPoint,
                                         allowing: .estimatedPlane,
                                         alignment: .any)
            
            if let firstHit = results.first {
                let hitPosition = SIMD3<Float>(
                    firstHit.worldTransform.columns.3.x,
                    firstHit.worldTransform.columns.3.y,
                    firstHit.worldTransform.columns.3.z
                )
                
                if alreadySpawned(detection.label) {
                    if Int.random(in: 1...10) == 1 {
                        print("Spawn blocked for \(detection.label): entity exists or in cooldown")
                    }
                    return
                }
                
                let isSameLabel = detection.label == lastSpawnedLabel
                let distanceFromLast = distance(hitPosition, lastSpawnPosition)
                
                let shouldSpawn: Bool
                if isSameLabel {
                    shouldSpawn = timeSinceLastSpawn > (spawnCooldown * 2.0) && distanceFromLast > (minimumDistance * 2.0)
                } else {
                    shouldSpawn = timeSinceLastSpawn > spawnCooldown || distanceFromLast > minimumDistance
                }
                
                guard shouldSpawn else {
                    print("Skipping spawn: cooldown=\(String(format: "%.1f", timeSinceLastSpawn))s, same=\(isSameLabel), dist=\(String(format: "%.1f", distanceFromLast))m")
                    return
                }
                
                print("Raycast hit at \(firstHit.worldTransform)")
                let anchor = AnchorEntity(world: firstHit.worldTransform)
                
                if let entity = modelCache[detection.label.lowercased()]?.clone(recursive: true) {
                    entity.name = detection.label
                    
                    if let modelEntity = entity.findFirstModelEntity() {
                        entity.ensureAllModelEntitiesHaveCollision()
                        
                        PhysicsManager.addPhysics(to: modelEntity)
                        
                        modelEntity.generateCollisionShapes(recursive: true)
                        
                        if entity.components[CollisionComponent.self] == nil {
                            let bounds = entity.visualBounds(relativeTo: nil)
                            let size = bounds.extents
                            let safeSize = SIMD3<Float>(
                                max(size.x, 0.1),
                                max(size.y, 0.1),
                                max(size.z, 0.1)
                            )
                            entity.components[CollisionComponent.self] = CollisionComponent(
                                shapes: [.generateBox(size: safeSize)]
                            )
                        }
                    } else {
                        entity.components[CollisionComponent.self] = CollisionComponent(
                            shapes: [.generateBox(size: [0.1, 0.1, 0.1])]
                        )
                    }
                    
                    centralGestureManager?.addEntity(entity)
                    
                    anchor.addChild(entity)
                    arView.scene.addAnchor(anchor)
                    
                    let labelKey = detection.label.lowercased()
                    spawnedEntities[labelKey] = entity
                    entitySpawnHistory[labelKey] = now
                    spawnedAnchors.append(anchor)
                    cleanupOldObjects()
                    
                    if let animation = entity.availableAnimations.first {
                        entity.playAnimation(animation.repeat())
                    }
                    
                    lastSpawnTime = now
                    lastSpawnedLabel = detection.label
                    lastSpawnPosition = hitPosition
                    print("Spawned \(detection.label) at \(String(format: "%.1f", hitPosition.x)), \(String(format: "%.1f", hitPosition.y)), \(String(format: "%.1f", hitPosition.z))")
                } else {
                    let sphere = ModelEntity(
                        mesh: .generateSphere(radius: 0.1),
                        materials: [SimpleMaterial(color: .blue, isMetallic: false)]
                    )
                    sphere.name = detection.label
                    
                    sphere.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
                        massProperties: .default,
                        material: .default,
                        mode: .kinematic
                    )
                    sphere.components[CollisionComponent.self] = CollisionComponent(
                        shapes: [.generateSphere(radius: 0.1)]
                    )
                    
                    centralGestureManager?.addEntity(sphere)
                    
                    anchor.addChild(sphere)
                    arView.scene.addAnchor(anchor)
                    
                    let labelKey = detection.label.lowercased()
                    spawnedEntities[labelKey] = sphere
                    entitySpawnHistory[labelKey] = now
                    spawnedAnchors.append(anchor)
                    cleanupOldObjects()
                    
                    print("Could not load model for '\(detection.label)', using fallback sphere")
                    
                    lastSpawnTime = now
                    lastSpawnedLabel = detection.label
                    lastSpawnPosition = hitPosition
                }
            } else {
                print("No raycast hit, skipping placement")
            }
        }
    }
        
    
    // MARK: - Object Cleanup
    /// Trims older anchors when the maximum number of objects is exceeded.
    private func cleanupOldObjects() {
        guard spawnedAnchors.count > maxObjectsInScene else { return }
        
        let objectsToRemove = spawnedAnchors.count - maxObjectsInScene
        for i in 0..<objectsToRemove {
            let oldAnchor = spawnedAnchors[i]
            
            for child in oldAnchor.children {
                removeFromTracking(child)
            }
            
            arView?.scene.removeAnchor(oldAnchor)
            print("Removed old object to maintain scene limit")
        }
        spawnedAnchors = Array(spawnedAnchors.dropFirst(objectsToRemove))
        
        print("Cleaned up old objects from scene")
    }
    
    // MARK: - Debug Helper
    /**
    Prints the entity hierarchy for debugging, including basic component flags.
    - Parameters:
      - entity: The root entity to print.
      - depth: The initial indentation depth.
    */
    private func debugPrintEntityHierarchy(_ entity: Entity, depth: Int) {
        let indent = String(repeating: "  ", count: depth)
        let hasCollision = entity.components[CollisionComponent.self] != nil
        let hasPhysics = entity.components[PhysicsBodyComponent.self] != nil
        let isModelEntity = entity is ModelEntity
        
        print("\(indent)├─ \(entity.name.isEmpty ? "<unnamed>" : entity.name) " +
              "[\(type(of: entity))] " +
              "\(isModelEntity ? "[MODEL]" : "") " +
              "\(hasCollision ? "[COLLISION]" : "") " +
              "\(hasPhysics ? "[PHYSICS]" : "")")
        
        for child in entity.children {
            debugPrintEntityHierarchy(child, depth: depth + 1)
        }
    }
    
    // MARK: - Preload Models (async/await, iOS 15+)
    /// Preloads USDZ models and caches by detection label.
    private func preloadModels() {
        #if targetEnvironment(simulator)
        print("Skipping model preloads in Simulator (RealityKit/ARKit not supported).")
        return
        #else
        let mappings: [String: String] = [
            "laptop": "hummingbird_anim.usdz",
            "person": "toy_drummer.usdz",
            "table": "ball_basketball_realistic.usdz",
            "dining table": "ball_soccerball_realistic.usdz",
            "bottle": "ball_basketball_realistic.usdz",
            "book": "ball_basketball_realistic.usdz",
            "keyboard": "Straw.usdz",
            "mouse": "toy_biplane_realistic.usdz",
            "cell phone": "Straw.usdz",
            "tv": "ball_soccerball_realistic.usdz",
            "cat": "toy_drummer.usdz",
            "monitor": "ball_soccerball_realistic.usdz"
        ]

        Task {
            for (label, fileName) in mappings {
                do {
                    let entity = try await Entity(named: fileName)

                    await MainActor.run {
                        self.modelCache[label] = entity
                        print("Preloaded model for \(label) (\(fileName))")
                    }

                } catch {
                    print("Failed to preload \(fileName) for \(label): \(error.localizedDescription)")
                    
                    await MainActor.run {
                        self.handleFailedModelLoad(label: label, originalFile: fileName)
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - Model Loading Error Handling
    /**
    Attempts fallback model load when original fails.
    - Parameters:
      - label: Detection label.
      - originalFile: Original asset file that failed.
    */
    private func handleFailedModelLoad(label: String, originalFile: String) {
        let fallbackMappings: [String: String] = [
            "tv": "toy_biplane_realistic.usdz",
            "monitor": "toy_biplane_realistic.usdz",
            "laptop": "toy_drummer.usdz",
            "cell phone": "ball_basketball_realistic.usdz",
            "keyboard": "ball_basketball_realistic.usdz"
        ]
        
        if let fallbackFile = fallbackMappings[label] {
            Task {
                do {
                    let entity = try await Entity(named: fallbackFile)
                    await MainActor.run {
                        self.modelCache[label] = entity
                        print("Loaded fallback model for \(label) (\(fallbackFile))")
                    }
                } catch {
                    print("Fallback also failed for \(label) with \(fallbackFile): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    /// Removes anchors, clears caches and timers, and resets internal state.
    func cleanup() {
        stopDetectionTimer()
        
        for anchor in spawnedAnchors {
            arView?.scene.removeAnchor(anchor)
        }
        spawnedAnchors.removeAll()
        spawnedEntities.removeAll()
        entitySpawnHistory.removeAll()
        consecutiveDetections.removeAll()
        
        isProcessingFrame = false
        currentBuffer = nil
        currentCamera = nil
        
        centralGestureManager = nil
        
        modelCache.removeAll()
    }
    
    deinit {
        cleanup()
    }

}
