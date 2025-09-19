//
//  OnboardingModifier.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI

/** 
 View modifier that provides a Help button and Onboarding overlay for any view.
 Manages onboarding state persistence and conditional display timing.
*/
struct OnboardingModifier: ViewModifier {
    @AppStorage private var onboardingShown: Bool
    @State private var showOnboarding: Bool = false
    @State private var shouldTriggerOnboarding: Bool = false

    let title: String
    let hints: [String]
    let storageKey: String
    let delayCondition: () -> Bool

    /**
     Creates an onboarding modifier with the specified configuration.
     
     - Parameters:
       - title: Overlay title
       - hints: Hint strings to display
       - storageKey: UserDefaults key for onboarding state
       - delayCondition: Controls if onboarding should be delayed
     */
    init(title: String, hints: [String], storageKey: String, delayCondition: @escaping () -> Bool = { false }) {
        self.title = title
        self.hints = hints
        self.storageKey = storageKey
        self.delayCondition = delayCondition
        self._onboardingShown = AppStorage(wrappedValue: false, storageKey)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content

            // Help button
            HelpButton(isVisible: $showOnboarding)

            // Onboarding overlay
            OnboardingOverlay(
                isVisible: $showOnboarding,
                title: title,
                hints: hints
            )
        }
        .onAppear {
            if !onboardingShown {
                shouldTriggerOnboarding = true
                checkAndShowOnboarding()
            }
        }
        .onChange(of: delayCondition()) {
            checkAndShowOnboarding()
        }
    }
    
    private func checkAndShowOnboarding() {
        if shouldTriggerOnboarding && !delayCondition() {
            showOnboarding = true
            onboardingShown = true
            shouldTriggerOnboarding = false
        }
    }
}

extension View {
    /**
     Attaches onboarding functionality to a view.
     
     - Parameters:
       - title: Overlay title
       - hints: Hint strings to display
       - storageKey: UserDefaults storage key
       - delayCondition: Optional delay trigger
     - Returns: Modified view with onboarding capabilities
     */
    func withOnboarding(title: String, hints: [String], storageKey: String, delayCondition: @escaping () -> Bool = { false }) -> some View {
        self.modifier(OnboardingModifier(title: title, hints: hints, storageKey: storageKey, delayCondition: delayCondition))
    }
}

