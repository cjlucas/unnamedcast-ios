//
//  unnamedcastUnitTests.swift
//  unnamedcastUnitTests
//
//  Created by Christopher Lucas on 3/12/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import XCTest
import Freddy

class unnamedcastUnitTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func loadFixture(name: String, ofType: String) -> NSData {
    let fpath = NSBundle(forClass: unnamedcastUnitTests.self).pathForResource(name, ofType: ofType)
    return NSData(contentsOfFile: fpath!)!
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
}
