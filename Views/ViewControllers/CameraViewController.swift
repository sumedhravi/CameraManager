//
//  ViewController.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 25/07/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {

    @IBOutlet weak var videoCaptureView: UIView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var cameraModeControl: UISegmentedControl!
    @IBOutlet weak var previewImageView: UIImageView!
    
    let cameraManager = CameraManager.sharedInstance
    
    var galleryView: GalleryView?
    private var activityIndicator: UIActivityIndicatorView?
    private var capturedImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraManager.writeFilesToPhoneLibrary = false
        if cameraManager.isCameraReady {
            addVideoPreviewView(mode: nil)
            cameraManager.recordingDelegate = self
            cameraManager.imageCaptureDelegate = self
        } else {
            //Request permission
            cameraManager.requestVideoRecordingPermissions { [weak self] (accessGranted) in
                guard let `self` = self else { return }
                if accessGranted {
                    
                    self.addVideoPreviewView(mode: nil)
                    self.cameraManager.recordingDelegate = self
                    self.cameraManager.imageCaptureDelegate = self
                } else {
                    self.cameraAccessDenied(type: PermissionsManager.PermissionType.video)
                    //Hide Buttons
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        positionCameraPreview()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        timeLabel.isHidden = true
        startButton.isEnabled = true
        setupUI()
        cameraManager.resumeSession(){
            DispatchQueue.main.async {
                self.updateUIForCameraMode(mode: self.cameraManager.cameraOutputMode)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        cameraManager.stopAndRemoveSession()
        activityIndicator = nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (context) in
            if let galleryView = self.galleryView {
                if self.view.subviews.contains(galleryView) {
                    galleryView.frame = CGRect(x: 0, y: size.height-240, width: size.width, height: 240)
                    self.galleryView = galleryView
                }
            }
            if let activityIndicator = self.activityIndicator {
                if self.view.subviews.contains(activityIndicator) {
                    activityIndicator.frame = UIScreen.main.bounds
                    activityIndicator.center = CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
                }
            }
            
        }) { (context) in
            
        }
    }
    
    @IBAction func startRecord(_ sender: Any) {
        if cameraManager.cameraOutputMode == .video {
            if !startButton.isSelected {
                cameraManager.startRecording()
            } else {
                cameraManager.pauseRecording()
            }
        } else {
            cameraManager.capturePhoto(withPreviewSize: previewImageView.frame.size)
        }
    }
    
    @IBAction func stopRecord(_ sender: Any) {
        cameraManager.stopRecording(discardVideo: true)
        startActivityIndicator()
    }
    
    @IBAction func switchCamera(_ sender: Any) {
        cameraManager.changeCameraPosition()
        handleButtonStates()
    }
    
    @IBAction func clickedFlashButton(_ sender: Any) {
        setFlashImage(state: cameraManager.changeIlluminationMode())
    }
    
    @IBAction func toggleCameraMode(_ sender: Any) {
        guard let button = sender as? UISegmentedControl, let mode = CameraOutputMode(rawValue: button.selectedSegmentIndex % 2) else { return }
        changeCameraMode(mode: mode)
        setFlashImage(state: cameraManager.illuminationState)
    }
    
    @IBAction func pressedPreviewImage(_ sender: UIGestureRecognizer) {
        let vc: ImageViewController? = self.storyboard?.instantiateViewController(withIdentifier: "ImageViewController") as? ImageViewController
                if let validVC: ImageViewController = vc,
                    let capturedImage = capturedImage {
                    validVC.image = capturedImage
        
                        self.navigationController?.pushViewController(validVC, animated: true)
                    }
    }
    
    
    private func setupUI() {
        videoCaptureView?.contentMode = .scaleToFill
        startButton.isSelected = false
        stopButton.isEnabled = false
    }
    
    private func addVideoPreviewView(mode: CameraOutputMode?) {
        guard let cameraMode = (mode != nil) ? mode : CameraOutputMode(rawValue: UserDefaultsHandler.defaultOutputMode()) else { return }
        cameraManager.addVideoPreviewToView(videoCaptureView, cameraMode: cameraMode,completion: {
            DispatchQueue.main.sync {
                self.updateUIForCameraMode(mode: self.cameraManager.cameraOutputMode)
                self.setFlashImage(state: self.cameraManager.illuminationState)
            }
        })
    }
    
    private func positionCameraPreview() {
//            previewLayer?.videoGravity = .resizeAspectFill
//            previewLayer?.frame = videoCaptureView.bounds
//            self.previewLayer?.position = CGPoint(x: self.videoCaptureView.bounds.midX, y: self.videoCaptureView.bounds.midY)
//        cameraPreviewView?.previewLayer.videoGravity = .resizeAspectFill
//        cameraPreviewView?.frame = videoCaptureView.bounds
        
    }
    
    private func setFlashImage(state: CameraFlashMode) {
        switch state {
        case .off:
            flashButton.setImage(UIImage(named: "icoFlashOff"), for: .normal)
        case .on :
            flashButton.setImage(UIImage(named: "icoFlashOn"), for: .normal)
        case .auto:
            flashButton.setImage(UIImage(named: "icoFlashAuto"), for: .normal)
        }
    }
    
    private func showPlayerScreen(with videoUrl: URL) {
        guard let playerVC = self.storyboard?.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController else { return }
        playerVC.videoUrl = videoUrl
        playerVC.shouldAllowSave = true
        
//            navigationController?.pushViewController(playerVC, animated: true)
        present(playerVC, animated: true)
    }
    
    private func handleButtonStates() {
        if let flash = cameraManager.hasTorchOrFlash {
            flashButton.isEnabled = flash
        } else {
            flashButton.isEnabled = false
        }
        switchCameraButton.isEnabled = cameraManager.hasFrontCamera
        switchCameraButton.isHidden = !cameraManager.canChangeCameraPosition
        cameraModeControl.selectedSegmentIndex = cameraManager.cameraOutputMode.rawValue
    }
    
    func cameraAccessDenied(type: PermissionsManager.PermissionType? = nil) {
        let message = type?.errorMessage ?? "Please enable access to camera and microphone."
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Permissions needed", message: message, preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Go to Settings", style: UIAlertActionStyle.default, handler: { (action) in
                guard let url = URL(string: UIApplicationOpenSettingsURLString), UIApplication.shared.canOpenURL(url) else { return }
                
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }))
            self.present(alertController, animated: true)
        }
    }
    
    private func changeCameraMode(mode: CameraOutputMode) {
        cameraManager.cameraOutputMode = mode
        updateUIForCameraMode(mode: cameraManager.cameraOutputMode)
    }
    
    private func updateUIForCameraMode(mode: CameraOutputMode) {
        switch mode {
        case .video:
            stopButton.isHidden = false
            previewImageView.isHidden = true
            stopButton.isEnabled = cameraManager.isRecordingSessionInProgress
        case .stillImage:
            stopButton.isHidden = true
            timeLabel.isHidden = true
        }
        startButton.isSelected = false
        startButton.isEnabled = true
        handleButtonStates()
    }
    
    private func showAlert(title: String, message: String,completion: (()->())?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: completion)
    }
    
    func startActivityIndicator() {
        guard let spinner = activityIndicator else {
            activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
            activityIndicator?.frame = UIScreen.main.bounds
            activityIndicator?.center = CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
            activityIndicator?.hidesWhenStopped = true
            activityIndicator?.backgroundColor = UIColor(white: 0, alpha: 0.3)
            self.view.addSubview(activityIndicator!)
            view.bringSubview(toFront: activityIndicator!)
            activityIndicator?.startAnimating()
            return
        }
        spinner.frame = UIScreen.main.bounds
        spinner.center = CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)

        view.addSubview(spinner)
        view.bringSubview(toFront: spinner)
        spinner.startAnimating()
    }
    
    func stopActivityIndicator() {
        activityIndicator?.stopAnimating()
        activityIndicator?.removeFromSuperview()
    }
}

