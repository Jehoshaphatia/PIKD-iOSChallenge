//
//  GestureBinder.swift
//  iOSChallenge
//
//  Created by Jehoshaphat Allenlyon on 13/09/2025.
//

import UIKit
import RealityKit

/** 
 Centralizes gesture recognition setup for AR interactions.
 Provides consistent gesture handling across GestureManager and CharacterController.
 */
enum GestureBinder {
    
    /**
     Configures gesture recognizers for an ARView with optional handlers.
     
     - Parameters:
        - arView: Target ARView for gesture recognition
        - tap: Optional tap handler
        - swipe: Optional swipe handler with direction
        - pinch: Optional pinch handler with scale
        - pan: Optional pan handler with translation
     */
    static func bindGestures(
        on arView: ARView,
        tap: (() -> Void)? = nil,
        swipe: ((UISwipeGestureRecognizer.Direction) -> Void)? = nil,
        pinch: ((CGFloat) -> Void)? = nil,
        pan: ((CGPoint) -> Void)? = nil
    ) {
        if let tapHandler = tap {
            let sleeve = ClosureSleeve { _ in tapHandler() }
            let tapGR = UITapGestureRecognizer(target: sleeve,
                                               action: #selector(ClosureSleeve.invoke(_:)))
            tapGR.closureSleeve = sleeve
            arView.addGestureRecognizer(tapGR)
        }

        if let swipeHandler = swipe {
            let leftSleeve = ClosureSleeve { gr in
                if let s = gr as? UISwipeGestureRecognizer { swipeHandler(s.direction) }
            }
            let swipeLeft = UISwipeGestureRecognizer(target: leftSleeve,
                                                     action: #selector(ClosureSleeve.invoke(_:)))
            swipeLeft.direction = .left
            swipeLeft.closureSleeve = leftSleeve
            arView.addGestureRecognizer(swipeLeft)

            let rightSleeve = ClosureSleeve { gr in
                if let s = gr as? UISwipeGestureRecognizer { swipeHandler(s.direction) }
            }
            let swipeRight = UISwipeGestureRecognizer(target: rightSleeve,
                                                      action: #selector(ClosureSleeve.invoke(_:)))
            swipeRight.direction = .right
            swipeRight.closureSleeve = rightSleeve
            arView.addGestureRecognizer(swipeRight)
        }

        if let pinchHandler = pinch {
            let sleeve = ClosureSleeve { gr in
                if let p = gr as? UIPinchGestureRecognizer { pinchHandler(p.scale) }
            }
            let pinchGR = UIPinchGestureRecognizer(target: sleeve,
                                                   action: #selector(ClosureSleeve.invoke(_:)))
            pinchGR.closureSleeve = sleeve
            arView.addGestureRecognizer(pinchGR)
        }

        if let panHandler = pan {
            let sleeve = ClosureSleeve { gr in
                if let p = gr as? UIPanGestureRecognizer {
                    panHandler(p.translation(in: arView))
                }
            }
            let panGR = UIPanGestureRecognizer(target: sleeve,
                                               action: #selector(ClosureSleeve.invoke(_:)))
            panGR.closureSleeve = sleeve
            arView.addGestureRecognizer(panGR)
        }
    }
}

/** Retains closure references for gesture recognizer callbacks */
private class ClosureSleeve {
    let closure: (UIGestureRecognizer) -> Void

    init(_ closure: @escaping (UIGestureRecognizer) -> Void) {
        self.closure = closure
    }

    @objc func invoke(_ sender: UIGestureRecognizer) {
        closure(sender)
    }
}

private var sleeveKey: UInt8 = 0
private extension UIGestureRecognizer {
    /** Associates ClosureSleeve with gesture recognizer lifetime */
    var closureSleeve: ClosureSleeve? {
        get { objc_getAssociatedObject(self, &sleeveKey) as? ClosureSleeve }
        set { objc_setAssociatedObject(self, &sleeveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
