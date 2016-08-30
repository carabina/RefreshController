//
//  PullToRefreshController.swift
//  PullToRefreshController
//
//  Created by Edmond on 5/6/2559 BE.
//  Copyright © 2559 BE Edmond. All rights reserved.
//

import Foundation
import UIKit

public enum RefreshState {
    case Stop, Trigger, Loading
}

public enum RefreshDirection {
    case Top, Left, Bottom, Right
}

public typealias RefreshHandler = () -> ()

public class PullToRefreshController: NSObject {

    public weak var scrollView: UIScrollView? {
        didSet {
            removeScrollObser(oldValue)
            addScrollObser(scrollView)
        }
    }
    private(set) var direction: RefreshDirection
    private var triggerTime: NSTimeInterval = 0
    private var originContentInset: CGFloat
    private var refresView: UIView!
    public var triggerHandler: RefreshHandler?
    public var minRefrehDuration: NSTimeInterval = 60

    // which work for RefreshDirection isLoadMore
    public var autoLoadMore: Bool {
        willSet {
            if autoLoadMore != newValue {
                scrollView?.contentInset = initialContentInset
            }
        }
    }
    /**
     *  When pull To Refresh
     *  Set to false, if need user dragging to trigger load more action. Default is true.
     *
     *  When pull To LoadMore
     *  Set to true, which means customView is below scrollview content,
     *  Otherise `customView` below `scrollView?.contentInset.bottom`.
     */
    public var showRefreshControllerAboveContent = false

    private var enable: Bool {
        willSet {
            if enable != newValue {
                if !newValue && self.state != .Stop {
                    self.stopToRefresh(false, completion: nil)
                }
                if let refresView = refresView as? protocol<RefreshViewProtocol> {
                    refresView.pullToUpdate(self, didSetEnable: newValue)
                }
                self.enable = newValue
                self.layoutRefreshView()
                self.scrollView?.contentInset = initialContentInset
            }
        }
    }
    private(set) var state: RefreshState {
        willSet(newValue) {
            if let refresView = refresView as? protocol<RefreshViewProtocol> where state != newValue {
                refresView.pullToUpdate(self, didChangeState: newValue)
            }
        }
    }

    public init(scrollView: UIScrollView, direction: RefreshDirection) {
        self.state = .Stop
        self.enable = true
        self.direction = direction
        self.scrollView = scrollView
        self.autoLoadMore = direction.isLoadMore
        self.originContentInset = direction.originContentInset(scrollView.contentInset)
        super.init()
        setCustomView(defalutRefreshView)
        addScrollObser(scrollView)
    }

    public convenience init(scrollView: UIScrollView) {
        self.init(scrollView: scrollView, direction: .Top)
    }

    private func addScrollObser(scrollView: UIScrollView?) {
        scrollView?.addObserver(self, forKeyPath: "contentOffset", options: .New, context: nil)
        if direction.isLoadMore {
            scrollView?.addObserver(self, forKeyPath: "contentSize", options: .New, context: nil)
            scrollView?.contentInset = initialContentInset
        } else {
            scrollView?.addObserver(self, forKeyPath: "contentInset", options: .New, context: nil)
        }
    }

    private func removeScrollObser(scrollView: UIScrollView?) {
        scrollView?.removeObserver(self, forKeyPath: "contentOffset")
        if direction.isLoadMore {
            scrollView?.removeObserver(self, forKeyPath: "contentSize")
        } else {
            scrollView?.removeObserver(self, forKeyPath: "contentInset")
        }
    }

    /// MAKR: Public method

    public func triggerRefresh(animated: Bool) {
        if !enable || state == .Loading {
            return
        }
        state = .Loading
        triggerTime = NSDate().timeIntervalSince1970
        if let refresView = refresView as? protocol<RefreshViewProtocol> {
            refresView.pullToUpdate(self, didChangePercentage: 1.0)
        }
        let contentInset = adjustedContentInset
        let contentOffset = triggeredContentOffset(contentInset)
        let needUpdateInset = !(direction.isLoadMore && autoLoadMore)
        let duration = animated ? RefreshViewAnimationDuration : 0.0
        UIView.animateWithDuration(duration, delay: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {
            self.scrollView?.contentOffset = contentOffset
            if needUpdateInset {
                self.scrollView?.contentInset = contentInset
            }
        }) { [weak self] finished in
            if finished { self?.triggerHandler?() }
        }
    }

