//
//  GalleryView.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 23/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import UIKit

class GalleryView: UIView {
    
    private let buttonheight: CGFloat = 40.0
    
    var images: [UIImage?]
    
    var collectionView: UICollectionView!
    var didDeleteAssetBlock: ((Int) -> Void)?
    var didRearrangeAssetsBlock: ((Int, Int) -> ())?
    var progressBlock: (() -> Void)?
    var closeBlock: (() -> Void)?
    
    init(frame: CGRect,images: [UIImage?]) {
        self.images = images
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: 100, height: 100)
        flowLayout.footerReferenceSize = CGSize(width: 60, height: frame.height)
        flowLayout.scrollDirection = .horizontal
        collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height-buttonheight*2), collectionViewLayout: flowLayout)
        
        super.init(frame: frame)
        setupCollectionView()
        addCloseButton()
        addProgressButton()
        collectionView.dataSource = self
        collectionView.delegate = self
//        backgroundColor = .black
        addSubview(collectionView)
        collectionView.reloadData()
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = true
        layer.cornerRadius = 5
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setDataSource(imageArray: [UIImage]) {
        images = imageArray
        collectionView.reloadData()
    }
    
    private func setupCollectionView() {
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = true
        collectionView.clipsToBounds = true
        collectionView.isScrollEnabled = true
        collectionView.backgroundColor = UIColor.darkGray
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongGesture))
        self.collectionView.addGestureRecognizer(longPressGesture)
        addSubview(collectionView)
        let leadingConstraint = NSLayoutConstraint(item: collectionView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0.0)
        let trailingConstraint = NSLayoutConstraint(item: collectionView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        let topConstraint = NSLayoutConstraint(item: collectionView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0)
        let heightConstraint = NSLayoutConstraint(item: collectionView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: frame.size.height - 2 * buttonheight)
//        collectionView.addConstraint(heightConstraint)
//        addConstraints([leadingConstraint, trailingConstraint, topConstraint])
        NSLayoutConstraint.activate([leadingConstraint,trailingConstraint,topConstraint,heightConstraint])
        collectionView.register(UINib.init(nibName: "GalleryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "GalleryCollectionViewCell")
        collectionView.register(UINib(nibName: "GalleryCollectionFooterView", bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "GalleryCollectionFooterView")
        collectionView.contentInset = UIEdgeInsetsMake(0, 20, 20, 0)
    }
    
    private func addCloseButton() {
        let buttonFrame = CGRect(x: 0, y: collectionView.bounds.height, width: frame.width, height: buttonheight)
        let button = UIButton(frame: buttonFrame)
        button.backgroundColor = UIColor(red: 255/255, green: 80/255, blue: 103/255, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("Resume Recording", for: .normal)
        button.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        let leadingConstraint = NSLayoutConstraint(item: button, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0.0)
        let trailingConstraint = NSLayoutConstraint(item: button, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        let topConstraint = NSLayoutConstraint(item: button, attribute: .top, relatedBy: .equal, toItem: collectionView, attribute: .bottom, multiplier: 1.0, constant: 0.0)
        let heightConstraint = NSLayoutConstraint(item: button, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: buttonheight)
//        button.addConstraint(heightConstraint)
        NSLayoutConstraint.activate([leadingConstraint,trailingConstraint,topConstraint,heightConstraint])
        
    }
    
    private func addProgressButton() {
        let buttonFrame = CGRect(x: 0, y: collectionView.bounds.height + buttonheight, width: frame.width, height: buttonheight)
        let button = UIButton(frame: buttonFrame)
        button.backgroundColor = UIColor(red: 56/255, green: 214/255, blue: 134/255, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("Export Video", for: .normal)
        button.addTarget(self, action: #selector(progressButtonClicked), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        let leadingConstraint = NSLayoutConstraint(item: button, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0.0)
        let trailingConstraint = NSLayoutConstraint(item: button, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        let bottomConstraint = NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0)
        let heightConstraint = NSLayoutConstraint(item: button, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: buttonheight)
        //        button.addConstraint(heightConstraint)
        NSLayoutConstraint.activate([leadingConstraint,trailingConstraint,bottomConstraint,heightConstraint])
    }
    
    @objc private func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        switch(gesture.state) {
            
        case UIGestureRecognizerState.began:
            guard let selectedIndexPath = self.collectionView.indexPathForItem(at: gesture.location(in: self.collectionView)) else {
                break
            }
            collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case UIGestureRecognizerState.changed:
            collectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case UIGestureRecognizerState.ended:
            self.collectionView.endInteractiveMovement()
        default:
            collectionView.cancelInteractiveMovement()
        }
    }
    
    @objc func closeButtonClicked() {
        closeBlock?()
    }
    
    @objc func progressButtonClicked() {
        progressBlock?()
    }
}

extension GalleryView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section == 0 else { return 0 }
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCollectionViewCell", for: indexPath) as? GalleryCollectionViewCell else { return UICollectionViewCell() }
        cell.imageView.image = images[indexPath.item]
        cell.didDeleteAssetBlock = { [weak self] (index) in
            let alertController = UIAlertController(title: "Delete?", message: "Do you want to discard this clip?", preferredStyle: UIAlertControllerStyle.alert)
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default))
            
            alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: { [weak self] (action) in
                guard let `self` = self else { return }
                if index < self.images.count {
                    self.images.remove(at: index)
                    self.collectionView.reloadData()
                    self.didDeleteAssetBlock?(index)
                }
            }))
            self?.window?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
        cell.layer.borderWidth = 2.0
        cell.layer.borderColor = UIColor.black.cgColor
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard indexPath.section == 0, let cell = cell as? GalleryCollectionViewCell else { return }
        cell.index = indexPath.item
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let temp = images[sourceIndexPath.item]
        
        if sourceIndexPath.item < destinationIndexPath.item {
            for item in sourceIndexPath.item..<destinationIndexPath.item{
                images[item] = images[item+1]
            }
            images[destinationIndexPath.item] = temp
        }
        else{
            for item in (destinationIndexPath.item+1...sourceIndexPath.item).reversed(){
                images[item] = images[item-1]
            }
        }
        images[destinationIndexPath.item] = temp
        didRearrangeAssetsBlock?(sourceIndexPath.item,destinationIndexPath.item)
    }
}
