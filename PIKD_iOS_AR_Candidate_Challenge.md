# PIKD iOS AR Candidate Challenge

## Objective
Evaluate your ability to design and implement a modular, interactive AR system on iOS that demonstrates expertise in: geospatial AR, physics-driven interactions, object detection, and AR navigation.

We want to see design, architecture, and execution skills.

---

## Challenge Overview

Create an iOS AR demo app that demonstrates the following capabilities:

### 1. Geospatial AR
- Place at least one 3D asset anchored to a real-world GPS location.
- Demonstrate anchor stability while moving around.
- Use ARKit VPS or Location Anchors to ensure the asset remains accurately positioned.

### 2. Gestures & Physics
- Implement gestures: tap, swipe, pinch.
- Demonstrate physics-driven behavior: object falls, bounces, or reacts realistically to touch.
- Optional: haptic feedback when interacting with objects.

### 3. Object Detection / Recognition
- Use CoreML + Vision framework to detect a specific object in the environment.
- Trigger an AR asset to appear, animate, or react when the object is detected.
- Candidate may use pre-trained models like YOLOv8, MobileNet, or EfficientDet.

### 4. AR Navigation
- Display a simple AR path or waypoint system to guide the user toward the geospatial asset.
- Overlays should update dynamically as the user moves.
- Use MapKit + RealityKit overlays for visual guidance.

### 5. Performance
- Maintain smooth rendering (≥30 fps) on a recent iPhone.
- Efficient memory usage and responsive interactions.

---

## Technical Requirements

### Core iOS AR Stack
- ARKit 6+, iOS 16+
- RealityKit 2 / SceneKit for rendering
- Metal API for rendering optimization

### Gestures & Physics
- RealityKit gesture recognizers (tap, swipe, pinch, drag)
- RealityKit physics engine
- Optional: Core Haptics for feedback

### Geospatial
- ARKit VPS / Location Anchors
- CoreLocation for GPS-based placement
- MapKit overlays for navigation

### Object Detection
- CoreML + Vision framework
- Pre-trained on-device models (YOLOv8, MobileNet, EfficientDet)

### AR Navigation
- RealityKit / MapKit overlays for AR wayfinding
- Dynamic path rendering with SceneKit/RealityKit

---

## Deliverables

1. **iOS Project**
   - Xcode project with modular, well-structured code.
   - Focus on architecture, modularity, and maintainability.

2. **Documentation**
   - README covering:
     - App architecture
     - Libraries and frameworks used
     - How to run/test the app
     - Decisions made for performance and UX

3. **Demo Video (Optional but Recommended)**
   - 30–60 seconds screen capture showcasing:
     - Geospatial AR anchor
     - Gesture-based interactions and physics
     - Object detection triggering asset behavior
     - AR navigation overlay

---

## Evaluation Criteria

### Technical Skill
- Correct use of ARKit, RealityKit, Metal
- Geospatial anchor stability
- Smooth gestures and physics
- Object detection implementation
- AR navigation overlay accuracy

### Architecture & Modularity
- Code structured as modules for potential SDK integration
- Clear separation of concerns: geospatial module, interactions, object detection, AR navigation

### Performance
- Smooth AR rendering on iPhone
- Efficient memory usage and responsive interactions

### Documentation & Clarity
- Well-written README explaining design choices
- Easy to run and test

---

## Sections
- PIKD iOS AR Candidate Challenge
- Challenge Overview
- Technical Requirements
- Deliverables
- Evaluation Criteria
