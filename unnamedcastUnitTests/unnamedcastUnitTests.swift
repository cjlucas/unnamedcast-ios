//
//  unnamedcastUnitTests.swift
//  unnamedcastUnitTests
//
//  Created by Christopher Lucas on 3/12/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import XCTest
import Alamofire
import Freddy
import PromiseKit
import RealmSwift

func mockJSONRequester(responses: [JSON]) -> JSONRequester {
  var resps = responses
  
  
  return { (req: URLRequestConvertible) -> Promise<JSONResponse> in
    let okResp = NSHTTPURLResponse(URL: req.URLRequest.URL!, statusCode: 200, HTTPVersion: nil, headerFields: nil)!
    
    return Promise { fulfill, reject in
      guard resps.count > 0 else { fatalError("No responses left to return") }
      fulfill((req: req.URLRequest, resp: okResp, json: resps.removeFirst()))
    }
  }
}
  
func loadFixture(name: String, ofType: String) -> NSData {
  let fpath = NSBundle(forClass: unnamedcastUnitTests.self).pathForResource(name, ofType: ofType)
  return NSData(contentsOfFile: fpath!)!
}

class unnamedcastUnitTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testFeedFromJSON() {
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
    
    do {
      let f = try Feed(json: json)
      XCTAssertEqual(f.id, try! data["id"]!.string())
      XCTAssertEqual(f.title, try! data["title"]!.string())
      XCTAssertEqual(f.author, try! data["author"]!.string())
      XCTAssertEqual(f.imageUrl, try! data["image_url"]!.string())
      
      XCTAssertEqual(f.itemIds.count, 1)
    } catch let e {
      XCTFail("Failed JSON deserialization \(e)")
    }
  }
  
  func testItemFromJSON() {
    let data: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "guid": "guid goes here",
      "link": "link goes here",
      "title": "title goes here",
      "author": "author goes here",
      "description": "description",
      "duration": 5,
      "size": 100,
      "publication_time": "doesnt matter",
      "url": "http://google.com/podcast.mp3",
      "image_url": "http://google.com/404.png",
      "modification_time": "2016-04-03T19:38:03.33Z"
    ]
    
    let json = JSON.Dictionary(data)
    
    do {
      let item = try Item(json: json)
      XCTAssertEqual(item.guid, try! json["guid"]!.string())
      XCTAssertEqual(item.link, try! json["link"]!.string())
      XCTAssertEqual(item.title, try! json["title"]!.string())
      XCTAssertEqual(item.author, try! json["author"]!.string())
      XCTAssertEqual(item.desc, try! json["description"]!.string())
      XCTAssertEqual(item.duration, try! json["duration"]!.int())
      XCTAssertEqual(item.size, try! json["size"]!.int())
      XCTAssertEqual(item.pubDate, try! json["publication_time"]!.string())
      XCTAssertEqual(item.audioURL, try! json["url"]!.string())
      XCTAssertEqual(item.imageURL, try! json["image_url"]!.string())
      print(item.modificationDate)
      
    } catch let e {
      XCTFail("Failed JSON deserialization \(e)")
    }
  }

  // TODO: move this test to its own class
  func testInitialUserFeedSync() {
    // TODO: Waiting for Freddy to support proper literal syntax
    // https://github.com/bignerdranch/Freddy/issues/150
    
    let resp1: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "username": "chris@cjlucas.net",
      "feeds": ["56d65493c8747268f348438b"],
      "states": [],
    ]
    
    let resp2: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "modification_time": "2016-04-03T19:38:03.33Z",
      "items": []
    ]

    let resp3: [JSON] = []
    
    
    let responses = [JSON.Dictionary(resp1), JSON.Dictionary(resp2), JSON.Array(resp3)]
    let rc = Realm.Configuration(inMemoryIdentifier: "testInitialUserFeedSync")
    let conf = DataStore.Configuration(realmConfig: rc, requestJSON: mockJSONRequester(responses))
    let ds = DataStore(configuration: conf)
    ds.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
    
    ds.syncUserFeeds().always {
      expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(ds.feeds.count, 1)
      XCTAssertEqual(ds.feeds.first!.items.count, 0)
    }
  }
  
  func testUserFeedSyncWithNewItems() {
    // TODO: Waiting for Freddy to support proper literal syntax
    // https://github.com/bignerdranch/Freddy/issues/150
   
    // GET /api/users/56d65493c8747268f348438b
    let resp1: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "username": "chris@cjlucas.net",
      "feeds": ["56d65493c8747268f348438b"],
      "states": [],
    ]
    
    // GET /api/feeds/56d65493c8747268f348438b
    let resp2: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "modification_time": "2016-04-03T19:38:03.33Z",
      "items": []
    ]
    
    let resp3: [JSON] = []

    // GET /api/users/56d65493c8747268f348438b
    let resp4 = resp1

    // GET /api/feeds/56d65493c8747268f348438b
    let resp5: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "modification_time": "2016-04-03T19:38:03.34Z",
      "items": [
        "56d65493c8747268f348438c",
      ]
    ]
    
    let resp6: [JSON] = [
      [
        "id": "56d65493c8747268f348438c",
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title goes here",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png",
        "modification_time": "2016-04-03T19:38:03.33Z"
      ]
    ]
 
    let responses = [
      JSON.Dictionary(resp1),
      JSON.Dictionary(resp2),
      JSON.Array(resp3),
      JSON.Dictionary(resp4),
      JSON.Dictionary(resp5),
      JSON.Array(resp6),
    ]
    let rc = Realm.Configuration(inMemoryIdentifier: "testUserFeedSyncWithNewItems")
    let conf = DataStore.Configuration(realmConfig: rc, requestJSON: mockJSONRequester(responses))
    let ds = DataStore(configuration: conf)
    ds.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
  
    ds.syncUserFeeds().then {
      return ds.syncUserFeeds()
    }.always {
        expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(ds.feeds.count, 1)
      XCTAssertEqual(ds.items.count, 1)
      XCTAssertEqual(ds.feeds.first!.items.count, 1)
    }
  }

  func testUserFeedSyncWithUpdatedItems() {
    // TODO: Waiting for Freddy to support proper literal syntax
    // https://github.com/bignerdranch/Freddy/issues/150
    
    let resp1: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "username": "chris@cjlucas.net",
      "feeds": ["56d65493c8747268f348438b"],
      "states": [],
    ]
    
    let resp2: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "modification_time": "2016-04-03T19:38:03.34Z",
      "items": [
        "56d65493c8747268f348438c",
      ]
    ]
    
    let resp3: [JSON] = [
      [
        "id": "56d65493c8747268f348438c",
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title1",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png",
        "modification_time": "2016-04-03T19:38:03.33Z"
      ]
    ]
    
    let resp4 = resp1
    let resp5 = resp2

    let resp6: [JSON] = [
      [
        "id": "56d65493c8747268f348438c",
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title2",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png",
        "modification_time": "2016-04-03T19:38:04.33Z"
      ]
    ]
    
    let responses = [
      JSON.Dictionary(resp1),
      JSON.Dictionary(resp2),
      JSON.Array(resp3),
      JSON.Dictionary(resp4),
      JSON.Dictionary(resp5),
      JSON.Array(resp6),
    ]

    let rc = Realm.Configuration(inMemoryIdentifier: "testUserFeedSyncWithUpdatedItems")
    let conf = DataStore.Configuration(realmConfig: rc, requestJSON: mockJSONRequester(responses))
    let ds = DataStore(configuration: conf)
    ds.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
    
    ds.syncUserFeeds().then {
      return ds.syncUserFeeds()
    }.always {
      expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(ds.feeds.count, 1)
      XCTAssertEqual(ds.items.count, 1)
      XCTAssertEqual(ds.feeds.first!.items.count, 1)
      
      let item = ds.feeds.first!.items.first!
      XCTAssertEqual(item.title, "title2")
    }
  }
  
  func testUserFeedSyncWithNewFeed() {
    // TODO: Waiting for Freddy to support proper literal syntax
    // https://github.com/bignerdranch/Freddy/issues/150
    
    let resp1: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "username": "chris@cjlucas.net",
      "feeds": ["56d65493c8747268f348438b"],
      "states": [],
    ]
    
    let resp2: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "modification_time": "2016-04-03T19:38:03.34Z",
      "items": [
        "56d65493c8747268f348438c",
      ]
    ]
    
    let resp3: [JSON] = [
      [
        "id": "56d65493c8747268f348438c",
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title1",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png",
        "modification_time": "2016-04-03T19:38:03.33Z"
      ]
    ]

    let resp4: [String: JSON] = [
      "id": "56d65493c8747268f348438b",
      "username": "chris@cjlucas.net",
      "feeds": ["56d65493c8747268f348438b", "56d65493c8747268f348438c"],
      "states": [],
    ]
    
    let resp5 = resp2
    let resp6 = resp3
    
    let resp7: [String: JSON] = [
      "id": "56d65493c8747268f348438c",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "modification_time": "2016-04-03T19:38:03.34Z",
      "items": [
        "56d65493c8747268f348438d",
      ]
    ]
    
    let resp8: [JSON] = [
      [
        "id": "56d65493c8747268f348438d",
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title2",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png",
        "modification_time": "2016-04-03T19:38:03.33Z",
      ]
    ]
    
    let responses = [
      JSON.Dictionary(resp1),
      JSON.Dictionary(resp2),
      JSON.Array(resp3),
      JSON.Dictionary(resp4),
      JSON.Dictionary(resp5),
      JSON.Array(resp6),
      JSON.Dictionary(resp7),
      JSON.Array(resp8),
    ]
  
    let rc = Realm.Configuration(inMemoryIdentifier: "testUserFeedSyncWithUpdatedItems")
    let conf = DataStore.Configuration(realmConfig: rc, requestJSON: mockJSONRequester(responses))
    let ds = DataStore(configuration: conf)
    ds.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
    
    ds.syncUserFeeds().then {
      return ds.syncUserFeeds()
    }.always {
      expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(ds.feeds.count, 2)
      XCTAssertEqual(ds.items.count, 2)
      XCTAssertEqual(ds.feeds[0].items.count, 1)
      XCTAssertEqual(ds.feeds[1].items.count, 1)
    }
  }
}
