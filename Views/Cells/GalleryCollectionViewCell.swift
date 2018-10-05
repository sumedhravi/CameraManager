//
//  GalleryCollectionViewCell.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 23/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import UIKit

class GalleryCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    var index: Int = 0
    var didDeleteAssetBlock: ((Int) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()

    }
    
    @IBAction func didDeleteAsset(_ sender: Any) {
        didDeleteAssetBlock?(index)
    }
}
