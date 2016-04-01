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
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testFeedFromJSON() {
    let data: Dictionary<String, JSON> = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "items": [[
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title goes here",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png"
      ]]
    ]
    
    let json = JSON.Dictionary(data)
    
    do {
      let f = try Feed(json: json)
      XCTAssertEqual(f.id, try! data["id"]!.string())
      XCTAssertEqual(f.title, try! data["title"]!.string())
      XCTAssertEqual(f.author, try! data["author"]!.string())
      XCTAssertEqual(f.imageUrl, try! data["image_url"]!.string())
      
      XCTAssertEqual(f.items.count, 1)
      let item = f.items.first!
      let itemJSON = try! data["items"]!.array().first!.dictionary()
      XCTAssertEqual(item.guid, try! itemJSON["guid"]!.string())
      XCTAssertEqual(item.link, try! itemJSON["link"]!.string())
      XCTAssertEqual(item.title, try! itemJSON["title"]!.string())
      XCTAssertEqual(item.author, try! itemJSON["author"]!.string())
      XCTAssertEqual(item.desc, try! itemJSON["description"]!.string())
      XCTAssertEqual(item.duration, try! itemJSON["duration"]!.int())
      XCTAssertEqual(item.size, try! itemJSON["size"]!.int())
      XCTAssertEqual(item.pubDate, try! itemJSON["publication_time"]!.string())
      XCTAssertEqual(item.audioURL, try! itemJSON["url"]!.string())
      XCTAssertEqual(item.imageURL, try! itemJSON["image_url"]!.string())
      
    } catch let e {
      XCTFail("Failed JSON deserialization \(e)")
    }
  }

  // TODO: move this test to its own class
  func testInitialUserFeedSync() {
    // TODO: Waiting for Freddy to support proper literal syntax
    // https://github.com/bignerdranch/Freddy/issues/150
    let resp1: JSON = [[
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
    ].toJSON()]
    
    
    let responses = [resp1]
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
    let resp1: Dictionary<String, JSON> = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
    ]

    let resp2: Dictionary<String, JSON> = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "items": [[
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title goes here",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png"
      ]]
    ]
  
    let responses = [JSON.Array([.Dictionary(resp1)]), JSON.Array([.Dictionary(resp2)])]
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
    let resp1: Dictionary<String, JSON> = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "items": [[
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title1",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png"
      ]]
    ]

    let resp2: Dictionary<String, JSON> = [
      "id": "56d65493c8747268f348438b",
      "title": "Some Title",
      "url": "http://google.com",
      "author": "Author goes Here",
      "image_url": "http://google.com/404.png",
      "items": [[
        "guid": "guid goes here",
        "link": "link goes here",
        "title": "title2",
        "author": "author goes here",
        "description": "description",
        "duration": 5,
        "size": 100,
        "publication_time": "doesnt matter",
        "url": "http://google.com/podcast.mp3",
        "image_url": "http://google.com/404.png"
      ]]
    ]
  
    let responses = [JSON.Array([.Dictionary(resp1)]), JSON.Array([.Dictionary(resp2)])]
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
}
