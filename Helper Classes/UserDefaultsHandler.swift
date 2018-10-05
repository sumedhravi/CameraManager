//
//  UserDefaultsHandler.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 24/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import Foundation

class UserDefaultsHandler: NSObject {
    
    static private let outputModeString = "OutputMode"
    static private let cameraQualityModeString = "CameraQuality"
    static private let videoExportQualityModeString = "ExportQuality"
    static private let allowEditString = "ShouldAllowEdit"
    static private let shouldSaveMediaString = "SaveMedia"
    
    static let defaults = UserDefaults.standard
    
    class func defaultOutputMode() -> Int {
        if defaults.value(forKey: outputModeString) == nil {
            setDefaultOutputMode(value: 0)
        }
        return defaults.integer(forKey: outputModeString)
    }
    
    class func defaultCameraOutputQualityMode() -> Int {
        if defaults.value(forKey: cameraQualityModeString) == nil {
            setCameraOutputQualityMode(value: 0)
        }
        return defaults.integer(forKey: cameraQualityModeString)
    }
    
    class func defaultVideoExportQuality() -> Int {
        if defaults.value(forKey: videoExportQualityModeString) == nil {
            setVideoExportQuality(value: 0)
        }
        return defaults.integer(forKey: videoExportQualityModeString)
    }
    
    class func shouldAllowEdit() -> Bool {
        if defaults.value(forKey: allowEditString) == nil {
            setShouldAllowEdit(value: false)
        }
        return defaults.bool(forKey: allowEditString)
    }
    
    class func shouldSaveMedia() -> Bool {
        if defaults.value(forKey: shouldSaveMediaString) == nil {
            setShouldSaveMedia(value: true)
        }
        return defaults.bool(forKey: shouldSaveMediaString)
    }
    
    class func setDefaultOutputMode(value: Int){
        defaults.set(value, forKey: outputModeString)
    }
    
    class func setCameraOutputQualityMode(value: Int){
        defaults.set(value, forKey: cameraQualityModeString)
    }
    
    class func setVideoExportQuality(value: Int){
        defaults.set(value, forKey: videoExportQualityModeString)
    }
    
    class func setShouldAllowEdit(value: Bool){
        defaults.set(value, forKey: allowEditString)
    }
    
    class func setShouldSaveMedia(value: Bool) {
        defaults.set(value, forKey: shouldSaveMediaString)
    }
}
