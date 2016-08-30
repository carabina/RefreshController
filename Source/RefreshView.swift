//
//  RefreshView.swift
//  RefreshController
//
//  Created by Edmond on 5/6/2559 BE.
//  Copyright © 2559 BE Edmond. All rights reserved.

//
import Foundation
import UIKit

let RefreshViewDefaultHeight: CGFloat = 44.0
let RefreshViewAnimationDuration: TimeInterval = 0.3


public protocol RefreshViewProtocol: class {
    func pullToUpdate(_ controller: PullToRefreshController, didChangeState state: RefreshState)
    func pullToUpdate(_ controller: PullToRefreshController, didChangePercentage percentate: CGFloat)
    func pullToUpdate(_ controller: PullToRefreshController, didSetEnable enable: Bool)
}

public class RefreshView: UIView {
    var state: RefreshState? {
        willSet {
            if newValue == .stop {
                indicator.stopAnimating()
            } else if newValue == .loading {
                indicator.startAnimating()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(indicator)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let boundsCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        indicator.center = boundsCenter
    }

    lazy var indicator: RefreshIndicator = {
        return RefreshIndicator(color: UIColor.lightGray)
    }()
}

extension RefreshView: RefreshViewProtocol {
    public func pullToUpdate(_ controller: PullToRefreshController, didChangeState state: RefreshState) {
        self.state = state
        setNeedsLayout()
    }

    public func pullToUpdate(_ controller: PullToRefreshController, didChangePercentage percentage: CGFloat) {
        indicator.setPercentage(percentage)
    }

    public func pullToUpdate(_ controller: PullToRefreshController, didSetEnable enable: Bool) {
        if !enable {
            state = .stop
        }
    }
}
