//
//  JoystickView.swift
//  MobileTraining2Concept
//
//  Created by Lukas Schmidt on 01.08.19.
//  Copyright © 2019 Lukas Schmidt. All rights reserved.
//

import UIKit

class JoystickView: UIControl {
    
    var outlineShape: CAShapeLayer!
    var stickShape: CAShapeLayer!
    
    let deadZone: (Float, Float) = (0.25, 0.25)
    
    var value: (Float, Float) {
        get {
            let scale = self.bounds.width / 2

            var x = Float((stickShape.position.x - self.bounds.center.x) / scale)
            var y = Float((stickShape.position.y - self.bounds.center.y) / scale)
            if abs(x) < deadZone.0 {
                x = 0
            }
            if abs(y) < deadZone.1 {
                y = 0
            }

            return clamp(vector: (x, y), toLength: 1.0)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup(){
        outlineShape = CAShapeLayer()
        outlineShape!.path = CGPath(ellipseIn: bounds, transform: nil)
        outlineShape!.strokeColor = UIColor.white.cgColor
        outlineShape!.lineWidth = 2.0
        outlineShape!.opacity = 1.0
        outlineShape!.fillColor = UIColor.white.withAlphaComponent(0.25).cgColor
        self.layer.addSublayer(outlineShape!)
        
        stickShape = CAShapeLayer()
        stickShape!.fillColor = UIColor.white.cgColor
        let stickSize: CGFloat = 48
        let stickRect = CGRect(x: -stickSize / 2, y: -stickSize / 2, width: stickSize, height: stickSize)
        stickShape!.path = CGPath(ellipseIn: stickRect, transform: nil)
        stickShape.shadowPath = stickShape.path
        self.layer.addSublayer(stickShape)
    }
    
    override func layoutSubviews() {
        outlineShape?.path = CGPath(ellipseIn: bounds, transform: nil)
        stickShape.position = self.bounds.center
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        stickShape.position = touches.first!.location(in: self)
        self.sendActions(for: .valueChanged)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Disable actions to remove the default 0.1s animation for moving the layer.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stickShape.position = touches.first!.location(in: self)
        CATransaction.commit()
        self.sendActions(for: .valueChanged)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // This is implicitly animated.
        self.stickShape.position = self.bounds.center
        self.sendActions(for: .valueChanged)
    }
    
}


extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}

/// Clamps a vector to have at most the specified length.
private func clamp(vector: (Float, Float), toLength length: Float) -> (Float, Float) {
    let magnitude = sqrt(vector.1 * vector.1 + vector.0 * vector.0)
    let angle = atan2(vector.1, vector.0)
    let newMagnitude = min(magnitude, 1.0)
    let newVector = (cos(angle) * newMagnitude, sin(angle) * newMagnitude)
    return newVector
}
