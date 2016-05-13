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

class MockRequester: EndpointRequestable {
  var endpointResponses: [String:[JSON]] = [:]
  let url = NSURLComponents(string: "http://localhost/fakepath")!.URL!
  
  func responseKey(method: String, path: String) -> String {
    return "\(method) \(path)"
  }
  
  func registerResponse(method: String, path: String, response: JSON) {
    let key = responseKey(method, path: path)
    
    if endpointResponses[key] == nil {
      endpointResponses[key] = []
    }
    
    endpointResponses[key]?.append(response)
  }
  
  func request<E : Endpoint>(endpoint: E) -> Promise<(NSURLRequest, NSHTTPURLResponse, E.ResponseType)> {
    let key = responseKey(endpoint.requestComponents.method, path: endpoint.requestComponents.path)
    
    guard var responses = endpointResponses[key] else {
      fatalError("No response found for key: \(key)")
    }
    
    guard responses.count > 0 else {
      fatalError("No more responses found for key: \(key)")
    }
    
    let json = responses.removeFirst()
    endpointResponses[key] = responses
    
    guard let body = try? json.serialize() else {
      fatalError("Could not serialize json")
    }
    
    return dispatch_promise {
      let req = NSURLRequest(URL: self.url)
      let res = NSHTTPURLResponse(URL: self.url, statusCode: 200, HTTPVersion: nil, headerFields: nil)!
      
      return (req, res, try endpoint.unmarshalResponse(body))
    }
  }
  
  func request<E : Endpoint where E.ResponseType == Void>(endpoint: E) -> Promise<(NSURLRequest, NSHTTPURLResponse)> {
    return dispatch_promise {
      let req = NSURLRequest(URL: self.url)
      let res = NSHTTPURLResponse(URL: self.url, statusCode: 200, HTTPVersion: nil, headerFields: nil)!
      return (req, res)
    }
  }
}

func loadFixture(name: String, ofType: String) -> NSData {
  let fpath = NSBundle(forClass: unnamedcastUnitTests.self).pathForResource(name, ofType: ofType)
  return NSData(contentsOfFile: fpath!)!
}

