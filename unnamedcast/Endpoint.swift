//
//  APIEndpoint.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/20/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Alamofire
import Foundation
import Freddy
import PromiseKit

let rfc3339Formatter: NSDateFormatter = {
  let f = NSDateFormatter()
  f.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssX"
  f.timeZone = NSTimeZone(name: "UTC")
  return f
}()

let rfc3339NanoFormatter: NSDateFormatter = {
  let f = NSDateFormatter()
  f.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSSSSX"
  f.timeZone = NSTimeZone(name: "UTC")
  return f
}()

func parseDate(s: String) -> NSDate? {
  for fmt in [rfc3339Formatter, rfc3339NanoFormatter] {
    let d = fmt.dateFromString(s)
    if d != nil {
      return d
    }
  }
  
  return nil
}

protocol EndpointRequestable {
  func request<E: Endpoint>(endpoint: E) -> Promise<(NSURLRequest, NSHTTPURLResponse, E.ResponseType)>
  func request<E: Endpoint where E.ResponseType == Void>(endpoint: E) -> Promise<(NSURLRequest, NSHTTPURLResponse)>
}

protocol Endpoint {
  associatedtype ResponseType
  
  var method: String { get }
  var path: String { get }
  var queryParameters: [String: String?] { get}
 
  func marshalRequestBody() throws -> NSData?
  func unmarshalResponse(body: NSData) throws -> ResponseType
}

// Default values
extension Endpoint {
  var queryParameters: [String: String?] {
    return [:]
  }

  func marshalRequestBody() throws -> NSData? {
    return nil
  }
}

extension Endpoint where ResponseType == Void {
  // Noop if no ResponseType
  func unmarshalResponse(body: NSData) throws -> Void {
    return
  }
}

struct LoginEndpoint: Endpoint {
  var username: String
  var password: String
  
  let method = "GET"
  let path = "/login"
  
  var queryParameters: [String : String?] {
    return [
      "username": username,
      "password": password
    ]
  }
  
  func unmarshalResponse(body: NSData) throws -> User {
    return try User(json: JSON(data: body))
  }
}

struct GetFeedEndpoint: Endpoint {
  let id: String
  
  let method = "GET"
  var path: String {
    return "/api/feeds/\(id)"
  }
  
  func unmarshalResponse(body: NSData) throws -> Feed {
    return try Feed(json: JSON(data: body))
  }
}

struct GetFeedItemsEndpoint: Endpoint {
  var id: String
  var modificationsSince: NSDate?
  
  let method = "GET"
  var path: String {
    return "/api/feeds/\(id)/items"
  }
  
  var queryParameters: [String : String?] {
    var params = [String: String?]()
    if let t = modificationsSince {
      params["modified_since"] = rfc3339Formatter.stringFromDate(t)
    }
    
    return params
  }
  
  func unmarshalResponse(body: NSData) throws -> [Item] {
    return try [Item](json: JSON(data: body))
  }
}

struct GetUserEndpoint: Endpoint {
  var id: String
  
  let method = "GET"
  var path: String {
    return "/api/users/\(id)"
  }
  
  func unmarshalResponse(body: NSData) throws -> User {
    return try User(json: JSON(data: body))
  }
}

struct GetUserItemStates: Endpoint {
  var userID: String
  
  let method = "GET"
  var path: String {
    return "/api/users/\(userID)/states"
  }
  
  func unmarshalResponse(body: NSData) throws -> [ItemState] {
    return try [ItemState](json: JSON(data: body))
  }
}

struct UpdateUserFeedsEndpoint: Endpoint {
  typealias ResponseType = Void
  
  var userID: String
  var feedIDs: [String]
  
  let method = "PUT"
  var path: String {
    return "/api/users/\(userID)/feeds"
  }
  
  func marshalRequestBody() throws -> NSData? {
    return try feedIDs.toJSON().serialize()
  }
}

struct UpdateUserItemStatesEndpoint: Endpoint {
  typealias ResponseType = Void
  
  var userID: String
  var states: [ItemState]
  
  let method = "PUT"
  var path: String {
    return "/api/users/\(userID)/states"
  }
  
  func marshalRequestBody() throws -> NSData? {
    return try states.toJSON().serialize()
  }
}

struct SearchFeedsEndpoint: Endpoint {
  var query: String
  
  let method = "GET"
  let path = "/search_feeds"
  var queryParameters: [String : String?] {
    return ["q": query]
  }
  
  func unmarshalResponse(body: NSData) throws -> [SearchResult] {
    return try [SearchResult](json: JSON(data: body))
  }
}
