//
//  GeoConfig.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import CoreLocation

// MARK: - Codable Structures
struct GeoLocation: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct GeoConfigData: Codable {
    let locations: [String: GeoLocation]
    let defaults: Defaults
    
    struct Defaults: Codable {
        let altitude: Double
    }
}

// MARK: - GeoConfig Loader
enum GeoConfig {
    private static let config: GeoConfigData? = {
        guard let url = Bundle.main.url(forResource: "GeoConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ GeoConfig.json not found in bundle. Using fallback values.")
            return nil
        }
        do {
            return try JSONDecoder().decode(GeoConfigData.self, from: data)
        } catch {
            print("⚠️ Failed to decode GeoConfig.json: \(error.localizedDescription). Using fallback values.")
            return nil
        }
    }()
    
    // MARK: - Fallback Defaults
    private static let fallbackLocations: [String: GeoLocation] = [
        "beccasBeautyBar": GeoLocation(latitude: 6.356913911104207,
                                       longitude: 2.400707146363209,
                                       altitude: 10),
        "sanFrancisco": GeoLocation(latitude: 37.7749,
                                    longitude: -122.4194,
                                    altitude: 0),
        "stanford": GeoLocation(latitude: 37.4275,
                                longitude: -122.1697,
                                altitude: 0)
    ]
    private static let fallbackAltitude: Double = 0
    
    // MARK: - Accessors
    static var beccasBeautyBar: GeoLocation {
        getLocation(named: "beccasBeautyBar")
    }
    
    static var sanFrancisco: GeoLocation {
        getLocation(named: "sanFrancisco")
    }
    
    static var stanford: GeoLocation {
        getLocation(named: "stanford")
    }
    
    static var defaultAltitude: Double {
        if let altitude = config?.defaults.altitude {
            return altitude
        } else {
            print("⚠️ Using fallback altitude: \(fallbackAltitude)")
            return fallbackAltitude
        }
    }
    
    // MARK: - Helper
    private static func getLocation(named key: String) -> GeoLocation {
        if let location = config?.locations[key] {
            return location
        } else if let fallback = fallbackLocations[key] {
            print("⚠️ Using fallback location for '\(key)': \(fallback.latitude), \(fallback.longitude)")
            return fallback
        } else {
            // Graceful fallback: return neutral coordinate instead of crashing
            print("❌ Missing both JSON and fallback value for location: \(key). Returning neutral (0,0,0).")
            return GeoLocation(latitude: 0, longitude: 0, altitude: 0)
        }
    }
}
