//
//  VideoMerger.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 27/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

final class VideoMerger: NSObject {
    
    //Merges Video Files represented by the URLs passed as the argument and returns the composite video asset and composition.
    func compositeVideo(fromVideoUrls videoUrls: [URL], videoSize: CGSize, exportQuality: VideoExportQuality)-> (asset: AVMutableComposition?, videoComposition: AVMutableVideoComposition?) {
        let mainComposition = AVMutableComposition()
        let mainInstruction = AVMutableVideoCompositionInstruction()
        var totalDuration = kCMTimeZero
        var prefferedTransform: CGAffineTransform!
        
        guard let compositeVideoTrack = mainComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return (nil,nil) }
        guard let compositeAudioTrack = mainComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return (nil,nil) }
        
        for url in videoUrls {
            let videoAsset = AVAsset(url: url)
            let videoAssetTrack = videoAsset.tracks(withMediaType: AVMediaType.video)[0]
            let audioAssetTrack = videoAsset.tracks(withMediaType: AVMediaType.audio)[0]
            prefferedTransform = videoAssetTrack.preferredTransform
            
            do {
                try compositeVideoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, videoAssetTrack.timeRange.duration), of: videoAssetTrack, at: totalDuration)
                try compositeAudioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, audioAssetTrack.timeRange.duration), of: audioAssetTrack, at: totalDuration)
                compositeVideoTrack.preferredTransform = prefferedTransform
            } catch {
                print("Error in merge")
                return(nil,nil)
            }
            
            let layerInstruction = videoCompositionInstruction(track: videoAssetTrack, asset: videoAsset,startTime: totalDuration,preferredVideoSize: videoSize)
            if url != videoUrls.last {
                layerInstruction.setOpacity(0.0, at: totalDuration + videoAsset.duration)
            }
            
            totalDuration = CMTimeAdd(totalDuration, videoAsset.duration)
            mainInstruction.layerInstructions.append(layerInstruction)
        }
        
        mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero,totalDuration)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [mainInstruction]
        videoComposition.frameDuration = CMTimeMake(1, 30)
        videoComposition.renderSize = videoSize.getSizeApplyingTransform(transform: prefferedTransform)
        
        return (mainComposition,videoComposition)
    }
    
    private func videoCompositionInstruction(track: AVAssetTrack, asset: AVAsset,startTime: CMTime,preferredVideoSize: CGSize)
        -> AVMutableVideoCompositionLayerInstruction {
            let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            let assetTrack = asset.tracks(withMediaType: .video)[0]
            let assetInfo = orientationFromTransform(assetTrack.preferredTransform)
            let size = preferredVideoSize.getSizeApplyingTransform(transform: assetTrack.preferredTransform)
            
            var scaleFactor: CGAffineTransform!
            var translationFix: CGAffineTransform!
            var scaleToFitRatio =  size.width / assetTrack.naturalSize.width
            
            if assetInfo.isPortrait {
                let widthRatio = size.width / assetTrack.naturalSize.height
                let heightRatio = size.height / assetTrack.naturalSize.width
                scaleToFitRatio = min(widthRatio,heightRatio)
                scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
                
                if heightRatio > widthRatio {
                    let yFix = (size.height - assetTrack.naturalSize.width * scaleToFitRatio)/2
                    translationFix = CGAffineTransform(translationX: 0, y: yFix)
                } else {
                    let xfix = (size.width - assetTrack.naturalSize.height * scaleToFitRatio)/2
                    translationFix = CGAffineTransform(translationX: xfix, y: 0)
                }
            } else {
                let widthRatio = size.width / assetTrack.naturalSize.width
                let heightRatio = size.height / assetTrack.naturalSize.height
                scaleToFitRatio = min(widthRatio,heightRatio)
                scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
                
                if heightRatio > widthRatio {
                    let yFix = (size.height - assetTrack.naturalSize.height * scaleToFitRatio)/2
                    translationFix = CGAffineTransform(translationX: 0, y: yFix)
                } else {
                    let xFix = (size.width - assetTrack.naturalSize.width * scaleToFitRatio)/2
                    translationFix = CGAffineTransform(translationX: xFix, y: 0)
                }
            }
            
            instruction.setTransform(assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(translationFix), at: startTime)
            return instruction
    }
    
    private func orientationFromTransform(_ transform: CGAffineTransform)
        -> (orientation: UIImageOrientation, isPortrait: Bool) {
            var assetOrientation = UIImageOrientation.up
            var isPortrait = false
            
            if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
                assetOrientation = .right
                isPortrait = true
            } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
                assetOrientation = .left
                isPortrait = true
            } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
                assetOrientation = .up
            } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
                assetOrientation = .down
            }
            return (assetOrientation, isPortrait)
    }
}

extension CGSize {
    func getSizeApplyingTransform(transform: CGAffineTransform) -> CGSize {
        var newSize = self.applying(transform)
        newSize.width = CGFloat(fabsf(Float(newSize.width)))
        newSize.height = CGFloat(fabsf(Float(newSize.height)))
        return newSize
    }
}
