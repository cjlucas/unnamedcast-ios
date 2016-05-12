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
   
    let ep = LoginEndpoint(username: emailTextField.text!, password: passwordTextField.text!)
    // TODO: handle error
    APIClient().request(ep).then { _, _, user in
      NSUserDefaults.standardUserDefaults().setObject(user.id, forKey: "user_id")
    }.then { () -> Void in
      let ds = try! DataStore()
      ds.sync {
        dispatch_async(dispatch_get_main_queue()) {
          self.performSegueWithIdentifier("Login2Main", sender: self)
        }
      }
    }
  }
}