extension CameraViewController: CameraMangerRecordingDelegate, CameraPhotoCaptureDelegate {
    
    func didStartRecording() {
        startButton.isSelected = true
        stopButton.isEnabled = true
        handleButtonStates()
    }
    
    func didPauseRecording(withIndividualVideoUrls videoUrls: [URL]) {
        DispatchQueue.main.async {
            self.handleButtonStates()
            self.startButton.isSelected = false
        }
    }
    
    func didExportVideo(with outputUrl: URL?,error: Error?) {
        DispatchQueue.main.async {
            self.stopButton.isEnabled = false
            self.startButton.isSelected = false
            self.timeLabel.isHidden = true
            self.handleButtonStates()
            self.stopActivityIndicator()
            if let outputUrl = outputUrl {
                self.showPlayerScreen(with: outputUrl)
            } else {
                var errorDescription = ""
                if let error = error {
                    errorDescription = error.localizedDescription
                }
                self.showAlert(title: "Error", message: "Could not Export Video. \(errorDescription)", completion: nil)
            }
        }
    }
    
    func didUpdateRecordingDuration(timeString: String) {
        DispatchQueue.main.async {
            self.view.bringSubview(toFront: self.timeLabel)
            self.timeLabel.isHidden = false
            self.timeLabel.text = timeString
        }
    }
    
