//
//  RefreshIndicator.swift
//  PullToRefreshController
//
//  Created by Edmond on 5/6/2559 BE.
//  Copyright © 2559 BE Edmond. All rights reserved.
//

import Foundation
import UIKit
import QuartzCore

private let RefreshAnimationKey = "spinkit-anim";

@objc public class RefreshIndicator: UIView {
    public var color: UIColor {
        willSet {
            layer.sublayers?.forEach{ $0.backgroundColor = newValue.CGColor }
        }
    }
    public var hideWhenStopped: Bool
    private var stopped: Bool

    public init(color: UIColor) {
        self.hideWhenStopped = true
        self.stopped = true
        self.color = color
        super.init(frame: CGRect.zero)
        sizeToFit()
        layer.addSublayer(cycleLayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplicationDidEnterBackgroundNotification, object: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    public func isAnimating() -> Bool {
        return !stopped
    }

    public func startAnimating() {
        if stopped {
            stopped = false
            resumeLayers()
        }
    }

    public func stopAnimating() {
        if !stopped {
            if hideWhenStopped {
                UIView.animateWithDuration(RefreshViewAnimationDuration, animations: {
                    self.cycleLayer.transform = CATransform3DMakeScale(0.5, 0.5, 0.0)
                    self.cycleLayer.opacity = 0
                })
            }
            pauseLayers()
            stopped = true
        }
    }

    public func setPercentage(percentage: CGFloat) {
        if !stopped {
            cycleLayer.transform = CATransform3DMakeScale(percentage, percentage, 0.0)
            cycleLayer.opacity = Float(percentage)
        }
    }

    public override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(30, 30)
    }

    @objc private func applicationWillEnterForeground() {
        stopped ? pauseLayers() : resumeLayers()
    }

    @objc private func applicationDidEnterBackground() {
        pauseLayers()
    }

    private func pauseLayers() {
        cycleLayer.removeAnimationForKey(RefreshAnimationKey)
    }

    private func resumeLayers() {
        let beginTime = CACurrentMediaTime()

        cycleLayer.opacity = 1
        cycleLayer.transform = CATransform3DMakeScale(1.0, 1.0, 0.0)

        let scaleAnim = CAKeyframeAnimation(keyPath: "transform")
        scaleAnim.values = [
            NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 0.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(0.5, 0.5, 0.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(0.2, 0.2, 0.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(0.5, 0.5, 0.0)),
            NSValue(CATransform3D: CATransform3DMakeScale(1.0, 1.0, 0.0)),
        ]
        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [
            1.0, 0.5, 0.0, 0.5, 1.0
        ]

        let animGroup = CAAnimationGroup()
        animGroup.removedOnCompletion = false
        animGroup.beginTime = beginTime
        animGroup.repeatCount = HUGE
        animGroup.duration = 1.5
        animGroup.animations = [scaleAnim, opacityAnim]
        animGroup.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        cycleLayer.addAnimation(animGroup, forKey: RefreshAnimationKey)
    }

    private lazy var cycleLayer: CALayer = {
        let layer = CALayer()
        layer.frame = self.bounds
        layer.backgroundColor = self.color.CGColor
        layer.anchorPoint = CGPointMake(0.5, 0.5)
        layer.opacity = 1.0
        layer.cornerRadius = CGRectGetHeight(layer.bounds) * 0.5
        layer.transform = CATransform3DMakeScale(0, 0, 0.0)
        return layer
    }()
}
