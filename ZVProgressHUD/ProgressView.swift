//
//  ZVProgressView.swift
//  ZVProgressHUD
//
//  Created by zevwings on 2017/7/13.
//  Copyright © 2017年 zevwings. All rights reserved.
//

import UIKit

class ProgressView: UIView {
    
    var strokeWidth: CGFloat = 3.0 {
        didSet {
            foregroundLayer.lineWidth = strokeWidth
            backgroundLayer.lineWidth = strokeWidth
        }
    }
    
    var progress: Float = 0.0 {
        didSet {
            foregroundLayer.strokeEnd = CGFloat(progress)
            setNeedsDisplay()
        }
    }

    private lazy var foregroundLayer: CAShapeLayer = { [unowned self] in
        
        let foregroundLayer = CAShapeLayer()
        foregroundLayer.lineCap = kCALineCapRound
        foregroundLayer.lineWidth = self.strokeWidth
        foregroundLayer.frame = self.bounds
        foregroundLayer.fillColor = UIColor.clear.cgColor
        foregroundLayer.strokeColor = UIColor.white.cgColor
        foregroundLayer.strokeStart = 0.0
        foregroundLayer.strokeEnd = 0.0

        return foregroundLayer
    }()
    
    private lazy var backgroundLayer: CAShapeLayer = { [unowned self] in
        
        let backgroundLayer = CAShapeLayer()
        backgroundLayer.lineCap = kCALineCapRound
        backgroundLayer.lineWidth = self.strokeWidth
        backgroundLayer.frame = self.bounds
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = UIColor.black.cgColor
        backgroundLayer.strokeStart = 0.0
        backgroundLayer.strokeEnd = 1.0
        
        return backgroundLayer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.addSublayer(backgroundLayer)
        layer.addSublayer(foregroundLayer)
        layer.masksToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        backgroundColor = .clear
        
        let rect = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        foregroundLayer.frame = rect
        backgroundLayer.frame = rect
        
        prepare()
    }
    
    private func prepare() {
        
//        transform = CGAffineTransformMakeRotation(angle)
//        layer.transform = CGAffineTransform(rotationAngle: 1.5)
        
        let arcCenter: CGPoint = .init(x: self.frame.width / 2.0, y: self.frame.height / 2.0)
        let radius: CGFloat = (min(self.bounds.width, self.bounds.height) - self.strokeWidth * 2) / 2
        let startAngle = CGFloat( -0.5 * Double.pi)
        let endAngle = CGFloat(1.5 * Double.pi)

        let path = UIBezierPath(arcCenter: arcCenter, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true).cgPath
        foregroundLayer.path = path
        backgroundLayer.path = path
    }
    
    func updateProgress(_ progress: Float) {
        
//        var v = value
//        if value > 1.0 { v = 1.0 }
//        if value < 0.0 { v = 0.0 }
    
        CATransaction.begin()
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
        CATransaction.setAnimationDuration(0.15)
        foregroundLayer.strokeEnd = CGFloat(progress)
        CATransaction.commit()
    }
}
