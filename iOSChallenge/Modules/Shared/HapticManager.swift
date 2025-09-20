//
//  HapticManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import CoreHaptics
import UIKit

/**
 Enhanced haptic feedback manager that addresses the haptic engine failures seen in logs.
 
 Provides:
 - Automatic engine recovery from failures
 - Fallback to basic vibration when CoreHaptics fails
 - Proper resource management and cleanup
 */
final class HapticManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = HapticManager()
    
    // MARK: - Engine Management
    private var hapticEngine: CHHapticEngine?
    private var isEngineRunning = false
    private var supportsHaptics = false
    
    // MARK: - Patterns
    private var feedbackGenerators: [UIImpactFeedbackGenerator] = []
    
    private init() {
        setupHapticEngine()
        setupFeedbackGenerators()
    }
    
    // MARK: - Setup
    
    private func setupHapticEngine() {
        // Check device capabilities
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("Device does not support haptics - using fallback")
            supportsHaptics = false
            return
        }
        
        supportsHaptics = true
        createHapticEngine()
    }
    
    private func createHapticEngine() {
        do {
            hapticEngine = try CHHapticEngine()
            setupEngineHandlers()
            print("Haptic engine created successfully")
        } catch {
            print("Failed to create haptic engine: \(error.localizedDescription)")
            supportsHaptics = false
        }
    }
    
    private func setupEngineHandlers() {
        guard let engine = hapticEngine else { return }
        
        // Handle engine reset
        engine.resetHandler = { [weak self] in
            print("Haptic engine reset")
            self?.isEngineRunning = false
            self?.restartEngine()
        }
        
        // Handle engine stop
        engine.stoppedHandler = { [weak self] reason in
            print("Haptic engine stopped: \(reason)")
            self?.isEngineRunning = false
            
            switch reason {
            case .audioSessionInterrupt, .applicationSuspended:
                print("Attempting to restart haptic engine after interruption")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.restartEngine()
                }
            case .idleTimeout:
                print("Haptic engine stopped due to idle timeout")
            case .systemError:
                print("Haptic engine system error - recreating engine")
                self?.recreateEngine()
            case .notifyWhenFinished:
                print("Haptic engine stopped after completion")
            case .engineDestroyed:
                print("Haptic engine was destroyed - recreating")
                self?.recreateEngine()
            case .gameControllerDisconnect:
                print("Game controller disconnected")
            @unknown default:
                print("Unknown haptic engine stop reason")
            }
        }
    }
    
    private func setupFeedbackGenerators() {
        // Pre-create feedback generators for different impact types
        feedbackGenerators = [
            UIImpactFeedbackGenerator(style: .light),
            UIImpactFeedbackGenerator(style: .medium),
            UIImpactFeedbackGenerator(style: .heavy)
        ]
        
        // Prepare generators
        feedbackGenerators.forEach { $0.prepare() }
    }
    
    // MARK: - Engine Management
    
    private func startEngine() {
        guard supportsHaptics, let engine = hapticEngine, !isEngineRunning else {
            return
        }
        
        do {
            try engine.start()
            isEngineRunning = true
            print("Haptic engine started")
        } catch {
            print("Failed to start haptic engine: \(error.localizedDescription)")
            isEngineRunning = false
            handleEngineError(error)
        }
    }
    
    private func restartEngine() {
        guard supportsHaptics else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.startEngine()
        }
    }
    
    private func recreateEngine() {
        hapticEngine = nil
        isEngineRunning = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.createHapticEngine()
            self?.startEngine()
        }
    }
    
    private func handleEngineError(_ error: Error) {
        if let hapticError = error as? CHHapticError {
            switch hapticError.code {
            case .engineNotRunning:
                print("Engine not running - attempting restart")
                restartEngine()
            case .operationNotPermitted:
                print("Haptic operation not permitted")
                supportsHaptics = false
            case .engineStartTimeout:
                print("Engine start timeout - recreating")
                recreateEngine()
            default:
                print("Unknown haptic error: \(hapticError.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public Interface
    
    /**
     Plays a simple impact feedback with automatic fallback handling.
     
     - Parameter style: The impact intensity style
     */
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        // Try CoreHaptics first if available and running
        if supportsHaptics && isEngineRunning {
            playAdvancedImpact(style: style)
        } else {
            // Fallback to basic UIKit feedback
            playBasicImpact(style: style)
        }
    }
    
    /**
     Plays a selection feedback (for UI interactions).
     */
    func playSelection() {
        let selectionGenerator = UISelectionFeedbackGenerator()
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
    
    /**
     Plays a notification feedback.
     
     - Parameter type: The notification type (success, warning, error)
     */
    func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }
    
    // MARK: - Advanced Haptics
    
    private func playAdvancedImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard let engine = hapticEngine else {
            playBasicImpact(style: style)
            return
        }
        
        // Ensure engine is running
        if !isEngineRunning {
            startEngine()
            // If still not running, fallback
            if !isEngineRunning {
                playBasicImpact(style: style)
                return
            }
        }
        
        do {
            // Create haptic pattern based on style
            let intensity: Float
            let sharpness: Float
            
            switch style {
            case .light:
                intensity = 0.3
                sharpness = 0.2
            case .medium:
                intensity = 0.6
                sharpness = 0.5
            case .heavy:
                intensity = 1.0
                sharpness = 0.8
            case .soft:
                intensity = 0.4
                sharpness = 0.3
            case .rigid:
                intensity = 0.8
                sharpness = 0.9
            @unknown default:
                intensity = 0.6
                sharpness = 0.5
            }
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            
        } catch {
            print("Advanced haptic failed: \(error.localizedDescription)")
            // Fallback to basic haptics
            playBasicImpact(style: style)
        }
    }
    
    // MARK: - Fallback Haptics
    
    private func playBasicImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generatorIndex: Int
        
        switch style {
        case .light:
            generatorIndex = 0
        case .medium:
            generatorIndex = 1
        case .heavy:
            generatorIndex = 2
        case .soft:
            generatorIndex = 0  // Use light generator for soft
        case .rigid:
            generatorIndex = 2  // Use heavy generator for rigid
        @unknown default:
            generatorIndex = 1
        }
        
        guard generatorIndex < feedbackGenerators.count else {
            print("Invalid feedback generator index")
            return
        }
        
        let generator = feedbackGenerators[generatorIndex]
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Lifecycle
    
    func applicationDidEnterBackground() {
        // Stop engine to save battery
        if isEngineRunning {
            hapticEngine?.stop(completionHandler: { error in
                if let error = error {
                    print("Error stopping haptic engine: \(error.localizedDescription)")
                }
            })
            isEngineRunning = false
        }
    }
    
    func applicationWillEnterForeground() {
        // Restart engine if needed
        if supportsHaptics && !isEngineRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startEngine()
            }
        }
    }
    
    deinit {
        hapticEngine?.stop(completionHandler: nil)
        feedbackGenerators.removeAll()
    }
}