    func didStopRecording(withIndividualVideoUrls videoUrls: [URL]?) {
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            self.timeLabel.isHidden = true
            self.stopButton.isEnabled = false
            self.startButton.isSelected = false
            self.handleButtonStates()
            self.stopActivityIndicator()
            
            guard var intermediateVideoUrls = videoUrls else {
//                self.cameraManager.resumeSession(completion: {
//                    DispatchQueue.main.async {
//                        self.updateUIForCameraMode(mode: self.cameraManager.cameraOutputMode)
//                    }
//                })
                return
            }
            
            let assetHandler = AssetHandler(withAssetUrls: intermediateVideoUrls, size: self.cameraManager.videoResolutionSize)
            var images = assetHandler.getImagesForAssets()
            let frame = CGRect(x: 0, y: self.view.bounds.height-240, width: self.view.bounds.width, height: 240)
            self.galleryView = GalleryView(frame: frame, images: images)
            
            self.galleryView?.didDeleteAssetBlock = { (index) in
                if index < intermediateVideoUrls.count {
                    intermediateVideoUrls.remove(at: index)
                    images.remove(at: index)
//                    self.cameraManager.deleteVideoAtIndex(index: index)
                }
            }
            
            self.galleryView?.didRearrangeAssetsBlock = { (fromIndex, toIndex)  in
                let temp = intermediateVideoUrls[fromIndex]
                
                if fromIndex < toIndex {
                    for item in fromIndex ..< toIndex {
                        intermediateVideoUrls[item] = intermediateVideoUrls[item+1]
                    }
                    intermediateVideoUrls[toIndex] = temp
                }
                else{
                    for item in (toIndex + 1...fromIndex).reversed() {
                        intermediateVideoUrls[item] = intermediateVideoUrls[item-1]
                    }
                }
                intermediateVideoUrls[toIndex] = temp
            }
            
            self.galleryView?.closeBlock = { [weak self] in
                guard let `self` = self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else { return }
                    self.galleryView?.removeFromSuperview()
                }
                self.cameraManager.resumeSession(completion: {
                    DispatchQueue.main.async {
                        self.updateUIForCameraMode(mode: self.cameraManager.cameraOutputMode)
                    }
                })
            }
            
            self.galleryView?.progressBlock = { [weak self] in
                guard let `self` = self else { return }
                self.galleryView?.removeFromSuperview()
                self.startActivityIndicator()
                self.cameraManager.exportCompositeVideo(fromIndividualVideoUrls: intermediateVideoUrls, quality: self.cameraManager.videoExportQuality)
            }
            
            self.view.addSubview(self.galleryView!)
        }
    }
    
    private func discardCapturedImages() {
        self.galleryView?.removeFromSuperview()
    }
    
    func didCaptureImage(image: UIImage?, previewImage: UIImage?, error: Error?) {
        DispatchQueue.main.async {
            guard let image = image else {
                self.showAlert(title: "Error", message: "Could not Capture Image", completion: nil)
                return
            }
            self.capturedImage = image
            if let previewImage = previewImage {
                self.previewImageView.isHidden = false
                self.previewImageView.image = previewImage
            } else {
                self.previewImageView.isHidden = false
                self.previewImageView.image = image
            }
        }
    }
}
