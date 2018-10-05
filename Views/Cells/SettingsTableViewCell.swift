//
//  SettingsTableViewCell.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 24/08/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var selectionSwitch: UISwitch!
    
    public var selectedIndexValue: Int? {
        if requiresPickerView {
            return pickerView.selectedRow(inComponent: 0)
        } else {
            guard let isOn = isSwitchOn else { return nil }
            return isOn ? 1: 0
        }
    }
    
    var requiresPickerView: Bool = true {
        didSet {
            pickerView.isHidden = !requiresPickerView
            selectionSwitch.isHidden = requiresPickerView
            if requiresPickerView {
                bringSubview(toFront: pickerView)
            } else {
                bringSubview(toFront: selectionSwitch)
            }
        }
    }
    
    private var pickerViewOptions: [String] = []
    private var isSwitchOn: Bool?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionSwitch.isHidden = requiresPickerView
        pickerView.isHidden = !requiresPickerView
        // Initialization code
        pickerView.dataSource = self
        pickerView.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setPickerViewItems(items: [String],selectedOption: Int) {
        pickerViewOptions = items
        pickerView.reloadComponent(0)
        pickerView.selectRow(selectedOption, inComponent: 0, animated: false)
    }
    
    func setSwitchValue(isOn: Bool) {
        if !requiresPickerView && selectionSwitch.isHidden == false {
            selectionSwitch.isOn = isOn
            isSwitchOn = isOn
        }
    }
    
    @IBAction func didToggleSwitch(_ sender: Any) {
        guard let switchButton = sender as? UISwitch else { return }
        isSwitchOn = switchButton.isOn
    }
}

extension SettingsTableViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerViewOptions.count
    }
}

extension SettingsTableViewCell: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerViewOptions[row]
    }
}
