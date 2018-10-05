//
//  SettingsViewController.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 24/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import Foundation
import UIKit

enum CameraSettingsOptions: Int {
    case defaultMode = 0
    case recordingQuality
    case exportQuality
    case shouldAllowEditing
    case saveMediaAutomatically
    
    static let count = 5
    
    var requiresPicker: Bool {
        switch self {
        case .shouldAllowEditing:
            return false
        case .saveMediaAutomatically:
            return false
        default:
            return true
        }
    }
    
    var titleText: String {
        switch  self {
        case .defaultMode:
            return "Default Mode"
        case .recordingQuality:
            return "Camera Quality"
        case .exportQuality:
            return "Video Export Quality"
        case .shouldAllowEditing:
            return "Allow Editing"
        case .saveMediaAutomatically:
            return "Save Media Automatically"
        }
    }
    var options: [String] {
        switch  self {
        case .defaultMode:
            return CameraOutputMode.optionArray
        case .recordingQuality:
            return CameraOutputQuality.optionArray
        case .exportQuality:
            return VideoExportQuality.optionArray
        case .shouldAllowEditing:
            return []
        case .saveMediaAutomatically:
            return []
        }
    }
    
    var selectedOptionIndex: Int {
        switch  self {
        case .defaultMode:
            return UserDefaultsHandler.defaultOutputMode()
        case .recordingQuality:
            return UserDefaultsHandler.defaultCameraOutputQualityMode()
        case .exportQuality:
            return UserDefaultsHandler.defaultVideoExportQuality()
        case .shouldAllowEditing:
            return UserDefaultsHandler.shouldAllowEdit() ? 1 : 0
        case .saveMediaAutomatically:
            return UserDefaultsHandler.shouldSaveMedia() ? 1 : 0
        }
    }
    
    func updateValue(withSelectedIndex index: Int) {
        switch  self {
        case .defaultMode:
            guard let _ = CameraOutputMode(rawValue: index) else { return }
            UserDefaultsHandler.setDefaultOutputMode(value: index)
        case .recordingQuality:
            guard let _ = CameraOutputQuality(rawValue: index) else { return }
            UserDefaultsHandler.setCameraOutputQualityMode(value: index)
        case .exportQuality:
            guard let _ = VideoExportQuality(rawValue: index) else { return }
            UserDefaultsHandler.setVideoExportQuality(value: index)
        case .shouldAllowEditing:
            UserDefaultsHandler.setShouldAllowEdit(value: index == 0 ? false: true)
        case .saveMediaAutomatically:
            UserDefaultsHandler.setShouldSaveMedia(value: index == 0 ? false: true)
        }
    }
}

class SettingsViewController: UIViewController {

    @IBOutlet weak var settingsTableView: UITableView!
    private var selectedOptions = Array.init(repeating: -1, count: CameraSettingsOptions.count)
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        updateSettings()
    }

    private func updateSettings() {
        for index in 0 ..< selectedOptions.count {
            guard let setting = CameraSettingsOptions(rawValue: index) else { continue }
            if let cell = settingsTableView.cellForRow(at: IndexPath(row: index, section: 0)) as? SettingsTableViewCell, let selectedValue = cell.selectedIndexValue {
                setting.updateValue(withSelectedIndex: selectedValue)
            } else {
                setting.updateValue(withSelectedIndex: selectedOptions[index])
            }
        }
    }
}

extension SettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CameraSettingsOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: type(of: SettingsTableViewCell())), for: indexPath) as? SettingsTableViewCell else { return UITableViewCell() }
        guard let option = CameraSettingsOptions(rawValue: indexPath.row) else { return cell }
        var selectedOption: Int!
        cell.requiresPickerView = option.requiresPicker
        cell.titleLabel.text = option.titleText
        guard indexPath.row < selectedOptions.count else {
            return cell
        }
        if selectedOptions[indexPath.row] != -1 {
            selectedOption = selectedOptions[indexPath.row]
        } else {
            selectedOption = option.selectedOptionIndex
            selectedOptions[indexPath.row] = selectedOption
        }
        if option.requiresPicker {
            cell.setPickerViewItems(items: option.options, selectedOption: selectedOption)
        } else {
            cell.setSwitchValue(isOn: selectedOption == 0 ? false: true)
        }
        return cell
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 170
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? SettingsTableViewCell, let value = cell.selectedIndexValue, indexPath.section == 0, indexPath.row < selectedOptions.count else { return }
        selectedOptions[indexPath.row] = value
    }
}
