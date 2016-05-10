//
//  NSMutableURLRequest.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/10/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation

extension NSMutableURLRequest {
  convenience init(method: String,
                   path: String,
                   queryParameters: [String: String?] = [:],
                   body: NSData? = nil) {
    self.init()
    
    let components = NSURLComponents()
    components.path = path
    components.queryItems = queryParameters.map { NSURLQueryItem(name: $0, value: $1) }
    HTTPMethod = method
    HTTPBody = body
    URL = components.URL
  }
}