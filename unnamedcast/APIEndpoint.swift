//
//  APIEndpoint.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/20/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Alamofire
import Foundation

let rfc3339Formatter: NSDateFormatter = {
  let f = NSDateFormatter()
  f.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSSSSX"
  f.timeZone = NSTimeZone(name: "UTC")
  return f
}()

enum APIEndpoint {
  case Login(user: String, password: String)
  case GetFeed(id: String, modificationsSince: NSDate?)
  case GetUserInfo(id: String)
  case GetUserFeeds(userID: String, syncToken: String?)
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
    components.host = "192.168.1.19"
    components.port = 8081
    
    switch self {
    case .Login(let user, let password):
      req.HTTPMethod = "GET"
      components.path = "/login"
      components.queryItems = [
        NSURLQueryItem(name: "username", value: user),
        NSURLQueryItem(name: "password", value: password)
      ]
    case .GetFeed(let id, let modTime):
      req.HTTPMethod = "GET"
      components.path = "/api/feeds/\(id)"
      if let t = modTime {
        let param = "items_modified_since"
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
    case .GetUserFeeds(let userID, let syncToken):
      req.HTTPMethod = "GET"
      components.path = "/api/users/\(userID)/feeds"
      if let token = syncToken {
        req.addValue(token, forHTTPHeaderField: "X-Sync-Token")
      }
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