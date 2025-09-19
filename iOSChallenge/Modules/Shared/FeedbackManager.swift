//
//  FeedbackManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import RealityKit
import CoreHaptics

/** 
 Manages haptic and audio feedback for AR interactions using CoreHaptics.
 Provides synchronized haptic and sound feedback for entity interactions.
 */
class FeedbackManager {
    
    /** 
     Shared haptic engine instance that auto-restarts on interruption.
     Handles device capability checking and engine lifecycle management.
     */
    private static var hapticsEngine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        do {
            let engine = try CHHapticEngine()
            
            engine.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason). Restarting...")
                do {
                    try engine.start()
                    print("Haptic engine restarted successfully")
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            engine.resetHandler = {
                print("Haptic engine reset. Restarting...")
                do {
                    try engine.start()
                    print("Haptic engine restarted after reset")
                } catch {
                    print("Failed to restart haptic engine after reset: \(error)")
                }
            }
            
            try engine.start()
            return engine
        } catch {
            print("Haptics not available: \(error.localizedDescription)")
            return nil
        }
    }()
    
    // MARK: - Public API
    
    /** Plays strong haptic and jump sound feedback on the entity */
    static func jump(on entity: Entity) {
        playHaptic(style: .strong)
        SoundManager.play("jump.wav", on: entity)
    }
    
    /** Plays light haptic and turn sound feedback on the entity */
    static func turn(on entity: Entity) {
        playHaptic(style: .light)
        SoundManager.play("turn.m4a", on: entity)
    }
    
    /** Plays soft haptic and scale sound feedback on the entity */
    static func scale(on entity: Entity) {
        playHaptic(style: .soft)
        SoundManager.play("scale.wav", on: entity)
    }
    
    /** 
     Plays pulse haptic and walking sound feedback
     - Parameters:
       - entity: Target entity for spatial audio
       - loop: Whether to loop the walking sound
     */
    static func walkStep(on entity: Entity, loop: Bool = false) {
        playHaptic(style: .pulse)
        SoundManager.play("footstep.wav", on: entity, loop: loop)
    }
    
    /** Stops any active walking sound on the specified entity */
    static func stopWalking(on entity: Entity) {
        SoundManager.stop("footstep.wav", on: entity)
    }
    
    // MARK: - Internal Haptics
    
    /** Defines available haptic feedback intensities and patterns */
    private enum HapticStyle { case strong, light, soft, pulse }
    
    /**
     Creates and plays a haptic pattern based on the specified style.
     Handles engine state management and error recovery.
     */
    private static func playHaptic(style: HapticStyle) {
        guard let engine = hapticsEngine else { return }
        
        do {
            if engine.currentTime == 0 {
                try engine.start()
                print("Haptic engine was stopped, restarted")
            }
        } catch {
            print("Failed to restart haptic engine: \(error)")
            return
        }
        
        do {
            let event: CHHapticEvent
            switch style {
            case .strong:
                event = CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [
                                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                                      ],
                                      relativeTime: 0)
            case .light:
                event = CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [
                                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                                      ],
                                      relativeTime: 0)
            case .soft:
                event = CHHapticEvent(eventType: .hapticContinuous,
                                      parameters: [
                                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                                      ],
                                      relativeTime: 0,
                                      duration: 0.2)
            case .pulse:
                event = CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [
                                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                                      ],
                                      relativeTime: 0)
            }
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            print("Haptic feedback played successfully")
            
        } catch {
            print("Haptic error: \(error.localizedDescription)")
        }
    }
}