    public func stopToRefresh(animated: Bool, completion: RefreshHandler? = nil) {
        if !enable || state == .Stop {
            return
        }
        var delay = NSDate().timeIntervalSince1970 - triggerTime
        if delay < minRefrehDuration {
            delay = minRefrehDuration / 60
        }
        if delay > minRefrehDuration {
            delay = 0
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
            if let sSelf = self {
                sSelf.state = .Stop
                let contentInset = sSelf.adjustedContentInset
                let duration = animated ? RefreshViewAnimationDuration : 0.0
                UIView.animateWithDuration(duration, delay: 0, options: [.AllowUserInteraction, .BeginFromCurrentState ], animations: {
                    sSelf.scrollView?.contentInset = contentInset
                }) { finished in
                    if finished { completion?() }
                }
            }
        }
    }

    public func setCustomView<T: RefreshViewProtocol where T: UIView>(customView: T) {
        if refresView.superview != nil {
            refresView.removeFromSuperview()
        }
        refresView = customView
        scrollView?.addSubview(refresView)
        layoutRefreshView()
    }

    /// MARK: Private Method

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard let keyPath = keyPath else {
            return
        }
        if keyPath == "contentOffset" {
            checkOffsets(change)
        } else if keyPath == "contentSize" {
            layoutRefreshView()
        } else if keyPath == "contentInset" && !direction.isLoadMore {
            if let changeValue = change?[NSKeyValueChangeNewKey] as? NSValue {
                let insets = changeValue.UIEdgeInsetsValue()
                if originContentInset != insets.top {
                    originContentInset = insets.top
                }
                layoutRefreshView()
            }
        }
    }

    private func checkOffsets(change: [String: AnyObject]?) {
        if !enable {
            return
        }
        guard let changeValue = change?[NSKeyValueChangeNewKey] as? NSValue, scrollView = scrollView else {
            return
        }
        let contentOffset = changeValue.CGPointValue()
        let refreshViewOffset = visibleDistance
        var contentInset = scrollView.contentInset
        var threshold: CGFloat = 0.0
        var checkOffset: CGFloat = 0.0
        var visibleOffset: CGFloat = 0
        switch direction {
        case .Top:
            checkOffset = contentOffset.y
            threshold = -contentInset.top - refreshViewOffset
            visibleOffset = -checkOffset - contentInset.top
        case .Left:
            checkOffset = contentOffset.x
            threshold = -contentInset.left - refreshViewOffset
            visibleOffset = -checkOffset - contentInset.left
        case .Bottom:
            checkOffset = contentOffset.y
            threshold = scrollView.contentSize.height + contentInset.bottom - scrollView.bounds.size.height
        case .Right:
            checkOffset = contentOffset.x
            threshold = scrollView.contentSize.width + contentInset.right - scrollView.bounds.size.width
        }
        var isTriggered = checkOffset <= threshold
        if direction.isLoadMore {
            if !autoLoadMore {
                threshold += refreshViewOffset
            }
            visibleOffset = checkOffset - threshold + refreshViewOffset
            if threshold < 0 {
                isTriggered = false
            } else {
                isTriggered = checkOffset >= threshold
            }
        }

        // NSLog("checkOffset \(checkOffset), threshold \(threshold), visibleOffset \(visibleOffset)")

        if state == .Stop {
            var percentage = visibleOffset / refreshViewOffset
            percentage = min(1, max(0, percentage))
            if let refresView = refresView as? protocol<RefreshViewProtocol> {
                refresView.pullToUpdate(self, didChangePercentage: percentage)
            }
        }
        if scrollView.dragging {
            if isTriggered && state == .Stop {
                state = .Trigger
            } else if !isTriggered && state == .Trigger {
                state == .Stop
            }
        } else if state == .Trigger {
            state = .Loading
            triggerTime = NSDate().timeIntervalSince1970
            if autoLoadMore {
                self.scrollView?.contentInset = adjustedContentInset
                triggerHandler?()
                return
            }
            let needUpdateInset = !(direction.isLoadMore && autoLoadMore)
            if !needUpdateInset {
                return
            }
            contentInset = adjustedContentInset
            UIView.animateWithDuration(RefreshViewAnimationDuration,
                                       delay: 0,
                                       options: [.AllowUserInteraction, .BeginFromCurrentState],
                                       animations: {
                                        self.scrollView?.contentInset = contentInset
            }) { [weak self] finished in
                if let completion = self?.triggerHandler where finished {
                    completion()
                }
            }
        }
    }

    private func layoutRefreshView() {
        refresView.hidden = !enable
        if state != .Stop || !enable {
            return
        }
        guard let scrollView = scrollView else { return }
        var frame = refresView.frame
        var refresingOffset = visibleDistance
        if direction.isLoadMore {
            if direction == .Bottom {
                refresingOffset = scrollView.contentSize.height
            } else if direction == .Right {
                refresingOffset = scrollView.contentSize.width
            }
            if !showRefreshControllerAboveContent {
                refresingOffset += originContentInset
            }
        } else {
            refresingOffset *= -1
            if showRefreshControllerAboveContent {
                refresingOffset -= originContentInset
            }
        }
        if direction.isVertical {
            frame.origin.y = refresingOffset
        } else {
            frame.origin.x = refresingOffset
        }
        refresView.frame = frame
    }

    private var initialContentInset: UIEdgeInsets {
        guard var contentInset = scrollView?.contentInset else { return UIEdgeInsetsZero }
        if enable && autoLoadMore {
            if direction == .Bottom {
                contentInset.bottom += CGRectGetHeight(refresView.frame)
            } else if direction == .Right {
                contentInset.right += CGRectGetWidth(refresView.frame)
            }
        } else {
            if direction == .Bottom {
                contentInset.bottom = originContentInset
            } else if direction == .Right {
                contentInset.right = originContentInset
            }
        }
        return contentInset
    }

    private var adjustedContentInset: UIEdgeInsets {
        guard var contentInset = scrollView?.contentInset else { return UIEdgeInsetsZero }
        let refresingOffset = visibleDistance
        let mutil: CGFloat = state == .Stop ? -1 : 1
        switch direction {
        case .Top:
            contentInset.top += refresingOffset * mutil
        case .Left:
            contentInset.left += refresingOffset * mutil
        case .Bottom:
            contentInset.bottom += refresingOffset * mutil
        case .Right:
            contentInset.right += refresingOffset * mutil
        }
        return contentInset
    }

    func triggeredContentOffset(inset: UIEdgeInsets) -> CGPoint {
        guard let scrollView = scrollView else { return CGPoint.zero }
        switch direction {
        case .Top:
            return CGPointMake(0, -inset.top)
        case .Left:
            return CGPointMake(-inset.left, 0)
        case .Bottom:
            var offset = CGRectGetHeight(refresView.bounds)
            offset = scrollView.contentSize.height - scrollView.bounds.height + offset
            return CGPointMake(0, offset)
        case .Right:
            var offset = CGRectGetWidth(refresView.bounds)
            offset = scrollView.contentSize.width - scrollView.bounds.width + offset
            return CGPointMake(offset, 0)
        }
    }

    private var visibleDistance: CGFloat {
        switch direction {
        case .Top, .Bottom:
            return CGRectGetHeight(refresView.frame)
        case .Left, .Right:
            return CGRectGetWidth(refresView.frame)
        }
    }

    private var defalutRefreshView: RefreshView {
        let bounds = self.scrollView?.bounds ?? CGRectZero
        let size = direction.refreshViewSize(bounds)
        let view = RefreshView(frame: CGRectMake(0, 0, size.width, size.height))
        view.autoresizingMask = self.direction.isVertical ? .FlexibleWidth : .FlexibleHeight
        refresView = view
        return view
    }
}

extension RefreshDirection {
    var isLoadMore: Bool {
        return self == .Bottom || self == .Right
    }

    var isVertical: Bool {
        return self == .Top || self == .Bottom
    }

    func originContentInset(inset: UIEdgeInsets) -> CGFloat {
        switch self {
        case .Top:
            return inset.top
        case .Left:
            return inset.left
        case .Bottom:
            return inset.bottom
        case .Right:
            return inset.right
        }
    }

    func refreshViewSize(frame: CGRect) -> CGSize {
        switch self {
        case .Top, .Bottom:
            return CGSizeMake(CGRectGetWidth(frame), RefreshViewDefaultHeight)
        case .Left, .Right:
            return CGSizeMake(RefreshViewDefaultHeight, CGRectGetHeight(frame))
        }
    }
}
