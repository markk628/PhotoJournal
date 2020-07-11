//
//  PhotoJournalViewController.swift
//  PhotoJournal
//
//  Created by Erick Wesley Espinoza on 4/25/20.
//  Copyright © 2020 HazeStudio. All rights reserved.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

// animations we use through out the app
enum PhotoVCTransitionAnims {
    case PhotoListToJournal
    case JournalToPhotoList
    case PhotoListToMediaSelector
    case MediaSelectorToPhotoList
    case MediaSelectorToJournal
}

class PhotoJournalViewController: UIViewController {
    let photoCollectionView = PhotoCollectionView()
    let journalView = JournalView()
    let mediaSelectorview = MediaSelectorView()
    let screen = UIScreen.main
    var leadingAnchor: NSLayoutConstraint? = nil
    var topAnchor: NSLayoutConstraint? = nil
    let db = Firestore.firestore()
    let storage = Storage.storage()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    func setupView(){
        photoCollectionView.delegate = self
        self.view.addSubview(photoCollectionView)
        self.view.addSubview(journalView)
        self.view.addSubview(mediaSelectorview)
        mediaSelectorview.delegate = self
        self.title = "Photo Journal"
        // assign and activate the Achors we will animate to make everything move.
        topAnchor = photoCollectionView.topAnchor.constraint(equalTo: self.view.topAnchor)
        leadingAnchor = photoCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor)
        topAnchor?.isActive = true
        leadingAnchor?.isActive = true
        
