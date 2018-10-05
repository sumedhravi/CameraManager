//
//  AssetHandler.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 23/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

final class AssetHandler: NSObject {
    var assetUrls: [URL]?
    var preferredSize: CGSize
    
    init(withAssetUrls urls: [URL],size: CGSize) {
        assetUrls = urls
        preferredSize = size
        
        super.init()
    }
    
    public func getImagesForAssets() -> [UIImage?] {
        var images = [UIImage?]()
       
        guard let assetUrls = assetUrls else { return [nil] }
        
        for url in assetUrls {
            let image = getThumbnailImage(forUrl: url, preferredSize: preferredSize)
            if (images.append(image)) == nil {
                images = [image]
            }
        }
        return images
    }
    
    public func getThumbnailImage(forUrl url: URL,preferredSize: CGSize) -> UIImage? {
        let asset: AVAsset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = preferredSize
        
        do {
            let thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(1, 60) , actualTime: nil)
            return UIImage(cgImage: thumbnailImage)
        } catch let error {
            print(error)
        }
        return nil
    }
    
}
