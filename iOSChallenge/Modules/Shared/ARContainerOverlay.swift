//
//  ARContainerOverlay.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI
import RealityKit
import ARKit

/**
 A unified SwiftUI overlay container for AR experiences that manages coaching,
 status display, and onboarding flows.
 */
struct ARContainerOverlay<ARContent: UIViewRepresentable>: View {
    /** Main AR view content */
    let arContent: ARContent
    
    /** Current AR tracking status message */
    let trackingStatus: String
    
    /** Optional navigation status message */
    let navigationStatus: String?
    
    /** Onboarding configuration */
    let onboardingTitle: String
    let onboardingHints: [String]
    let onboardingKey: String
    
    /** AR session and delay handling */
    let sessionProvider: () -> ARSession?
    let delayCondition: () -> Bool

    /**
     Creates a new AR container overlay with the given configuration
     
     - Parameters:
       - arContent: Main AR view to display
       - trackingStatus: Current AR tracking state description
       - navigationStatus: Optional navigation guidance text
       - onboardingTitle: Title shown during onboarding
       - onboardingHints: List of onboarding guidance hints
       - onboardingKey: Storage key for onboarding completion
       - sessionProvider: Provides AR session for coaching overlay
       - delayCondition: Controls onboarding display timing
     */
    init(
        arContent: ARContent,
        trackingStatus: String,
        navigationStatus: String?,
        onboardingTitle: String,
        onboardingHints: [String],
        onboardingKey: String,
        sessionProvider: @escaping () -> ARSession? = { nil },
        delayCondition: @escaping () -> Bool = { false }
    ) {
         self.arContent = arContent
         self.trackingStatus = trackingStatus
         self.navigationStatus = navigationStatus
         self.onboardingTitle = onboardingTitle
         self.onboardingHints = onboardingHints
         self.onboardingKey = onboardingKey
         self.sessionProvider = sessionProvider
         self.delayCondition = delayCondition
     }

    /** Constructs the layered AR interface with coaching, status, and onboarding */
    var body: some View {
        ZStack {
            arContent
                .edgesIgnoringSafeArea(.all)
                .overlay(CoachingOverlayRepresentable(session: sessionProvider()), alignment: .center)

            VStack {
                HStack {
                    StatusHUD(
                        trackingStatus: trackingStatus,
                        navigationStatus: navigationStatus?.isEmpty == false ? navigationStatus : nil
                    )
                    Spacer()
                }
                Spacer()
            }
        }
        .withOnboarding(
            title: onboardingTitle,
            hints: onboardingHints,
            storageKey: onboardingKey,
            delayCondition: delayCondition
        )
    }
}
