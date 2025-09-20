//
//  FeedbackManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import RealityKit
import UIKit

/** 
 Manages haptic and audio feedback for AR interactions.
 Now uses the enhanced HapticManager for improved reliability and error handling.
 */
class FeedbackManager {
    
    private static let hapticManager = HapticManager.shared
    
    // MARK: - Public Interface
    
    /** Plays strong haptic feedback for significant interactions (entity taps, spawns) */
    static func playStrong() {
        print("Haptic feedback played successfully")
        hapticManager.playImpact(style: .heavy)
    }
    
    /** Plays light haptic feedback for subtle interactions (UI touches, hovers) */
    static func playLight() {
        hapticManager.playImpact(style: .light)
    }
    
    /** Plays soft haptic feedback for gentle continuous actions */
    static func playSoft() {
        hapticManager.playImpact(style: .medium)
    }
    
    /** Plays pulsing haptic feedback for ongoing processes */
    static func playPulse() {
        hapticManager.playSelection()
    }
    
    /** Plays notification feedback for system events */
    static func playNotification(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        hapticManager.playNotification(type: type)
    }
    
    // MARK: - Entity-Specific Actions
    
    /** Plays jump feedback - strong haptic with jump sound */
    static func jump(on entity: Entity) {
        playStrong()
        SoundManager.play("jump.wav", on: entity)
    }
    
    /** Plays turn feedback - light haptic with turn sound */
    static func turn(on entity: Entity) {
        playLight()
        SoundManager.play("turn.m4a", on: entity)
    }
    
    /** Plays scale feedback - medium haptic with scale sound */
    static func scale(on entity: Entity) {
        playSoft()
        SoundManager.play("scale.wav", on: entity)
    }
    
    /** Plays walking step feedback - soft haptic with footstep sound */
    static func walkStep(on entity: Entity, loop: Bool = false) {
        playSoft()
        SoundManager.play("footstep.wav", on: entity, loop: loop)
    }
    
    // MARK: - Audio + Haptic Combinations
    
    /** Plays a walking sound on the specified entity with optional looping */
    static func playWalking(on entity: Entity, loop: Bool = true) {
        SoundManager.play("footstep.wav", on: entity, loop: loop)
    }
    
    /** Stops any active walking sound on the specified entity */
    static func stopWalking(on entity: Entity) {
        SoundManager.stop("footstep.wav", on: entity)
    }
}
