//
//  DBTests.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import XCTest
import RealmSwift
import Freddy

class DBTests: XCTestCase {
  var feed: Feed!
  
  let dbc = DB.Configuration(realmConfig: Realm.Configuration(
    inMemoryIdentifier: "DBTests",
    deleteRealmIfMigrationNeeded: true
    ))
  
  override func setUp() {
    super.setUp()
    
    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false
    
    let data: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "modification_time": "2016-04-03T19:38:03.33Z",
      "items": [
        "56d65493c8747268f348438c"
      ]
    ]
    
    let json = JSON.Dictionary(data)
    feed = try! Feed(json: json)

    let db = try! DB(configuration: dbc)
    try! db.write {
      db.add(self.feed)
    }
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testAddNotificationBlockForFeedUpdate() {
    let expectation = expectationWithDescription("whatever")
    
    let db = try! DB(configuration: self.dbc)
    db.addNotificationBlockForFeedUpdate(feed) {
      expectation.fulfill()
    }
    
    let q = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
    dispatch_async(q) {
      let db = try! DB(configuration: self.dbc)
      let feed = db.feedWithID("56d65493c8747268f348438b")
      try! db.write {
        feed?.author = "Something"
      }
    }
    
    waitForExpectationsWithTimeout(1) { err in
      if err != nil { XCTFail("Expectation was not fulfilled") }
    }
  }
}
