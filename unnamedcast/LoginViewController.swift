//
//  LoginViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/14/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import Alamofire
import Freddy
import RealmSwift

class LoginViewController: UIViewController {
  
  @IBOutlet weak var emailTextField: UITextField!
  @IBOutlet weak var passwordTextField: UITextField!
  
  @IBAction func loginButtonPressed(sender: AnyObject) {
    
    let endpoint = APIEndpoint.Login(user: emailTextField.text!, password: passwordTextField.text!)
    print(endpoint.URLRequest.URL)
    let q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
    Alamofire.request(endpoint).response(queue: q) { resp in
      guard resp.1?.statusCode == 200 else { return }
      
      let json = try! JSON(data: resp.2!)
      
      
      NSUserDefaults.standardUserDefaults().setObject(try! json.string("id"), forKey: "user_id")
      let ds = try! DataStore()
      ds.sync {
        dispatch_async(dispatch_get_main_queue()) {
          self.performSegueWithIdentifier("Login2Main", sender: self)
        }
      }
    }
  }
}
