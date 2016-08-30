//
//  PullToRefreshController.swift
//  RefreshController
//
//  Created by Edmond on 5/6/2559 BE.
//  Copyright © 2559 BE Edmond. All rights reserved.
//

import Foundation
import UIKit

public enum RefreshState {
    case stop, trigger, loading
}

public enum RefreshDirection {
    case top, left, bottom, right
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
    private var triggerTime: TimeInterval = 0
    private var originContentInset: CGFloat
    private var refresView: UIView!
    public var triggerHandler: RefreshHandler?
    public var minRefrehDuration: TimeInterval = 60
    
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
                if !newValue && self.state != .stop {
                    self.stopToRefresh(false, completion: nil)
                }
                if let refresView = refresView as? RefreshViewProtocol {
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
            if let refresView = refresView as? RefreshViewProtocol, state != newValue {
                refresView.pullToUpdate(self, didChangeState: newValue)
            }
        }
    }
    
    public init(scrollView: UIScrollView, direction: RefreshDirection) {
        self.state = .stop
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
        self.init(scrollView: scrollView, direction: .top)
    }
    
    private func addScrollObser(_ scrollView: UIScrollView?) {
        scrollView?.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        if direction.isLoadMore {
            scrollView?.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
            scrollView?.contentInset = initialContentInset
        } else {
            scrollView?.addObserver(self, forKeyPath: "contentInset", options: .new, context: nil)
        }
    }

    private func removeScrollObser(_ scrollView: UIScrollView?) {
        scrollView?.removeObserver(self, forKeyPath: "contentOffset")
        if direction.isLoadMore {
            scrollView?.removeObserver(self, forKeyPath: "contentSize")
        } else {
            scrollView?.removeObserver(self, forKeyPath: "contentInset")
        }
    }
    
    /// MAKR: Public method
    
    public func triggerRefresh(_ animated: Bool) {
        if !enable || state == .loading {
            return
        }
        state = .loading
        triggerTime = Date().timeIntervalSince1970
        if let refresView = refresView as? RefreshViewProtocol {
            refresView.pullToUpdate(self, didChangePercentage: 1.0)
        }
        let contentInset = adjustedContentInset
        let contentOffset = triggeredContentOffset(contentInset)
        let needUpdateInset = !(direction.isLoadMore && autoLoadMore)
        let duration = animated ? RefreshViewAnimationDuration : 0.0
        UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            self.scrollView?.contentOffset = contentOffset
            if needUpdateInset {
                self.scrollView?.contentInset = contentInset
            }
        }) { [weak self] finished in
            if finished { self?.triggerHandler?() }
        }
    }
    
    public func stopToRefresh(_ animated: Bool, completion: RefreshHandler? = nil) {
        if !enable || state == .stop {
            return
        }
        var delay = Date().timeIntervalSince1970 - triggerTime
        if delay < minRefrehDuration {
            delay = minRefrehDuration / 60
        }
        if delay > minRefrehDuration {
            delay = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: { [weak self] in
            if let sSelf = self {
                sSelf.state = .stop
                let contentInset = sSelf.adjustedContentInset
                let duration = animated ? RefreshViewAnimationDuration : 0.0
                UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState ], animations: {
                    sSelf.scrollView?.contentInset = contentInset
                }) { finished in
                    if finished { completion?() }
                }
            }
        })
    }
    
    public func setCustomView<T: RefreshViewProtocol>(_ customView: T) where T: UIView {
        if refresView.superview != nil {
            refresView.removeFromSuperview()
        }
        refresView = customView
        scrollView?.addSubview(refresView)
        layoutRefreshView()
    }
    
    /// MARK: Private Method
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        guard let keyPath = keyPath else {
            return
        }
        if keyPath == "contentOffset" {
            checkOffsets(change as [NSKeyValueChangeKey : AnyObject]?)
        } else if keyPath == "contentSize" {
            layoutRefreshView()
        } else if keyPath == "contentInset" && !direction.isLoadMore {
            if let changeValue = change?[NSKeyValueChangeKey.newKey] as? NSValue {
                let insets = changeValue.uiEdgeInsetsValue
                if originContentInset != insets.top {
                    originContentInset = insets.top
                }
                layoutRefreshView()
            }
        }
    }
    
    private func checkOffsets(_ change: [NSKeyValueChangeKey: AnyObject]?) {
        if !enable {
            return
        }
        guard let changeValue = change?[.newKey] as? NSValue, let scrollView = scrollView else {
            return
        }
        let contentOffset = changeValue.cgPointValue
        let refreshViewOffset = visibleDistance
        var contentInset = scrollView.contentInset
        var threshold: CGFloat = 0.0
        var checkOffset: CGFloat = 0.0
        var visibleOffset: CGFloat = 0
        switch direction {
        case .top:
            checkOffset = contentOffset.y
            threshold = -contentInset.top - refreshViewOffset
            visibleOffset = -checkOffset - contentInset.top
        case .left:
            checkOffset = contentOffset.x
            threshold = -contentInset.left - refreshViewOffset
            visibleOffset = -checkOffset - contentInset.left
        case .bottom:
            checkOffset = contentOffset.y
            threshold = scrollView.contentSize.height + contentInset.bottom - scrollView.bounds.size.height
        case .right:
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
        if state == .stop {
            var percentage = visibleOffset / refreshViewOffset
            percentage = min(1, max(0, percentage))
            if let refresView = refresView as? RefreshViewProtocol {
                refresView.pullToUpdate(self, didChangePercentage: percentage)
            }
        }
        if scrollView.isDragging {
            if isTriggered && state == .stop {
                state = .trigger
            } else if !isTriggered && state == .trigger {
                state = .stop
            }
        } else if state == .trigger {
            state = .loading
            triggerTime = Date().timeIntervalSince1970
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
            UIView.animate(withDuration: RefreshViewAnimationDuration,
                                       delay: 0,
                                       options: [.allowUserInteraction, .beginFromCurrentState],
                                       animations: {
                                        self.scrollView?.contentInset = contentInset
            }) { [weak self] finished in
                if let completion = self?.triggerHandler, finished {
                    completion()
                }
            }
        }
    }
    
    private func layoutRefreshView() {
        refresView.isHidden = !enable
        if state != .stop || !enable {
            return
        }
        guard let scrollView = scrollView else { return }
        var frame = refresView.frame
        var refresingOffset = visibleDistance
        if direction.isLoadMore {
            if direction == .bottom {
                refresingOffset = scrollView.contentSize.height
            } else if direction == .right {
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
        guard var contentInset = scrollView?.contentInset else { return UIEdgeInsets.zero }
        if enable && autoLoadMore {
            if direction == .bottom {
                contentInset.bottom += refresView.frame.height
            } else if direction == .right {
                contentInset.right += refresView.frame.width
            }
        } else {
            if direction == .bottom {
                contentInset.bottom = originContentInset
            } else if direction == .right {
                contentInset.right = originContentInset
            }
        }
        return contentInset
    }
    
    private var adjustedContentInset: UIEdgeInsets {
        guard var contentInset = scrollView?.contentInset else { return UIEdgeInsets.zero }
        let refresingOffset = visibleDistance
        let mutil: CGFloat = state == .stop ? -1 : 1
        switch direction {
        case .top:
            contentInset.top += refresingOffset * mutil
        case .left:
            contentInset.left += refresingOffset * mutil
        case .bottom:
            contentInset.bottom += refresingOffset * mutil
        case .right:
            contentInset.right += refresingOffset * mutil
        }
        return contentInset
    }
    
    func triggeredContentOffset(_ inset: UIEdgeInsets) -> CGPoint {
        guard let scrollView = scrollView else { return CGPoint.zero }
        switch direction {
        case .top:
            return CGPoint(x: 0, y: -inset.top)
        case .left:
            return CGPoint(x: -inset.left, y: 0)
        case .bottom:
            var offset = refresView.bounds.height
            offset = scrollView.contentSize.height - scrollView.bounds.height + offset
            return CGPoint(x: 0, y: offset)
        case .right:
            var offset = refresView.bounds.width
            offset = scrollView.contentSize.width - scrollView.bounds.width + offset
            return CGPoint(x: offset, y: 0)
        }
    }
    
    private var visibleDistance: CGFloat {
        switch direction {
        case .top, .bottom:
            return refresView.frame.height
        case .left, .right:
            return refresView.frame.width
        }
    }
    
    private var defalutRefreshView: RefreshView {
        let bounds = self.scrollView!.bounds 
        let size = direction.refreshViewSize(bounds)
        let view = RefreshView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        view.autoresizingMask = self.direction.isVertical ? .flexibleWidth : .flexibleHeight
        refresView = view
        return view
    }
}

extension RefreshDirection {
    var isLoadMore: Bool {
        return self == .bottom || self == .right
    }

    var isVertical: Bool {
        return self == .top || self == .bottom
    }
    func originContentInset(_ inset: UIEdgeInsets) -> CGFloat {
        switch self {
        case .top:
            return inset.top
        case .left:
            return inset.left
        case .bottom:
            return inset.bottom
        case .right:
            return inset.right
        }
    }
    
    func refreshViewSize(_ frame: CGRect) -> CGSize {
        switch self {
        case .top, .bottom:
            return CGSize(width: frame.width, height: RefreshViewDefaultHeight)
        case .left, .right:
            return CGSize(width: RefreshViewDefaultHeight, height: frame.height)
        }
    }
}
