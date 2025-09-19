//
//  HelpButton.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI

/** 
 A reusable help button component that displays onboarding/tutorial overlays.
 Uses spring animations for visual feedback and supports accessibility.
*/
struct HelpButton: View {
    /** State binding controlling help overlay visibility */
    @Binding var isVisible: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                isVisible = true
            }
        }) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .foregroundColor(.yellow)
                .padding()
                .scaleEffect(isVisible ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isVisible)
        }
        .accessibilityLabel("Help")
        .accessibilityHint("Shows instructions for using this AR feature")
        .accessibilityAddTraits(.isButton)
    }
}
