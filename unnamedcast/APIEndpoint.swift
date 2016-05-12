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

struct APIClient {
  struct Request: URLRequestConvertible {
    let scheme = "http"
    let host: String
    let port: Int
    let components: HTTPRequestComponents
    
    var URLRequest: NSMutableURLRequest {
      let urlComponents = NSURLComponents()
      urlComponents.scheme = scheme
      urlComponents.host = host
      urlComponents.port = port
      urlComponents.path = components.path
      
      if let params = components.queryParameters {
        urlComponents.queryItems = params.map { NSURLQueryItem(name: $0, value: $1) }
      }
      
      let req = NSMutableURLRequest()
      req.HTTPMethod = components.method
      req.HTTPBody = components.body
      req.URL = urlComponents.URL
      
      return req
    }
  }
  
  let host = "192.168.1.19"
  let port = 12100
  
  private func buildRequest<E: Endpoint>(endpoint: E) -> Request {
    return Request(host: host, port: port, components: endpoint.requestComponents)
  }
  
  func request<E: Endpoint>(endpoint: E) -> Promise<(NSURLRequest, NSHTTPURLResponse, E.ResponseType)> {
    let req = buildRequest(endpoint)
    return Alamofire.request(req).response().thenInBackground { req, res, body in
      return (req!, res!, try endpoint.unmarshalResponse(body!))
    }
  }

  func request<E: Endpoint where E.ResponseType == Void>(endpoint: E) -> Promise<(NSURLRequest, NSHTTPURLResponse)> {
    let req = buildRequest(endpoint)
    return Alamofire.request(req).response().then { req, res, _ in
      return (req!, res!)
    }
  }
}

struct HTTPRequestComponents {
  var method: String
  var path: String
  var queryParameters: [String:String?]?
  var body: NSData?
  
  init(method: String,
       path: String,
       queryParameters: [String:String?]? = nil,
       body: NSData? = nil) {
    self.method = method
    self.path = path
    self.queryParameters = queryParameters
    self.body = body
  }
}

protocol Endpoint {
  associatedtype ResponseType
  
  var requestComponents: HTTPRequestComponents { get }
  
  func unmarshalResponse(body: NSData) throws -> ResponseType
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
  
  var requestComponents: HTTPRequestComponents {
    return HTTPRequestComponents(method: "GET", path: "/login", queryParameters: [
      "username": username,
      "password": password
    ])
  }
  
  func unmarshalResponse(body: NSData) throws -> User {
    return try User(json: JSON(data: body))
  }
}

struct GetFeedEndpoint: Endpoint {
  let id: String
  
  var requestComponents: HTTPRequestComponents {
    return HTTPRequestComponents(method: "GET", path: "/api/feeds/\(id)")
  }
  
  func unmarshalResponse(body: NSData) throws -> Feed {
    return try Feed(json: JSON(data: body))
  }
}

struct GetFeedItemsEndpoint: Endpoint {
  var id: String
  var modificationsSince: NSDate?
  
  var requestComponents: HTTPRequestComponents {
    var params = [String: String?]()
    if let t = modificationsSince {
      params["modified_since"] = rfc3339Formatter.stringFromDate(t)
    }
    
    return HTTPRequestComponents(method: "GET",
                                 path: "/api/feeds/\(id)/items",
                                 queryParameters: params)
  }
  
  func unmarshalResponse(body: NSData) throws -> [Item] {
    return try [Item](json: JSON(data: body))
  }
}

struct GetUserEndpoint: Endpoint {
  var id: String
  
  var requestComponents: HTTPRequestComponents {
    return HTTPRequestComponents(method: "GET", path: "/api/users/\(id)")
  }
  
  func unmarshalResponse(body: NSData) throws -> User {
    return try User(json: JSON(data: body))
  }
}

struct GetUserItemStates: Endpoint {
  var userID: String
  
  var requestComponents: HTTPRequestComponents {
    return HTTPRequestComponents(method: "GET", path: "/api/users/\(userID)/states")
  }
  
  func unmarshalResponse(body: NSData) throws -> [ItemState] {
    return try JSON(data: body).array().map(ItemState.init)
  }
}

struct UpdateUserFeedsEndpoint: Endpoint {
  typealias ResponseType = Void
  
  var userID: String
  var feedIDs: [String]
  
  var requestComponents: HTTPRequestComponents {
    return HTTPRequestComponents(method: "PUT",
                                 path: "/api/users/\(userID)/feeds",
                                 body: try! feedIDs.toJSON().serialize())
  }
}

struct UpdateUserItemStatesEndpoint: Endpoint {
  typealias ResponseType = Void
  
  var userID: String
  var states: [ItemState]
  
  var requestComponents: HTTPRequestComponents {
    return HTTPRequestComponents(method: "PUT",
                                 path: "/api/users/\(userID)/states",
                                 body: try! states.toJSON().serialize())
  }
}

struct SearchFeedsEndpoint: Endpoint {
  var query: String
  
  var requestComponents: HTTPRequestComponents {
    return HTTPRequestComponents(method: "GET",
                                 path: "/search_feeds",
                                 queryParameters: ["q": query])
  }
  
  func unmarshalResponse(body: NSData) throws -> [SearchResult] {
    return try [SearchResult](json: JSON(data: body))
  }
}