        NSLayoutConstraint.activate([
            photoCollectionView.heightAnchor.constraint(equalToConstant: screen.bounds.height),
            photoCollectionView.widthAnchor.constraint(equalToConstant: screen.bounds.width),
            
            journalView.topAnchor.constraint(equalTo: self.view.topAnchor),
            journalView.leadingAnchor.constraint(equalTo: self.photoCollectionView.trailingAnchor),
            journalView.widthAnchor.constraint(equalToConstant: screen.bounds.width),
            journalView.heightAnchor.constraint(equalToConstant: screen.bounds.height),
            
            
            mediaSelectorview.topAnchor.constraint(equalTo: self.photoCollectionView.bottomAnchor),
            mediaSelectorview.leadingAnchor.constraint(equalTo: self.photoCollectionView.leadingAnchor),
            mediaSelectorview.widthAnchor.constraint(equalToConstant: screen.bounds.width),
            mediaSelectorview.heightAnchor.constraint(equalToConstant: screen.bounds.height)
        ])
        
        
        let logoutBarButton = UIBarButtonItem(title: "Logout", style: .done, target: self, action: #selector(logout))
        
        self.navigationItem.leftBarButtonItems = [logoutBarButton]
        
        let addEntryBarButton = UIBarButtonItem(title: "＋", style: .plain, target: self, action: #selector(gotoMediaSelector))
        
        self.navigationItem.rightBarButtonItems = [addEntryBarButton]
        
    }
    // function that takes us to the Media Selector screen
    @objc func gotoMediaSelector(){
        self.animateViewFrame(animation: .PhotoListToMediaSelector)
    }
    // function to add an entry to our firebase
    @objc func addEntry(){
        showSpinner(onView: self.view)
        if let userId = UserDefaults.standard.string(forKey: "UserId") {
            var ref: DocumentReference? = nil
            let textToSave = self.journalView.journalEntryTextView.text!
            let storageRef = storage.reference()
            let imageData = journalView.photoView.image?.pngData()
            let imageRef = storageRef.child("images/\(NSUUID().uuidString)")
            
            let uploadTask = imageRef.putData(imageData!, metadata: nil) { metaData, error in
                if error != nil {
                    print("Error uploading image Error: \(error!.localizedDescription)")
                }
            }
            
            uploadTask.observe(.success) { (snapshot) in
                // get image URL
                imageRef.downloadURL { url, error in
                    guard let downloadURL = url else {
                        print("Download URL failed")
                        return
                    }
                    let date = NSDate()
                    let dateFormatter = DateFormatter()
                    
                    dateFormatter.dateFormat = "M/d/yyyy, HH:mm a"
                    dateFormatter.timeZone = NSTimeZone() as TimeZone
                    let localDate = dateFormatter.string(from: date as Date)
                    
                    ref = self.db.collection("\(userId)").addDocument(data: ["imagePath" : "\(downloadURL)", "textEntry": "\(textToSave)", "timeStamp": "\(localDate)"]) { error in
                        if let error = error {
                            print("Error saving document: \(error.localizedDescription)")
                        } else {
                            print("Document added with ID \(ref!.documentID)")
                        }
                    }
                    self.removeSpinner()
                    self.animateViewFrame(animation: .JournalToPhotoList)
                }
                self.dismissKeyboard()
            }
        }
        
    }
    
    // function to log out
    @objc func logout(){
        let firebaseAuth = Auth.auth()
        
        do {
            try firebaseAuth.signOut()
        } catch let error as NSError {
            print("Error logging out: \(error.localizedDescription)")
            return
        }
        
        UserDefaults.standard.removeObject(forKey: "UserId")
        self.navigationController?.popViewController(animated: true)
        self.navigationController?.viewControllers = [LoginSignUpViewController()]
    }
    
    // function to cancel when we're at the journal screen. takes us back to the Collection view
    @objc func cancel(){
        self.animateViewFrame(animation: .JournalToPhotoList)
        dismissKeyboard()
    }
    
    // function that handels cancel being pressed from the MediaSelector
    @objc func cancelFromMediaSelector(){
        self.animateViewFrame(animation: .MediaSelectorToPhotoList)
    }
    
    // function in charge of the animation logic.
    func animateViewFrame(animation: PhotoVCTransitionAnims){
        // switch over the possible animations we could use.
        switch animation {
        // if we are going from the Collection view to th journal View ex. we tapped on a cell
        case .PhotoListToJournal:
            UIView.animate(withDuration: 0.25) {
                self.leadingAnchor?.isActive = false
                self.leadingAnchor = self.photoCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: -1 * self.screen.bounds.width)
                self.leadingAnchor?.isActive = true
                self.view.layoutIfNeeded()
                
                let cancelBarButton = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(self.cancel))
                
                let saveBarButton = UIBarButtonItem(title: "Update", style: .done, target: self, action: #selector(self.addEntry))
                
                self.navigationItem.rightBarButtonItems = [saveBarButton]
                self.navigationItem.leftBarButtonItems = [cancelBarButton]
                self.hideKeyboardTapped()
            }
            
            break
        // if we are going from the journal back to the Collection view ex. we clicked cancel, save or update
        case .JournalToPhotoList:
            UIView.animate(withDuration: 0.25) {
                         self.leadingAnchor?.isActive = false
                self.leadingAnchor = self.photoCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor)
                self.leadingAnchor?.isActive = true
                self.view.layoutIfNeeded()
                let addEntryBarButton = UIBarButtonItem(title: "＋", style: .plain, target: self, action: #selector(self.gotoMediaSelector))
                self.journalView.journalEntryTextView.text = ""
                self.navigationItem.rightBarButtonItems = [addEntryBarButton]
                
                let logoutBarButton = UIBarButtonItem(title: "Logout", style: .done, target: self, action: #selector(self.logout))
                
                self.navigationItem.leftBarButtonItems = [logoutBarButton]
                for gesture in self.view.gestureRecognizers!{
                    self.view.removeGestureRecognizer(gesture)
                }
            }
            break
        // if we are going to the media selector from the collectionView ex. we clicked the "+" button
        case .PhotoListToMediaSelector:
            UIView.animate(withDuration: 0.25) {
                self.topAnchor?.isActive = false
                self.topAnchor = self.photoCollectionView.topAnchor.constraint(equalTo: self.view.topAnchor, constant:  -1*self.screen.bounds.height)
                self.topAnchor?.isActive = true
                self.view.layoutIfNeeded()
                let addEntryBarButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelFromMediaSelector))
                self.navigationItem.rightBarButtonItems = [addEntryBarButton]
                self.navigationItem.leftBarButtonItems = []
            }
            break
        // if we clicked cancel from the Media selector
        case .MediaSelectorToPhotoList:
            UIView.animate(withDuration: 0.25) {
                self.topAnchor?.isActive = false
                 self.topAnchor = self.photoCollectionView.topAnchor.constraint(equalTo: self.view.topAnchor)
                 self.leadingAnchor?.isActive = true
                 self.view.layoutIfNeeded()
                 let addEntryBarButton = UIBarButtonItem(title: "＋", style: .plain, target: self, action: #selector(self.gotoMediaSelector))
                 self.navigationItem.rightBarButtonItems = [addEntryBarButton]
                 let logoutBarButton = UIBarButtonItem(title: "Logout", style: .done, target: self, action: #selector(self.logout))
                 self.navigationItem.leftBarButtonItems = [logoutBarButton]
            }
            break
        // Once we tap what kind of media we want to use then we proceed to the journal view
        case .MediaSelectorToJournal:
            UIView.animate(withDuration: 0.25) {
                
                self.leadingAnchor?.isActive = false
                self.leadingAnchor = self.photoCollectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: -1 * self.screen.bounds.width)
                self.leadingAnchor?.isActive = true
                self.view.layoutIfNeeded()
                
                let cancelBarButton = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(self.cancel))
                
                let saveBarButton = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(self.addEntry))
                
                self.navigationItem.rightBarButtonItems = [saveBarButton]
                self.navigationItem.leftBarButtonItems = [cancelBarButton]
                self.hideKeyboardTapped()
            }
            
            break
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // hides that back button that is there by default.
        self.navigationItem.setHidesBackButton(true, animated: true)
    }
}

extension PhotoJournalViewController: UIImagePickerControllerDelegate{
    // handles logic after a user has picked an image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        guard let image = info[.editedImage] as? UIImage else {
            print("No image found")
            return
        }
        // once the picker is dismissed and we have an image we change the journal image and we navigate to it.
        picker.dismiss(animated: true) {
            self.journalView.photoView.image = image
            self.animateViewFrame(animation: .MediaSelectorToJournal)
        }
    }
}
extension PhotoJournalViewController: UINavigationControllerDelegate{
    
}

