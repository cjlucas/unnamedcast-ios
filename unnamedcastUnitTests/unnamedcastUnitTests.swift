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

func mockJSONRequester(responses: [NSData]) -> JSONRequester {
  var resps = responses
  
  
  return { (req: URLRequestConvertible) -> Promise<JSONResponse> in
    let okResp = NSHTTPURLResponse(URL: req.URLRequest.URL!, statusCode: 200, HTTPVersion: nil, headerFields: nil)!
    
    return Promise { fulfill, reject in
      guard resps.count > 0 else { fatalError("No responses left to return") }
      let json = try! JSON(data: resps.removeFirst())
      fulfill((req: req.URLRequest, resp: okResp, json: json))
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
    let data = loadFixture("feed1", ofType: "json")
    let json = try! JSON(data: data)
    XCTAssert(json != nil)
    
    do {
      let _  = try Feed(json: json)
    } catch let e {
      XCTFail("Failed JSON deserialization \(e)")
    }
  }

  // TODO: move this test to its own class
  func testInitialUserFeedSync() {
    let responses = [loadFixture("userfeeds1", ofType: "json")]
    let rc = Realm.Configuration(inMemoryIdentifier: "hithere")
    let conf = DataStore.Configuration(realmConfig: rc, requestJSON: mockJSONRequester(responses))
    let ds = DataStore(configuration: conf)
    ds.userID = "0"
    
    let expectation = expectationWithDescription("whatever")
    
    ds.syncUserFeeds().always {
      expectation.fulfill()
    }
    
    waitForExpectationsWithTimeout(5) { err in
      XCTAssertEqual(ds.feeds.count, 1)
    }
  }
}
