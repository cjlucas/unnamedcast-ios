//
//  Request.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/9/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Alamofire
import PromiseKit

extension Alamofire.Request {
  public func response() -> Promise<(NSURLRequest?, NSHTTPURLResponse?, NSData?)> {
    return Promise { fulfill, reject in
      response { resp in
        if let err = resp.3 { return reject(err) }
        return fulfill((resp.0, resp.1, resp.2))
      }
    }
  }
}
