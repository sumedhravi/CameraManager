//
//  VideoEncoder.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 25/07/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import Foundation
import AVFoundation
import CoreVideo
class CameraFileManager: NSObject {
    
    let fileManager = FileManager.default
    let intermediateVideosFolderName = "IntermediateVideos"
    let exportedVideosFolderName = "Exported Videos"
    let documentsDirectoryFolderName = "JournalVideos"
        
    var documentsUrl: URL? {
        return fileManager.urls(for: .documentDirectory , in: .userDomainMask).first
    }
    
    var cacheUrl: URL? {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    
    override init() {
        super.init()
        
    }
    
    func createDirectory(url: URL) -> URL? {
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                return url
            } catch {
                print(error)
                return nil
            }
        } else {
            return url
        }
    }
    
    func createFileinCacheDirectory(fileName: String) -> URL? {
        guard let cacheUrl = cacheUrl  else {
            print("Could not fetch cache folder")
            return nil
        }
        let filePath = cacheUrl.appendingPathComponent(fileName)
        guard let fileUrl = createDirectory(url: filePath) else {
            print("Could not create directory")
            return nil
        }
        return fileUrl
    }
    
    func createDocumentsDirectoryFolder(name: String) -> URL? {
        guard let documentsUrl = documentsUrl  else {
            print("Could not fetch documents directory")
            return nil
        }
        let filePath = documentsUrl.appendingPathComponent(name)
        guard let url = createDirectory(url: filePath) else {
            print("Could not create Documents Directory path")
            return nil
        }
        
        return url
    }
    
    func fetchSavedMergedVideosDirectory() -> URL? {
        guard let documentsUrl = createDocumentsDirectoryFolder(name: documentsDirectoryFolderName) else { return nil }
        return documentsUrl
    }
    
    @discardableResult func deleteFile(atUrl url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            print(error)
            return false
        }
    }
}
