//
//  File.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/12/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Alamofire
import PromiseKit
import Freddy

internal enum Error: ErrorType {
  case NetworkError(ErrorType)
  case JSONError(ErrorType)
}

private struct Request<E: Endpoint>: URLRequestConvertible {
  let scheme = "http"
  let host: String
  let port: Int
  let endpoint: E
  
  var URLRequest: NSMutableURLRequest {
    let urlComponents = NSURLComponents()
    urlComponents.scheme = scheme
    urlComponents.host = host
    urlComponents.port = port
    urlComponents.path = endpoint.path
    
    urlComponents.queryItems = endpoint.queryParameters
      .map { NSURLQueryItem(name: $0, value: $1) }
    
    let req = NSMutableURLRequest()
    req.HTTPMethod = endpoint.method
    req.HTTPBody = try! endpoint.marshalRequestBody()
    req.URL = urlComponents.URL
    
    return req
  }
}

struct APIClient: EndpointRequestable {
  
  let host = "cast.cjlucas.net"
  let port = 80
  
  private func buildRequest<E: Endpoint>(endpoint: E) -> URLRequestConvertible {
    return Request(host: host, port: port, endpoint: endpoint)
  }
  
  func request<E: Endpoint>(endpoint: E) -> Promise<(NSURLRequest, NSHTTPURLResponse, E.ResponseType)> {
    let req = buildRequest(endpoint)
    
    return Alamofire.request(req).response()
      .recover { err -> (NSURLRequest?, NSHTTPURLResponse?, NSData?) in
        throw Error.NetworkError(err)
      
    }.thenInBackground { (req: NSURLRequest?, res: NSHTTPURLResponse?, body: NSData?) in
      return (req!, res!, try endpoint.unmarshalResponse(body!))
      
    }.recover { err -> (NSURLRequest, NSHTTPURLResponse, E.ResponseType) in
      throw Error.JSONError(err)
    }
  }

  func request<E: Endpoint where E.ResponseType == Void>(endpoint: E) -> Promise<(NSURLRequest, NSHTTPURLResponse)> {
    let req = buildRequest(endpoint)
    
    return Alamofire.request(req).response()
      .recover { err -> (NSURLRequest?, NSHTTPURLResponse?, NSData?) in
        throw Error.NetworkError(err)
        
    }.then { req, res, _ in
      return (req!, res!)
    }
  }
}
