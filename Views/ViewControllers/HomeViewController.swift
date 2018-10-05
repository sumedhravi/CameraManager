//
//  HomeViewController.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 01/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {

    @IBOutlet weak var listButton: UIButton!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    
    var fileManager = CameraFileManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let borderColor = UIColor(red: 34/255, green: 192/255, blue: 246/255, alpha: 1).cgColor
        listButton.layer.borderColor = borderColor
        listButton.layer.borderWidth = 2.0
        startButton.layer.borderColor = borderColor
        startButton.layer.borderWidth = 2.0
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupUI()
    }
    
    private func setupUI() {
        guard let savedFolder = fileManager.fetchSavedMergedVideosDirectory() else {
            listButton.isHidden = true
            countLabel.isHidden = true
            return
        }
        do {
            let fileArray = try FileManager.default.contentsOfDirectory(at: savedFolder, includingPropertiesForKeys: nil)
            countLabel.isHidden = fileArray.isEmpty
            listButton.isHidden = fileArray.isEmpty
            countLabel.text = "\(fileArray.count) Videos saved"
        } catch {
            print(error)
            countLabel.isHidden = true
            listButton.isHidden = true
        }
    }

}
