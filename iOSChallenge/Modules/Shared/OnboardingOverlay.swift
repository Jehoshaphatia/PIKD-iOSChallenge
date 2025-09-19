//
//  OnboardingOverlay.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI

/** 
 A reusable tutorial overlay that displays instructions and persists dismissal state.
 
 Provides a semi-transparent overlay with a title, bulleted hints, and a dismissal button.
 State is automatically persisted via @AppStorage to show only on first use.
*/
struct OnboardingOverlay: View {
    @Binding var isVisible: Bool
    let title: String
    let hints: [String]

    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .accessibilityLabel("Dismiss help overlay")
                    .accessibilityHint("Tap to close the help instructions")

                VStack(spacing: 24) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(hints.enumerated()), id: \.offset) { index, hint in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "hand.point.right.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title3)
                                    .frame(width: 20)
                                    .accessibilityHidden(true)
                                Text(hint)
                                    .foregroundColor(.white)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityLabel("Instruction \(index + 1): \(hint)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain)

                    Button(action: dismiss) {
                        Text("Got it")
                            .font(.headline.bold())
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.yellow)
                            .cornerRadius(12)
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel("Got it")
                    .accessibilityHint("Dismisses the help instructions")
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(24)
                .accessibilityElement(children: .contain)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.7)).combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.9))
            ))
            .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0), value: isVisible)
        }
    }

    /** Dismisses the overlay with a spring animation effect */
    private func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) { 
            isVisible = false 
        }
    }
}
