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

class LoginViewController: UIViewController, ApplicationDelegateReachable {
  
  @IBOutlet weak var emailTextField: UITextField!
  @IBOutlet weak var passwordTextField: UITextField!
  
  @IBAction func loginButtonPressed(sender: AnyObject) {
   
    let ep = LoginEndpoint(username: emailTextField.text!, password: passwordTextField.text!)
    APIClient().request(ep).then { _, _, user in
      self.applicationDelegate.engine.userID = user.id
    }.then { () -> Void in
      self.applicationDelegate.engine.sync().then {
        self.performSegueWithIdentifier("Login2Main", sender: self)
      }
    }.error { err in
      let alert = UIAlertController(title: "Error while syncing",
                                    message: (err as NSError).description,
                                    preferredStyle: .Alert)
      alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
      self.presentViewController(alert, animated: true, completion: nil)
    }
  }
}
