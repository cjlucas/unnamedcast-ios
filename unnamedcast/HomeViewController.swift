//
//  HomeViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 9/12/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit

class FeedViewControllerDataSource<T: CollectionType where T.Index.Distance == Int>: NSObject, UITableViewDataSource{
  var items: T
  var cellConfigurator: (FeedTableViewCell) -> ()
  
  init(items: T, cellConfigurator: (FeedTableViewCell) -> ()) {
    self.items = items
    self.cellConfigurator = cellConfigurator
  }
  
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("FeedTableViewCell")! as! FeedTableViewCell
    cellConfigurator(cell)
    return cell
  }
}

class HomeViewController: UIPageViewController, UIPageViewControllerDataSource {
  var vcs: [UIViewController] = []
  
  private lazy var sb = UIStoryboard(name: "Main", bundle: nil)
  
  func loadVC() -> FeedTableViewController {
    let vc = sb.instantiateViewControllerWithIdentifier("FeedViewController") as! FeedTableViewController
    vc.loadView()
    return vc
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    dataSource = self
   
    var vc = loadVC()
    vc.headerTitleLabel.text = "Podcasts"
    vcs.append(vc)

    vc = loadVC()
    vc.headerTitleLabel.text = "Playlists"
    vcs.append(vc)
    
    setViewControllers([vcs.first!], direction: .Forward, animated: true, completion: nil)
  }
  
  func viewControllerAt(distance: Int, from viewController: UIViewController) -> UIViewController? {
    guard var idx = vcs.indexOf(viewController) else { return nil }
   
    idx += distance
    return idx >= 0 && idx < vcs.count
      ? vcs[idx]
      : nil
  }
  
  func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
    return viewControllerAt(1, from: viewController)
  }
  
  func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
    return viewControllerAt(-1, from: viewController)
  }
}
