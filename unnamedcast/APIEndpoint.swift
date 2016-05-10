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

protocol Endpoint: URLRequestConvertible {
  associatedtype ResponseType
  func unmarshalResponse(data: NSData) throws -> ResponseType
}

// Noop if no ResponseType
extension Endpoint where ResponseType == Void {
  func unmarshalResponse(data: NSData) throws -> Void {
    return
  }
}

struct LoginEndpoint: Endpoint {
  var username: String
  var password: String
  
  var URLRequest: NSMutableURLRequest {
    return NSMutableURLRequest(method: "GET", path: "/login", queryParameters: [
      "username": username,
      "password": password
    ])
  }
  
  func unmarshalResponse(data: NSData) throws -> User {
    return try User(json: JSON(data: data))
  }
}

struct GetFeedEndpoint: Endpoint {
  let id: String
  var URLRequest: NSMutableURLRequest {
    return NSMutableURLRequest(method: "GET", path: "/feed/\(id)")
  }
  
  func unmarshalResponse(data: NSData) throws -> Feed {
    return try Feed(json: JSON(data: data))
  }
}

struct GetFeedItemsEndpoint: Endpoint {
  var id: String
  var modificationsSince: NSDate?
  
  var URLRequest: NSMutableURLRequest {
    var params = [String: String?]()
    if let t = modificationsSince {
      params["modification_time"] = rfc3339Formatter.stringFromDate(t)
    }
    
    return NSMutableURLRequest(method: "GET",
                               path: "/api/feeds/\(id)/items",
                               queryParameters: params)
  }
  
  func unmarshalResponse(data: NSData) throws -> [Item] {
    return try JSON(data: data).array().map(Item.init)
  }
}

struct GetUserEndpoint: Endpoint {
  var id: String
  var URLRequest: NSMutableURLRequest {
    return NSMutableURLRequest(method: "GET", path: "/api/users/\(id)")
  }
  
  func unmarshalResponse(data: NSData) throws -> User {
    return try User(json: JSON(data: data))
  }
}

struct GetUserItemStates: Endpoint {
  var userID: String
  var URLRequest: NSMutableURLRequest {
    return NSMutableURLRequest(method: "GET", path: "/api/users/\(userID)/items")
  }
  
  func unmarshalResponse(data: NSData) throws -> [ItemState] {
    return try JSON(data: data).array().map(ItemState.init)
  }
}

struct UpdateUserFeedsEndpoint: Endpoint {
  var userID: String
  var feedIDs: [String]
  typealias ResponseType = Void
  
  var URLRequest: NSMutableURLRequest {
    let body = try! JSON.Array(feedIDs.map { JSON.String($0) }).serialize()
    return NSMutableURLRequest(method: "PUT",
                               path: "/api/users/\(userID)/feeds",
                               body: body)
  }
}

struct UpdateUserItemStatesEndpoint: Endpoint {
  var userID: String
  var states: [ItemState]
  typealias ResponseType = Void
  
  var URLRequest: NSMutableURLRequest {
    let body = try! JSON.Array(states.map { $0.toJSON() }).serialize()
    return NSMutableURLRequest(method: "PUT",
                               path: "/api/users/\(userID)/feeds",
                               body: body)
  }
}

struct SearchFeedsEndpoint: Endpoint {
  var query: String
  
  var URLRequest: NSMutableURLRequest {
    return NSMutableURLRequest(method: "GET",
                               path: "/search_feeds",
                               queryParameters: ["q": query])
  }
  
  func unmarshalResponse(data: NSData) throws -> [Feed] {
    return try JSON(data: data).array().map(Feed.init)
  }
}

enum APIEndpoint {
  case Login(user: String, password: String)
  case GetFeed(id: String)
  case GetFeedItems(id: String, modificationsSince: NSDate?)
  case GetUserInfo(id: String)
  case SearchFeeds(query: String)
  case UpdateUserFeeds(userID: String)
  case GetUserItemStates(userID: String)
  case UpdateUserItemStates(userID: String)
}

extension APIEndpoint: URLRequestConvertible {
  var URLRequest: NSMutableURLRequest {
    let req = NSMutableURLRequest()
    let components = NSURLComponents()
    components.scheme = "http"
    components.host = "cast.cjlucas.net"
    components.port = 80
    
    switch self {
    case .Login(let user, let password):
      req.HTTPMethod = "GET"
      components.path = "/login"
      components.queryItems = [
        NSURLQueryItem(name: "username", value: user),
        NSURLQueryItem(name: "password", value: password)
      ]
    case .GetFeed(let id):
      req.HTTPMethod = "GET"
      components.path = "/api/feeds/\(id)"
    case .GetFeedItems(let id, let modTime):
      req.HTTPMethod = "GET"
      components.path = "/api/feeds/\(id)/items"
      if let t = modTime {
        let param = "modified_since"
        let val = rfc3339Formatter.stringFromDate(t)
        components.queryItems = [NSURLQueryItem(name: param, value: val)]
      }
    case .SearchFeeds(let query):
      req.HTTPMethod = "GET"
      components.path = "/search_feeds"
      components.queryItems = [NSURLQueryItem(name: "q", value: query)]
    case .GetUserInfo(let id):
      req.HTTPMethod = "GET"
      components.path = "/api/users/\(id)"
    case .UpdateUserFeeds(let userID):
      req.HTTPMethod = "PUT"
      components.path = "/api/users/\(userID)/feeds"
    case GetUserItemStates(let userID):
      req.HTTPMethod = "GET"
      components.path = "/api/users/\(userID)/states"
    case UpdateUserItemStates(let userID):
      req.HTTPMethod = "PUT"
      components.path = "/api/users/\(userID)/states"
    }
    
    req.URL = components.URL
    return req
  }
}