//
//  SoundManager.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import RealityKit
import Foundation

/** 
 Manages spatial audio resources for AR experiences with caching support.
 Handles both iOS 17 and 18+ audio configurations.
 */
class SoundManager {
    private static var cache: [String: AudioFileResource] = [:]

    /**
     Loads and caches an audio resource for spatial playback.
     
     - Parameters:
       - fileName: Audio filename (supported: .wav, .m4a)
       - loop: Enable looping playback
     - Returns: Cached or newly loaded AudioFileResource
     */
    static func load(_ fileName: String, loop: Bool = false) -> AudioFileResource? {
        if let cached = cache[fileName] {
            return cached
        }
        
        // Extract name and extension
        let nameWithoutExtension = fileName.replacingOccurrences(of: ".wav", with: "").replacingOccurrences(of: ".m4a", with: "")
        let fileExtension = fileName.hasSuffix(".wav") ? "wav" : (fileName.hasSuffix(".m4a") ? "m4a" : "wav")
        
        // Check if file exists first
        guard Bundle.main.path(forResource: nameWithoutExtension, ofType: fileExtension) != nil else {
            print("Warning: Sound file \(fileName) not found in bundle, skipping audio")
            return nil
        }
        
        do {
            if #available(iOS 18.0, *) {
                // iOS18+: load with configuration
                var config = AudioFileResource.Configuration()
                
                // Use loadingStrategy
                config.loadingStrategy = .preload
                
                // Use shouldLoop
                config.shouldLoop = loop
            
                let resource = try AudioFileResource.load(named: fileName, configuration: config)
                cache[fileName] = resource
                return resource
            } else {
                // iOS17 path
                let resource = try AudioFileResource.load(
                    named: fileName,
                    in: nil,
                    inputMode: AudioFileResource.InputMode.spatial,
                    loadingStrategy: AudioFileResource.LoadingStrategy.preload,
                    shouldLoop: loop
                )
                cache[fileName] = resource
                return resource
            }
        } catch {
            print("Error: Failed to load sound \(fileName): \(error.localizedDescription)")
            return nil
        }
    }

    /** 
     Attaches and plays audio on a RealityKit entity.
     
     - Parameters:
       - fileName: Audio file to play
       - entity: Target entity for audio playback
       - loop: Enable looping playback
     */
    static func play(_ fileName: String, on entity: Entity, loop: Bool = false) {
        if let resource = load(fileName, loop: loop) {
            entity.playAudio(resource)
        }
    }

    /** 
     Stops audio playback on an entity.
     
     - Parameters:
       - fileName: Audio file to stop
       - entity: Entity currently playing the audio
     */
    static func stop(_ fileName: String, on entity: Entity) {
        if let resource = load(fileName, loop: false) {
            entity.playAudio(resource) // resets loop
        }
    }
}
