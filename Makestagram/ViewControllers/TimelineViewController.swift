//
//  TimelineViewController.swift
//  Makestagram
//
//  Created by Samuel Putnam on 6/29/16.
//  Copyright © 2016 Make School. All rights reserved.
//

import UIKit
import Parse
import ConvenienceKit

protocol CaptionReceiverDelegate {
    func captionChosen(caption: String)
    
}

class TimelineViewController: UIViewController, TimelineComponentTarget {

    @IBOutlet weak var tableView: UITableView!
    var photoTakingHelper : PhotoTakingHelper?
    var defaultRange = 0...4
    let additionalRangeSize = 5
    var timelineComponent: TimelineComponent<Post, TimelineViewController>!
    var note: Note?
    var post: Post?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timelineComponent = TimelineComponent(target: self)
        self.tabBarController?.delegate = self
        
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if NSUserDefaults.standardUserDefaults().boolForKey("TermsAccepted") {
            // Terms have not been accepted. Show terms (perhaps using performSegueWithIdentifier)
            self.performSegueWithIdentifier("showTermsPage", sender: self)
            
        } else {
         // Terms have been accepted, proceed as normal   
        }
    
        timelineComponent.loadInitialIfRequired()
       
    }
    
    func takePhoto() {
        // Instantiate photo taking class, provide callback for when photo is selected
        photoTakingHelper = PhotoTakingHelper(viewController: self.tabBarController!) { (image: UIImage?) in
            self.post = Post()
            self.post!.image.value = image
            self.showCaptionActionSheetForPost(self.post!)
        }
    }

    func loadInRange(range: Range<Int>, completionBlock: ([Post]?) -> Void) {
        
        ParseHelper.timelineRequestForCurrentUser(range) { (result : [PFObject]?, error: NSError?) in
            if let error = error {
                ErrorHandling.defaultErrorHandler(error)
            }
            let posts = result as? [Post] ?? []
            
            completionBlock(posts)
        }
    }
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let identifier = segue.identifier {
            if identifier == "newCaption" {
                let displayNoteViewController = segue.destinationViewController as! DisplayNoteViewController
                displayNoteViewController.delegate = self
                
            }
            if identifier == "captionFromNotes" {
                let navigationController = segue.destinationViewController as! UINavigationController
                let listNotesTableViewController = navigationController.viewControllers.first as! ListNotesTableViewController
                listNotesTableViewController.delegate = self
               
            }
            
        }
    }
    
    
    
    // MARK: UIActionSheets
    
    func showCaptionActionSheetForPost(post: Post){
        let alertController = UIAlertController(title: nil, message: "Where do you want to get your caption from?", preferredStyle: .ActionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let newCaptionAction = UIAlertAction(title: "New caption", style: .Default) { (action) in
        self.performSegueWithIdentifier("newCaption", sender: self)
        }
        alertController.addAction(newCaptionAction)
        
        let captionFromNotesAction = UIAlertAction(title: "Caption from notes", style: .Default) { (action) in self.performSegueWithIdentifier("captionFromNotes", sender: self)
        }
        alertController.addAction(captionFromNotesAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func showActionSheetForPost(post: Post) {
        if (post.user == PFUser.currentUser()) {
            showDeleteActionSheetForPost(post)
        } else {
            showFlagActionSheetForPost(post)
        }
    }
    
    func showDeleteActionSheetForPost(post: Post) {
        let alertController = UIAlertController(title: nil, message: "Do you want to delete this post?", preferredStyle: .ActionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let destroyAction = UIAlertAction(title: "Delete", style: .Destructive) { (action) in
            post.deleteInBackgroundWithBlock({ (success: Bool, error: NSError?) -> Void in
                if (success) {
                    self.timelineComponent.removeObject(post)
                } else {
                    // restore old state
                    self.timelineComponent.refresh(self)
                }
            })
        }
        alertController.addAction(destroyAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func showFlagActionSheetForPost(post: Post) {
        let alertController = UIAlertController(title: nil, message: "Do you want to flag this post?", preferredStyle: .ActionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let destroyAction = UIAlertAction(title: "Flag", style: .Destructive) { (action) in
            post.flagPost(PFUser.currentUser()!)
        }
        
        alertController.addAction(destroyAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
}
// MARK: Tab Bar Delegate

extension TimelineViewController : UITabBarControllerDelegate {
    
    func tabBarController(tabBarController: UITabBarController, shouldSelectViewController viewController: UIViewController) -> Bool {
        if (viewController is PhotoViewController){
            takePhoto()
            print("Take Photo")
            return false
        } else {
            return true
        }
    }
}

extension TimelineViewController : UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.timelineComponent.content.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PostCell") as! PostTableViewCell
        
        let post = timelineComponent.content[indexPath.section]
        post.downloadImage()
        post.fetchLikes()
        cell.post = post
        cell.timeline = self
        
        return cell
    }
}

extension TimelineViewController : CaptionReceiverDelegate {
    func captionChosen(caption: String){
        post?.caption = caption
        self.post!.uploadPost()
    }
}

extension TimelineViewController : UITableViewDelegate {
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        timelineComponent.targetWillDisplayEntry(indexPath.section)
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerCell = tableView.dequeueReusableCellWithIdentifier("PostHeader") as! PostSectionHeaderView
        
        let post = self.timelineComponent.content[section]
        headerCell.post = post
        
        return headerCell
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
}

extension TimelineViewController {
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
}

