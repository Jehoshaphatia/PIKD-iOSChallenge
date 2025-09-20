//
//  ARSessionManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import ARKit
import RealityKit
import CoreLocation

/**
 Enhanced ARSession manager that addresses the critical issues identified in the logs:
 - ARFrame retention and memory leaks
 - Resource constraint handling
 - Session state management
 - VPS availability checking
 */
final class ARSessionManager: NSObject, ObservableObject {
    
    // MARK: - Published State
    @Published var sessionState: ARSessionState = .idle
    @Published var trackingQuality: ARCamera.TrackingState = .notAvailable
    @Published var isVPSAvailable: Bool = false
    @Published var geoTrackingStatus: ARGeoTrackingStatus?
    
    // MARK: - Session Management
    private var arSession: ARSession?
    private var frameBuffer: ARFrame?
    private var lastFrameTime: CFTimeInterval = 0
    private let frameProcessingInterval: CFTimeInterval = 0.033 // ~30 FPS
    
    // MARK: - Resource Management
    private var isProcessingFrame = false
    private var frameRetentionCount = 0
    private let maxFrameRetention = 2
    
    // MARK: - VPS Management
    private var vpsCheckCompletion: ((Bool, Error?) -> Void)?
    private var hasCheckedVPS = false
    
    enum ARSessionState: Equatable {
        case idle
        case starting
        case running
        case paused
        case failed(Error)
        
        static func == (lhs: ARSessionState, rhs: ARSessionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.starting, .starting), (.running, .running), (.paused, .paused):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Session Configuration
    
    /**
     Configures and starts an AR session with optimal settings.
     
     - Parameters:
        - arView: The ARView to configure
        - preferVPS: Whether to prefer VPS (geo tracking) over world tracking
        - completion: Called when configuration is complete
     */
    func configureSession(
        arView: ARView,
        preferVPS: Bool = true,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        print("Configuring AR session...")
        
        // Clean up any existing session
        cleanupSession()
        
        // Set up new session
        arSession = arView.session
        arSession?.delegate = self
        
        sessionState = .starting
        
        if preferVPS && ARGeoTrackingConfiguration.isSupported {
            configureVPSSession(arView: arView, completion: completion)
        } else {
            configureWorldTrackingSession(arView: arView, completion: completion)
        }
    }
    
    // MARK: - VPS Configuration
    
    private func configureVPSSession(
        arView: ARView,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        print("Checking VPS availability...")
        
        // Check VPS availability first
        ARGeoTrackingConfiguration.checkAvailability { [weak self] available, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isVPSAvailable = available
                
                if available {
                    print("VPS available - configuring geo tracking")
                    self.startGeoTracking(arView: arView, completion: completion)
                } else {
                    print("VPS not available - falling back to world tracking")
                    if let error = error {
                        print("VPS error: \(error.localizedDescription)")
                    }
                    self.configureWorldTrackingSession(arView: arView, completion: completion)
                }
            }
        }
    }
    
    private func startGeoTracking(
        arView: ARView,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let config = ARGeoTrackingConfiguration()
        config.planeDetection = [.horizontal]
        
        // Optimize for performance
        if PerformanceManager.shared.performanceMetrics.isLowPowerMode {
            config.planeDetection = []
            print("Disabled plane detection for low power mode")
        }
        
        arSession?.run(config, options: [.resetTracking, .removeExistingAnchors])
        sessionState = .running
        completion(true, nil)
        print("Geo tracking session started")
    }
    
    // MARK: - World Tracking Configuration
    
    private func configureWorldTrackingSession(
        arView: ARView,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        print("Configuring world tracking session...")
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        
        // Optimize for device capabilities
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) &&
           !PerformanceManager.shared.performanceMetrics.isLowPowerMode {
            config.sceneReconstruction = .mesh
        }
        
        // Disable expensive features on resource-constrained devices
        if PerformanceManager.shared.performanceMetrics.memoryUsage > 0.7 {
            config.planeDetection = []
            config.sceneReconstruction = []
            print("Reduced tracking features due to memory constraints")
        }
        