class unnamedcastUnitTests: XCTestCase {
  let dbc = DB.Configuration(realmConfig: Realm.Configuration(
    inMemoryIdentifier: "unnamedcastUnitTests",
    deleteRealmIfMigrationNeeded: true
  ))
  var db: DB!
  
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    
    db = try! DB(configuration: dbc)
    try! db.deleteAll()
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func newSyncEngine(requester: MockRequester) -> SyncEngine {
    let conf = SyncEngine.Configuration(dbConfiguration: dbc,
                                        endpointRequester: requester)
    return SyncEngine(configuration: conf)
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
      "summary": "summary",
      "description": "description",
      "duration": 5,
      "size": 100,
      "publication_time": "1970-01-01T00:00:05.00Z",
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
      XCTAssertEqual(item.summary, try! json["summary"]!.string())
      XCTAssertEqual(item.desc, try! json["description"]!.string())
      XCTAssertEqual(item.duration, try! json["duration"]!.int())
      XCTAssertEqual(item.size, try! json["size"]!.int())
      XCTAssertEqual(item.pubDate!.timeIntervalSince1970, 5)
      XCTAssertEqual(item.audioURL, try! json["url"]!.string())
      XCTAssertEqual(item.imageURL, try! json["image_url"]!.string())
      print(item.modificationDate)
      
    } catch let e {
      XCTFail("Failed JSON deserialization \(e)")
    }
  }

  // TODO: move this test to its own class
  func testInitialUserFeedSync() {
    let requester = MockRequester()
   
    requester.registerResponse("GET",
                               path: "/api/users/0",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "username": "chris@cjlucas.net",
                                "feeds": ["56d65493c8747268f348438b"],
                                "states": []
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "title": "Some Title",
                                "url": "http://google.com",
                                "author": "Author goes Here",
                                "image_url": "http://google.com/404.png",
                                "modification_time": "2016-04-03T19:38:03.33Z",
                                "items": []
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b/items",
                               response: JSON.Array([]))
    
    let engine = newSyncEngine(requester)
    engine.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
    
    engine.syncUserFeeds().always {
      expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(self.db.feeds.count, 1)
      XCTAssertEqual(self.db.feeds.first!.items.count, 0)
    }
  }
  
  func testUserFeedSyncWithNewItems() {
    let requester = MockRequester()
   
    requester.registerResponse("GET",
                               path: "/api/users/0",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "username": "chris@cjlucas.net",
                                "feeds": ["56d65493c8747268f348438b"],
                                "states": [],
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "title": "Some Title",
                                "url": "http://google.com",
                                "author": "Author goes Here",
                                "image_url": "http://google.com/404.png",
                                "modification_time": "2016-04-03T19:38:03.33Z",
                                "items": []
                                ]))

    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b/items",
                               response: JSON.Array([]))

    // No modifications
    requester.registerResponse("GET",
                               path: "/api/users/0",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "username": "chris@cjlucas.net",
                                "feeds": ["56d65493c8747268f348438b"],
                                "states": [],
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "title": "Some Title",
                                "url": "http://google.com",
                                "author": "Author goes Here",
                                "image_url": "http://google.com/404.png",
                                "modification_time": "2016-04-03T19:38:03.34Z",
                                "items": [
                                  "56d65493c8747268f348438c",
                                ]
                                ]))

    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b/items",
                               response: JSON.Array([
                                [
                                  "id": "56d65493c8747268f348438c",
                                  "guid": "guid goes here",
                                  "link": "link goes here",
                                  "title": "title goes here",
                                  "author": "author goes here",
                                  "summary": "summary",
                                  "description": "description",
                                  "duration": 5,
                                  "size": 100,
                                  "publication_time": "doesnt matter",
                                  "url": "http://google.com/podcast.mp3",
                                  "image_url": "http://google.com/404.png",
                                  "modification_time": "2016-04-03T19:38:03.33Z"
                                ]
                              ]))
    
   
    let engine = newSyncEngine(requester)
    engine.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
  
    engine.syncUserFeeds().then {
      return engine.syncUserFeeds()
    }.always {
        expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(self.db.feeds.count, 1)
      XCTAssertEqual(self.db.items.count, 1)
      XCTAssertEqual(self.db.feeds.first!.items.count, 1)
    }
  }

  func testUserFeedSyncWithUpdatedItems() {
    let requester = MockRequester()
    
    requester.registerResponse("GET",
                               path: "/api/users/0",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "username": "chris@cjlucas.net",
                                "feeds": ["56d65493c8747268f348438b"],
                                "states": [],
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "title": "Some Title",
                                "url": "http://google.com",
                                "author": "Author goes Here",
                                "image_url": "http://google.com/404.png",
                                "modification_time": "2016-04-03T19:38:03.34Z",
                                "items": [
                                  "56d65493c8747268f348438c",
                                ]
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b/items",
                               response: JSON.Array([
                                [
                                  "id": "56d65493c8747268f348438c",
                                  "guid": "guid goes here",
                                  "link": "link goes here",
                                  "title": "title1",
                                  "author": "author goes here",
                                  "summary": "summary",
                                  "description": "description",
                                  "duration": 5,
                                  "size": 100,
                                  "publication_time": "doesnt matter",
                                  "url": "http://google.com/podcast.mp3",
                                  "image_url": "http://google.com/404.png",
                                  "modification_time": "2016-04-03T19:38:03.33Z"
                                ]
                                ]))

    // Begin 2nd sync
    requester.registerResponse("GET",
                               path: "/api/users/0",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "username": "chris@cjlucas.net",
                                "feeds": ["56d65493c8747268f348438b"],
                                "states": [],
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "title": "Some Title",
                                "url": "http://google.com",
                                "author": "Author goes Here",
                                "image_url": "http://google.com/404.png",
                                "modification_time": "2016-04-03T19:38:03.34Z",
                                "items": [
                                  "56d65493c8747268f348438c",
                                ]
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b/items",
                               response: JSON.Array([
                                [
                                  "id": "56d65493c8747268f348438c",
                                  "guid": "guid goes here",
                                  "link": "link goes here",
                                  "title": "title2",
                                  "author": "author goes here",
                                  "summary": "summary",
                                  "description": "description",
                                  "duration": 5,
                                  "size": 100,
                                  "publication_time": "doesnt matter",
                                  "url": "http://google.com/podcast.mp3",
                                  "image_url": "http://google.com/404.png",
                                  "modification_time": "2016-04-03T19:38:04.33Z"
                                ]
                                ]))
    
    let engine = newSyncEngine(requester)
    engine.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
    
    engine.syncUserFeeds().then {
      return engine.syncUserFeeds()
    }.always {
      expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(self.db.feeds.count, 1)
      XCTAssertEqual(self.db.items.count, 1)
      XCTAssertEqual(self.db.feeds.first!.items.count, 1)
      
      let item = self.db.feeds.first!.items.first!
      XCTAssertEqual(item.title, "title2")
    }
  }

  func testUserFeedSyncWithNewFeed() {
    let requester = MockRequester()
    
    requester.registerResponse("GET",
                               path: "/api/users/0",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "username": "chris@cjlucas.net",
                                "feeds": ["56d65493c8747268f348438b"],
                                "states": [],
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "title": "Some Title",
                                "url": "http://google.com",
                                "author": "Author goes Here",
                                "image_url": "http://google.com/404.png",
                                "modification_time": "2016-04-03T19:38:03.34Z",
                                "items": [
                                  "56d65493c8747268f348438c",
                                ]
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b/items",
                               response: JSON.Array([
                                [
                                  "id": "56d65493c8747268f348438c",
                                  "guid": "guid goes here",
                                  "link": "link goes here",
                                  "title": "title1",
                                  "author": "author goes here",
                                  "summary": "summary",
                                  "description": "description",
                                  "duration": 5,
                                  "size": 100,
                                  "publication_time": "doesnt matter",
                                  "url": "http://google.com/podcast.mp3",
                                  "image_url": "http://google.com/404.png",
                                  "modification_time": "2016-04-03T19:38:03.33Z"
                                ]
                                ]))
    
    // Start 2nd sync
    
    requester.registerResponse("GET",
                               path: "/api/users/0",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "username": "chris@cjlucas.net",
                                "feeds": [
                                  "56d65493c8747268f348438b",
                                  "56d65493c8747268f348438c"
                                ],
                                "states": [],
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b",
                               response: JSON.Dictionary([
                                "id": "56d65493c8747268f348438b",
                                "title": "Some Title",
                                "url": "http://google.com",
                                "author": "Author goes Here",
                                "image_url": "http://google.com/404.png",
                                "modification_time": "2016-04-03T19:38:03.34Z",
                                "items": [
                                  "56d65493c8747268f348438c",
                                ]
                                ]))
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438b/items",
                               response: JSON.Array([
                                [
                                  "id": "56d65493c8747268f348438c",
                                  "guid": "guid goes here",
                                  "link": "link goes here",
                                  "title": "title1",
                                  "author": "author goes here",
                                  "summary": "summary",
                                  "description": "description",
                                  "duration": 5,
                                  "size": 100,
                                  "publication_time": "doesnt matter",
                                  "url": "http://google.com/podcast.mp3",
                                  "image_url": "http://google.com/404.png",
                                  "modification_time": "2016-04-03T19:38:03.33Z"
                                ]
                                ]))
    
    requester.registerResponse("GET",
                                path: "/api/feeds/56d65493c8747268f348438c",
                                response: JSON.Dictionary([
                                  "id": "56d65493c8747268f348438c",
                                  "title": "Some Title",
                                  "url": "http://google.com",
                                  "author": "Author goes Here",
                                  "image_url": "http://google.com/404.png",
                                  "modification_time": "2016-04-03T19:38:03.34Z",
                                  "items": [
                                    "56d65493c8747268f348438d",
                                  ]
                                ]))
    
    
    requester.registerResponse("GET",
                               path: "/api/feeds/56d65493c8747268f348438c/items",
                               response: JSON.Array([
                                [
                                  "id": "56d65493c8747268f348438d",
                                  "guid": "guid goes here",
                                  "link": "link goes here",
                                  "title": "title2",
                                  "author": "author goes here",
                                  "summary": "summary",
                                  "description": "description",
                                  "duration": 5,
                                  "size": 100,
                                  "publication_time": "doesnt matter",
                                  "url": "http://google.com/podcast.mp3",
                                  "image_url": "http://google.com/404.png",
                                  "modification_time": "2016-04-03T19:38:03.33Z",
                                ]
                                ]))
    
    let engine = newSyncEngine(requester)
    engine.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
    
    engine.syncUserFeeds().then {
      return engine.syncUserFeeds()
    }.always {
      expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(self.db.feeds.count, 2)
      XCTAssertEqual(self.db.items.count, 2)
      XCTAssertEqual(self.db.feeds[0].items.count, 1)
      XCTAssertEqual(self.db.feeds[1].items.count, 1)
    }
  }
}
