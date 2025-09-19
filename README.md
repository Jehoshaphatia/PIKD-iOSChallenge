# 📱 iOS AR Challenge – Modular Geospatial + Object Detection AR

An iOS AR demo app that integrates **Geospatial Anchoring, Physics-based Gestures, Object Detection, and AR Navigation** in a modular and extensible architecture.

Built with **ARKit 6+**, **RealityKit 2**, **CoreML + Vision**, and **MapKit**.

---

## 🚀 Features

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

## 📂 Project Structure

```
Modules/
├── Geospatial/
│   ├── GeospatialManager.swift
│   ├── GeospatialView.swift
│   ├── GeoConfig.swift
├── Detection/
│   ├── ObjectDetectionManager.swift
│   ├── DetectionView.swift
├── Navigation/
│   ├── NavigationManager.swift
├── Gestures/
│   ├── GestureManager.swift
│   ├── GestureBinder.swift
│   ├── CharacterController.swift
│   ├── PhysicsManager.swift
├── Feedback/
│   ├── FeedbackManager.swift
│   ├── SoundManager.swift
├── UI/
│   ├── ARContainerOverlay.swift
│   ├── StatusHUD.swift
│   ├── OnboardingOverlay.swift
│   ├── OnboardingModifier.swift
│   ├── HelpButton.swift
│   ├── CoachingOverlayRepresentable.swift
├── Utils/
│   ├── Extensions.swift
│   ├── DebugUtils.swift
AppDelegate.swift
ContentView.swift
```

---

## 🛠️ Tech Stack

- **ARKit 6+** → ARGeoTracking, ARWorldTracking
- **RealityKit 2** → Rendering, gestures, physics
- **CoreLocation** → GPS + heading for fallback
- **MapKit** → Route computation + overlays
- **CoreML + Vision** → Object detection (YOLOv8)
- **Core Haptics** → Feedback system
- **SwiftUI** → All UI (Status HUD, Onboarding, TabView)

---

## ▶️ How to Run

1. **Requirements**
   - iOS 18.5+ (project targets iOS 18.5 for latest ARKit features)
   - Xcode 15+
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

## 🧩 Design & Architecture Choices
- **Modularity**: Each feature is encapsulated in its own manager → SDK-ready.
- **Fallback-first**: VPS unavailability handled gracefully (alerts, banners, GPS fallback).
- **Performance-aware**: Object detection throttled, cleanup logic included.
- **Immersion**: Audio + haptic feedback paired with gestures.
- **UX-first**: Onboarding overlays, coaching, persistent help button.

### Architecture Note
This app uses a **single-window architecture with AppDelegate**. Apple recommends UIScene for multi-window setups, but for this challenge I intentionally used AppDelegate for simplicity and clarity. Functionality is unaffected on iOS 16–18.

---

## ✅ Improvements Beyond Spec
- Added **pan gesture** (not required in challenge).
- Audio + haptics feedback on all interactions.
- Onboarding overlays with persistent state.
- Clear **fallback banner + alerts** for VPS/GPS.
- Waypoints with **pulse animation** for better navigation visibility.
- Debugging utilities for entity hierarchy.

---

## 📖 Credits
- Apple ARKit / RealityKit documentation  
- CoreML YOLOv8 (converted to CoreML model)  
