//
//  VideoExporter.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 23/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

final class VideoExporter: NSObject {
    
    let fileManager = CameraFileManager()
    let videoMerger = VideoMerger()
    
    public func exportVideo(urls:[URL], exportQuality: VideoExportQuality, size: CGSize, completionHandler : @escaping (URL?,Error?)->Void) {
        let mergedVideo = videoMerger.compositeVideo(fromVideoUrls: urls, videoSize: size, exportQuality: exportQuality)
        guard let asset = mergedVideo.asset, let composition = mergedVideo.videoComposition else {
            print("Error merging videos")
            //TODO:Error
            completionHandler(nil,NSError())
            return
        }
        exportVideo(asset: asset, videoComposition: composition, exportQuality: exportQuality, completion: completionHandler)
    }
    
    //Exports Video Asset to required format and returns the URL to the exported video
    public func exportVideo(asset: AVMutableComposition, videoComposition: AVMutableVideoComposition, exportQuality: VideoExportQuality, completion: @escaping (URL?,Error?) -> Void) {
        var preset: String!
        switch exportQuality {
        case .low:
            preset = AVAssetExportPresetLowQuality
        case .medium:
            preset = AVAssetExportPresetMediumQuality
        case .high:
            preset = AVAssetExportPresetHighestQuality
        }
        guard let exporter = AVAssetExportSession(asset: asset, presetName: preset) else {
            completion(nil,nil)
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        guard let outputUrl = fileManager.createFileinCacheDirectory(fileName: fileManager.exportedVideosFolderName) else {
            print("Could not get Output URL")
            completion(nil, nil)
            return
        }
        
        exporter.outputURL = outputUrl.appendingPathComponent("\(dateString).mov")
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition
        
        // Perform the Export
        exporter.exportAsynchronously() {
            DispatchQueue.main.async {
                if exporter.status == .completed {
                    completion(exporter.outputURL,nil)
                }
                else {
                    completion(nil,exporter.error)
                    print(exporter.status.rawValue.description)
                    print(exporter.error)
                }
            }
        }
    }
}

