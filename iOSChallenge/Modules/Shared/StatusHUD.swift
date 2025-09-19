//
//  StatusHUD.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import SwiftUI

/** 
 A lightweight HUD component that displays AR tracking and navigation status.
 
 Renders status information in a translucent overlay with support for:
 - Tracking state display
 - Optional navigation status
 */
struct StatusHUD: View {
    /** Current AR tracking status message */
    let trackingStatus: String
    
    /** Optional navigation status message */
    let navigationStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trackingStatus)
                .font(.caption)
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)

            if let navigationStatus = navigationStatus {
                Text(navigationStatus)
                    .font(.caption2)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
