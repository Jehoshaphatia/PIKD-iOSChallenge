# iOS AR Challenge – Modular Geospatial + Object Detection AR

An iOS AR demo app that integrates **Geospatial Anchoring, Physics-based Gestures, Object Detection, and AR Navigation** in a modular and extensible architecture.

Built with **ARKit 6+**, **RealityKit 2**, **CoreML + Vision**, and **MapKit**.

---

## Features

### 1. Geospatial AR
- Anchors a **soldier model** at real-world GPS coordinates (`GeoConfig.json` or fallback constants).
- Uses **ARGeoTrackingConfiguration (VPS)** when available.
- Falls back gracefully to **GPS → AR positioning** if VPS unavailable, with clear UI banners.
- Dynamic onboarding and status HUDs for user clarity.

### 2. Gestures + Physics + Feedback
- Supported gestures:
  - **Tap** → Jump (with impulse + animation + sound + haptic)
  - **Swipe** → Rotate soldier left/right
  - **Pinch** → Scale soldier up/down
  - **Pan** → Move soldier in AR space
- Centralized physics engine (`PhysicsManager`).
- Immersive **audio + haptic feedback** via `FeedbackManager`.

### 3. Object Detection / Recognition
- **YOLOv8 CoreML model** integrated with Vision framework.
- Recognized objects spawn mapped AR assets (`.usdz`) or fallback spheres.
- Automatic:
  - Physics + gestures binding
  - Cooldown and scene cleanup (max 10 objects)
- Live HUD: detection status and scanning indicator.

### 4. AR Navigation
- **MapKit routing** → dynamically computed walking route.
- Waypoints anchored in AR with:
  - Color coding (🟢 start, 🔵 path, 🔴 destination)
  - Pulsing animation for visibility
- Updates dynamically if user strays from route.

### 5. UX & Performance
- `ARContainerOverlay` combines:
  - Coaching overlays
  - Status HUD
  - Onboarding tutorials (persisted via `@AppStorage`)
- Smooth rendering (FPS ≥ 30 on iPhone 14 tested).
- Efficient detection (throttled at ~3FPS).
- Memory management with object cleanup.

---

## Project Structure

```
iOSChallenge/
├── Modules/
│   ├── Detection/
│   │   ├── DetectionView.swift
│   │   └── ObjectDetectionManager.swift
│   ├── Geospatial/
│   │   ├── GeospatialView.swift
│   │   └── GeospatialManager.swift
│   ├── Interactions/
│   │   ├── CentralGestureManager.swift
│   │   ├── CharacterController.swift
│   │   ├── EntityGestureManager.swift
│   │   ├── GestureBinder.swift
│   │   └── PhysicsManager.swift
│   ├── Navigation/
│   │   └── NavigationManager.swift
│   └── Shared/
│       ├── ARSessionManager.swift
│       ├── PerformanceManager.swift
│       ├── SoundManager.swift
│       ├── HapticManager.swift
│       ├── FeedbackManagerNew.swift
│       ├── ARContainerOverlay.swift
│       ├── OnboardingOverlay.swift
│       ├── StatusHUD.swift
│       └── ... (other shared components)
├── Config/
│   ├── GeoConfig.swift
│   └── GeoConfig.json
├── Resources/
│   ├── Models/
│   └── Sounds/
AppDelegate.swift
ContentView.swift
```

---

## Tech Stack

- **ARKit 6+** → ARGeoTracking, ARWorldTracking
- **RealityKit 2** → Rendering, gestures, physics
- **CoreLocation** → GPS + heading for fallback
- **MapKit** → Route computation + overlays
- **CoreML + Vision** → Object detection (YOLOv8)
- **Core Haptics** → Feedback system
- - **SwiftUI** → All UI (Status HUD, Onboarding, TabView)

---

## Configuration

### Customizing Geospatial Locations

The app is designed to be easily configured for any location, not just the default "Becca's Beauty Bar."

There are two ways to manage locations:

1.  **Primary Method: `GeoConfig.json`**

    The easiest way to add or change locations is by editing `iOSChallenge/Config/GeoConfig.json`. This file contains a dictionary of location objects.

    To add a new location, simply add a new key-value pair to the `locations` object. For example, to add a location for New York City:

    ```json
    {
      "locations": {
        "beccasBeautyBar": { "latitude": 6.3569139, "longitude": 2.4007071, "altitude": 1 },
        "sanFrancisco": { "latitude": 37.7749, "longitude": -122.4194, "altitude": 0 },
        "stanford": { "latitude": 37.4275, "longitude": -122.1697, "altitude": 0 },
        "newYork": { "latitude": 40.7128, "longitude": -74.0060, "altitude": 10 }
      },
      "defaults": {
        "altitude": 0
      }
    }
    ```

2.  **Fallback Method: `GeoConfig.swift`**

    If `GeoConfig.json` is missing or a specific location key is not found, the app uses hardcoded fallback values from `iOSChallenge/Config/GeoConfig.swift`.

    ```swift
    // Inside GeoConfig.swift
    private static let fallbackLocations: [String: GeoLocation] = [
        "beccasBeautyBar": GeoLocation(latitude: 6.356913911104207, ...),
        "sanFrancisco": GeoLocation(latitude: 37.7749, ...),
        "stanford": GeoLocation(latitude: 37.4275, ...)
    ]
    ```
    
    To use a different location within the code, you would need to add a new static property to the `GeoConfig` enum in `GeoConfig.swift` that references the new key.

---

## Getting Started


---

## How to Run

1. **Requirements**
   - iOS 18.5+ (project targets iOS 18.5 for latest ARKit features)
   - Xcode 16+
   - iPhone with A12+ chip (ARKit requirement)
   - Location services + Camera permissions enabled
   - **Physical device required** (ARKit doesn't work in Simulator)

2. **Setup**
   - Clone repo
   - Open `iOSChallenge.xcodeproj` in Xcode
   - Ensure `GeoConfig.json` is in app bundle (fallbacks included if missing)
   - Build to physical device (Simulator not supported for AR)

3. **Run**
   - Launch app on device, grant camera/location permissions
   - Switch tabs:
     - **Geo** → Place soldier at GPS location, follow waypoints
     - **Detect** → Scan real-world objects (laptop, cup, phone), spawn AR models

---

## Design & Architecture Choices
- **Modularity**: Each feature is encapsulated in its own manager → SDK-ready.
- **Fallback-first**: VPS unavailability handled gracefully (alerts, banners, GPS fallback).
- **Performance-aware**: Object detection throttled, cleanup logic included.
- **Immersion**: Audio + haptic feedback paired with gestures.
- **UX-first**: Onboarding overlays, coaching, persistent help button.

---

## Improvements Beyond Spec
- Added **pan gesture** (not required in challenge).
- Audio + haptics feedback on all interactions.
- Onboarding overlays with persistent state.
- Clear **fallback banner + alerts** for VPS/GPS.
- Waypoints with **pulse animation** for better navigation visibility.
- Debugging utilities for entity hierarchy.


