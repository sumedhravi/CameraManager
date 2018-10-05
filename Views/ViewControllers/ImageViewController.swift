//
//  ImageViewController.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 17/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import Foundation
import UIKit

class ImageViewController: UIViewController {
    var image: UIImage?
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.isHidden = true
        
        guard let validImage = image else {
            return
        }
        
        self.imageView.image = validImage
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        guard !UserDefaultsHandler.shouldSaveMedia(), let image = image else {
            navigationController?.navigationBar.isHidden = false
            navigationController?.popViewController(animated: true)
            return
        }
        
        let alertVC = UIAlertController(title: "Save?", message: "Do you want to save this image to album?", preferredStyle: .alert)
        
        alertVC.addAction(UIAlertAction(title: "No", style: .destructive, handler: { (action) in
            CameraFileManager().deleteFile(atUrl: )
            self.navigationController?.navigationBar.isHidden = false
            self.navigationController?.popViewController(animated: true)
        }))
        alertVC.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) in
            CameraManager.saveImageToAlbum(image: image, completion: { (success) in
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else { return }
                    self.didSaveImage(success: success, completion: {
                        self.navigationController?.navigationBar.isHidden = false
                        self.navigationController?.popViewController(animated: true)
                    })
                    
                }
            })
        }))
        
        present(alertVC, animated: true, completion: nil)
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    private func didSaveImage(success: Bool,completion: (()->())?) {
        let title = success ? "Success": "Save Failed"
        let message = success ? "Image saved successfully" : "Could Not Save Image"
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alertVC.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in
            completion?()
        }))
        DispatchQueue.main.async {
            self.present(alertVC, animated: true)
        }
    }
}
