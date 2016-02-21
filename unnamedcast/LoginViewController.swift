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

class WaitGroup {
    private var counter: Int64 = 0;
    private var onDoneHandler: (() -> Void)?
    
    func onDone(handler: () -> Void) {
        onDoneHandler = handler
    }
    
    func add() {
        OSAtomicIncrement64(&counter)
    }
    
    func done() {
        OSAtomicDecrement64(&counter)
        guard counter == 0 else { return }
        
        if let handler = onDoneHandler {
            handler()
        }
    }
}

class LoginViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func loginButtonPressed(sender: AnyObject) {
        let realm = try! Realm()
       
        let endpoint = APIEndpoint.Login(user: emailTextField.text!, password: passwordTextField.text!)
        print(endpoint.URLRequest.URL)
        Alamofire.request(endpoint).response { resp in
            guard resp.1?.statusCode == 200 else { return }
            
            let json = try! JSON(data: resp.2!)
            
            
            NSUserDefaults.standardUserDefaults().setObject(try! json.string("id"), forKey: "user_id")
            
            let wg = WaitGroup()
            wg.onDone {
                dispatch_async(dispatch_get_main_queue()) {
                    self.performSegueWithIdentifier("Login2Main", sender: self)
                }
            }
            
            let fetchFeedsOp = NSBlockOperation()
            fetchFeedsOp.queuePriority = .Low
            
            for feedID in try! json.array("feeds") {
                fetchFeedsOp.addExecutionBlock {
                   
                    let endpoint = APIEndpoint.GetFeed(id: try! String(json: feedID))
                    wg.add()
                    Alamofire.request(endpoint).response { resp in
                        let json = try! JSON(data: resp.2!)
                        try! realm.write {
                            realm.add(try! Feed(json: json), update: false)
                        }
                        wg.done()
                        print("WROTE")
                    }
                }
            }
            
            NSOperationQueue.mainQueue().addOperation(fetchFeedsOp)
        }
    }
}
