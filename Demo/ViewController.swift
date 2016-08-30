//
//  ViewController.swift
//  PullToRefreshController
//
//  Created by Edmond on 5/6/2559 BE.
//  Copyright © 2559 BE Edmond. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var tableView: UITableView!
    var dataSource = [NSDate]()
    var refreshController: PullToRefreshController!
    var loadMoreController: PullToRefreshController!

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Refresh", style: .Plain, target: self, action: #selector(startToRefresh))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "LoadMore", style: .Plain, target: self, action: #selector(startToLoadMore))

        configureDataSource()

        tableView = UITableView(frame: view.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        refreshController = PullToRefreshController(scrollView: tableView, direction: .Top)
        refreshController.triggerHandler = { [weak self] in
            self?.insertRow(true)
        }

        loadMoreController = PullToRefreshController(scrollView: tableView, direction: .Bottom)
        loadMoreController.triggerHandler = { [weak self] in
            self?.insertRow(false)
        }
        tableView.reloadData()
    }

    deinit {
        refreshController.scrollView = nil
        loadMoreController.scrollView = nil
    }

    private func configureDataSource() {
        for i in 0...9 {
            dataSource.append(NSDate(timeIntervalSinceNow: -NSTimeInterval(i) * 90))
        }
    }

    @objc private func startToRefresh() {
        refreshController.triggerRefresh(true)
    }

    @objc private func startToLoadMore() {
        loadMoreController.triggerRefresh(true)
    }

    private func insertRow(isTop: Bool) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] () -> Void in
            if isTop {
                self?.dataSource.insert(NSDate(), atIndex: 0)
            } else {
                self?.dataSource.append(NSDate())
            }
            self?.tableView.reloadData()
            if isTop {
                self?.refreshController.stopToRefresh(true)
            } else {
                self?.loadMoreController.stopToRefresh(true)
            }
        }
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellID = "cell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellID)
        let date = dataSource[indexPath.row]
        cell?.textLabel?.text = NSDateFormatter.localizedStringFromDate(date, dateStyle: .NoStyle, timeStyle: .MediumStyle)
        return cell!
    }
}
