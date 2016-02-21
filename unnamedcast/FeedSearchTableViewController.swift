//
//  FeedSearchTableViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/19/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import Alamofire
import Freddy
import RealmSwift

class FeedSearchTableViewController: UITableViewController, UISearchBarDelegate {
    struct Result: JSONDecodable {
        var id: String
        var title: String
        
        init(json: JSON) throws {
            id = try json.string("id")
            title = try json.string("title")
        }
    }

    @IBOutlet weak var searchBar: UISearchBar!
    
    var results = [Result]()
    let realm = try! Realm()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        cell.textLabel?.text = results[indexPath.row].title

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let feedId = results[indexPath.row].id
        var feedIds = realm.objects(Feed).map { $0.id }
        feedIds.append(feedId)
        
        let alert = UIAlertController(title: "Add Feed", message: "Do you want to add this feed?", preferredStyle: .Alert)
        
        let add = UIAlertAction(title: "Add", style: .Default) { action in
            let userID = NSUserDefaults.standardUserDefaults().stringForKey("user_id")!
           
            let endpoint = APIEndpoint.UpdateUserFeeds(userID: userID)
            let payload = try! NSJSONSerialization.dataWithJSONObject(feedIds, options: NSJSONWritingOptions(rawValue: 0))
            Alamofire.upload(endpoint, data: payload).response { resp in
                print("Your shit got updated yo")
            }
            
        }
        let cancel = UIAlertAction(title: "Cancel", style: .Default) { action in
            print("HERE2")
        }
        
        alert.addAction(add)
        alert.addAction(cancel)
        
        presentViewController(alert, animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        let endpoint = APIEndpoint.SearchFeeds(query: searchText)
        Alamofire.request(endpoint).response { resp in
            guard resp.3 == nil else {
                print("Error received: \(resp.3!)")
                return
            }
            
            guard resp.1?.statusCode == 200 else {
                print("Unexpected status code: \(resp.1?.statusCode)")
                return
            }
            
            do {
                let json = try JSON(data: resp.2!).array()
                self.results = json.map { try! Result(json: $0) }
                self.tableView.reloadData()
            } catch {
                print("Error handling response")
                print(String(data: resp.2!, encoding: NSUTF8StringEncoding))
            }
            
        }
    }

}
