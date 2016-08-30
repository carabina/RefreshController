//
//  RefreshView.swift
//  PullToRefreshController
//
//  Created by Edmond on 5/6/2559 BE.
//  Copyright © 2559 BE Edmond. All rights reserved.

//
import Foundation
import UIKit

let RefreshViewDefaultHeight: CGFloat = 44.0
let RefreshViewAnimationDuration: NSTimeInterval = 0.3


public protocol RefreshViewProtocol: class {
    func pullToUpdate(controller: PullToRefreshController, didChangeState state: RefreshState)
    func pullToUpdate(controller: PullToRefreshController, didChangePercentage percentate: CGFloat)
    func pullToUpdate(controller: PullToRefreshController, didSetEnable enable: Bool)
}

public class RefreshView: UIView {
    var state: RefreshState? {
        willSet {
            if newValue == .Stop {
                indicator.stopAnimating()
            } else if newValue == .Loading {
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
        let boundsCenter = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))
        indicator.center = boundsCenter
    }

    private lazy var indicator: RefreshIndicator = {
        return RefreshIndicator(color: UIColor.lightGrayColor())
    }()
}

extension RefreshView: RefreshViewProtocol {
    public func pullToUpdate(controller: PullToRefreshController, didChangeState state: RefreshState) {
        self.state = state
        setNeedsLayout()
    }

    public func pullToUpdate(controller: PullToRefreshController, didChangePercentage percentage: CGFloat) {
        indicator.setPercentage(percentage)
    }

    public func pullToUpdate(controller: PullToRefreshController, didSetEnable enable: Bool) {
        if !enable {
            state = .Stop
        }
    }
}