        arSession?.run(config, options: [.resetTracking, .removeExistingAnchors])
        sessionState = .running
        completion(true, nil)
        print("World tracking session started")
    }
    
    // MARK: - Session Control
    
    func pauseSession() {
        guard sessionState == .running else { return }
        
        arSession?.pause()
        sessionState = .paused
        
        // Clean up retained frames when paused
        cleanupFrameBuffer()
        
        print("AR session paused")
    }
    
    func resumeSession() {
        guard sessionState == .paused,
              let session = arSession,
              let config = session.configuration else { return }
        
        session.run(config)
        sessionState = .running
        
        print("AR session resumed")
    }
    
    func stopSession() {
        guard sessionState != .idle else { return }
        
        arSession?.pause()
        sessionState = .idle
        
        cleanupSession()
        
        print("AR session stopped")
    }
    
    // MARK: - Frame Management
    
    /**
     Gets the current frame with proper memory management.
     Returns nil if no frame is available or if processing is throttled.
     */
    func getCurrentFrame() -> ARFrame? {
        let currentTime = CACurrentMediaTime()
        
        // Throttle frame access to prevent retention
        guard currentTime - lastFrameTime >= frameProcessingInterval,
              !isProcessingFrame,
              frameRetentionCount < maxFrameRetention else {
            return nil
        }
        
        guard let currentFrame = arSession?.currentFrame else {
            return nil
        }
        
        // Update frame management state
        lastFrameTime = currentTime
        frameRetentionCount += 1
        
        // Schedule cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.frameRetentionCount = max(0, (self?.frameRetentionCount ?? 0) - 1)
        }
        
        return currentFrame
    }
    
    // MARK: - Memory Management
    
    private func cleanupFrameBuffer() {
        frameBuffer = nil
        frameRetentionCount = 0
        print("Cleaned up frame buffer")
    }
    
    private func cleanupSession() {
        arSession?.delegate = nil
        arSession = nil
        cleanupFrameBuffer()
        isProcessingFrame = false
        print("Cleaned up AR session")
    }
    
    // MARK: - Anchor Management
    
    func addAnchor(_ anchor: ARAnchor) -> Bool {
        guard let session = arSession,
              sessionState == .running else {
            print("Cannot add anchor - session not running")
            return false
        }
        
        // Check if we're approaching anchor limits
        let currentAnchorCount = session.currentFrame?.anchors.count ?? 0
        if currentAnchorCount > 20 {
            print("High anchor count (\(currentAnchorCount)) - consider cleanup")
        }
        
        session.add(anchor: anchor)
        return true
    }
    
    func removeAnchor(_ anchor: ARAnchor) {
        arSession?.remove(anchor: anchor)
    }
    
    // MARK: - Diagnostics
    
    func getSessionDiagnostics() -> [String: Any] {
        var diagnostics: [String: Any] = [:]
        
        diagnostics["sessionState"] = String(describing: sessionState)
        diagnostics["trackingQuality"] = String(describing: trackingQuality)
        diagnostics["isVPSAvailable"] = isVPSAvailable
        diagnostics["frameRetentionCount"] = frameRetentionCount
        diagnostics["geoTrackingStatus"] = String(describing: geoTrackingStatus)
        
        if let session = arSession {
            diagnostics["anchorCount"] = session.currentFrame?.anchors.count ?? 0
        }
        
        return diagnostics
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Prevent excessive frame retention by selective processing
        let currentTime = CACurrentMediaTime()
        
        guard currentTime - lastFrameTime >= frameProcessingInterval else {
            return // Skip this frame to prevent retention
        }
        
        // Update tracking state
        DispatchQueue.main.async { [weak self] in
            self?.trackingQuality = frame.camera.trackingState
        }
        
        // Handle geo tracking status if available
        if let geoTrackingStatus = frame.geoTrackingStatus {
            DispatchQueue.main.async { [weak self] in
                self?.geoTrackingStatus = geoTrackingStatus
            }
        }
        
        lastFrameTime = currentTime
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async { [weak self] in
            self?.trackingQuality = camera.trackingState
            
            // Log significant tracking changes
            switch camera.trackingState {
            case .notAvailable:
                print("Camera tracking: Not available")
            case .normal:
                print("Camera tracking: Normal")
            case .limited(let reason):
                print("Camera tracking limited: \(reason)")
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            self?.sessionState = .failed(error)
        }
        
        // Attempt automatic recovery for specific errors
        if let arError = error as? ARError {
            handleARError(arError, session: session)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session interrupted")
        
        DispatchQueue.main.async { [weak self] in
            self?.sessionState = .paused
        }
        
        // Clean up resources during interruption
        cleanupFrameBuffer()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
        
        DispatchQueue.main.async { [weak self] in
            self?.sessionState = .running
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("Added \(anchors.count) anchors")
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        print("Removed \(anchors.count) anchors")
    }
    
    // MARK: - Error Handling
    
    private func handleARError(_ error: ARError, session: ARSession) {
        switch ARError.Code(rawValue: error.errorCode) {
        case .some(.cameraUnauthorized):
            print("Camera access denied")
            
        case .some(.worldTrackingFailed):
            print("World tracking failed - attempting recovery")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let config = session.configuration {
                    session.run(config, options: [.resetTracking])
                }
            }
            
        case .some(.geoTrackingNotAvailableAtLocation):
            print("Geo tracking not available at current location")
            // Could trigger fallback to world tracking here
            
        case .some(.geoTrackingFailed):
            print("Geo tracking failed")
            
        default:
            print("Unknown AR error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Extensions
