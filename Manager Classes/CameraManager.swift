//
//  CameraManager.swift
//  VideoJournal
//
//  Created by Sumedh Ravi on 25/07/18.
//  Copyright © 2018 Sumedh Ravi. All rights reserved.
//

import Foundation
import Photos
import AVFoundation
import CoreMotion

protocol CameraMangerRecordingDelegate: class {
    func didStartRecording()
    func didUpdateRecordingDuration(timeString: String)
    func didPauseRecording(withIndividualVideoUrls videoUrls: [URL])
    func didStopRecording(withIndividualVideoUrls videoUrls: [URL]?)
    func didExportVideo(with outputUrl: URL?, error: Error?)
}

protocol CameraPhotoCaptureDelegate: class {
    func didCaptureImage(image: UIImage?,previewImage: UIImage?, error: Error?)
}

protocol SettingsOptionsDataSource {
    static var optionArray: [String] { get }
}

public enum CameraState {
    case ready
    case accessDenied
    case noDeviceFound
    case notDetermined
}

public enum CameraFlashMode: Int {
    case off = 0
    case on
    case auto
}

public enum CameraOutputMode: Int, SettingsOptionsDataSource {
    
    case stillImage = 0
    case video
    
    var optionText: String {
        switch self {
        case .stillImage:
            return "Photo"
        case .video:
            return "Video"
        }
    }
    
    static var optionArray: [String] {
        return [self.stillImage.optionText,self.video.optionText]
    }
    
    func getOutput() -> AVCaptureOutput? {
        switch self {
            
        case .stillImage:
            let newStillImageOutput = AVCapturePhotoOutput()
            return newStillImageOutput
            
        case .video:
            let newMovieOutput = AVCaptureMovieFileOutput()
            newMovieOutput.movieFragmentInterval = kCMTimeInvalid
            
            return newMovieOutput
            
        default : return nil
        }
    }
}

public enum VideoExportQuality: Int, SettingsOptionsDataSource {
    case low = 0
    case medium
    case high
    
    var optionText: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    static var optionArray: [String] {
        return [self.low.optionText,self.medium.optionText,self.high.optionText]
    }
}

public enum CameraOutputQuality: Int {
    case low = 0
    case medium
    case high
    
    var optionText: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    static var optionArray: [String] {
        return [self.low.optionText,self.medium.optionText,self.high.optionText]
    }
}


public enum CameraPosition {
    case front
    case back
    
    var cameraDevice: AVCaptureDevice? {
        switch self {
        case .front :
            return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices.first
            
        case .back :
            return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices.first
        }
    }
}

internal typealias VideoRecordingAndImageCapture = CameraManager
internal typealias ZoomExposureAndFocusHandling = CameraManager
internal typealias OrientationHandling = CameraManager
internal typealias CameraSetup = CameraManager

final class CameraManager: NSObject {
    
    static let sharedInstance = CameraManager()
    
    var videoResolutionSize = CGSize(width: 0, height: 0)
    
    weak var recordingDelegate: CameraMangerRecordingDelegate?
    weak var imageCaptureDelegate: CameraPhotoCaptureDelegate?
    
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var backgroundTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    private let fileManager = CameraFileManager()
    private let photoLibrary = PhotoLibraryManager()
    private var exporter: VideoExporter?
    private var coreMotionManager: CMMotionManager!
    
    // MARK: Session Related properties
    
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDevice: AVCaptureDevice?
    private var captureDeviceInput: AVCaptureDeviceInput?
    private var cameraMovieOutput: AVCaptureMovieFileOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var imageOutput: AVCapturePhotoOutput?
    private lazy var micDevice: AVCaptureDevice? = {
        AVCaptureDevice.default(for: AVMediaType.audio)
    }()
    private var cameraIsSetup: Bool = false
    private var embeddingView: UIView?
    private var cameraTransitionView: UIView?
    private var transitionAnimating = false
    
    private lazy var focusGesture = UITapGestureRecognizer()
    private lazy var zoomGesture = UIPinchGestureRecognizer()
    private lazy var exposureGesture = UIPanGestureRecognizer()

    private var cameraIsObservingDeviceOrientation: Bool = false
    private var deviceOrientation: UIDeviceOrientation = .portrait
    
    // MARK: Properties related to zoom,exposure and focus functions
    let exposureDurationPower:Float = 4.0 //the exposure slider gain
    let exposureMininumDuration:Float64 = 1.0/2000.0
    var exposureValue: Float = 0.1 // EV
    
    var translationY: Float = 0
    var startPanPointInPreviewLayer: CGPoint?
    
    private var zoomScale = CGFloat(1.0)
    private var beginZoomScale = CGFloat(1.0)
    private var maxZoomScale = CGFloat(1.0)
    
    private var lastFocusRectangle: CAShapeLayer? = nil
    private var lastFocusPoint: CGPoint? = nil

    // MARK: Private Video Recording related properties
    private var pausedVideoUrls = [URL]()
    private var lockedRecordingOrientation: AVCaptureVideoOrientation = .portrait
    
    private var isRecording: Bool = false
    private var isPaused: Bool = true
    private var isStopped: Bool = false
    private var shouldDiscardVideo: Bool = false
    
    private var recordDuration = 0
    private var recordTimer: Timer?
    
    private var torchState = CameraFlashMode.off {
        didSet {
            if cameraIsSetup && torchState != oldValue {
                updateTorch(torchMode: torchState)
            }
        }
    }
    private var flashState = CameraFlashMode.off {
        didSet {
            if cameraIsSetup && torchState != oldValue {
                updateFlash(flashMode: flashState)
            }
        }
    }
    
    // MARK: Externally accesible properties
    
    // Property which denotes if camera is ready to be created.
    open var isCameraReady: Bool {
        return canLoadCamera()
    }
    
    //Indicates whether device has front camera
    open var hasFrontCamera: Bool = {
        let frontDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices
        return !frontDevices.isEmpty
    }()
    
    // Flash or Torch State of the device in the active session.
    open var illuminationState: CameraFlashMode {
        switch cameraOutputMode {
        case .video:
            return torchState
        case .stillImage:
            return flashState
        }
    }
    
    // Property which indicates whether camera device can be switched.(Cannot be switched when actively recording.)
    open var canChangeCameraPosition: Bool {
        return hasFrontCamera ? (isRecording ? isPaused : true) : false
    }
    
    // Property which indicates whether the recording device has provision for Torch or Flash
    open var hasTorchOrFlash: Bool? {
        return cameraOutputMode == .stillImage ? currentDevice?.hasFlash ?? false : (currentDevice?.hasTorch ?? false)
    }
    
    // Property to indicate whether a recording session is active.
    var isRecordingSessionInProgress: Bool {
        return cameraOutputMode == .video ? pausedVideoUrls.count > 0: false
    }
    
    
    // MARK: Externally modifiable properties.
    
    open static var videoAlbumName: String = "Videos"
    open static var imageAlbumName: String = "Images"
    
    open var videoExportQuality: VideoExportQuality = .medium
    open var shouldKeepViewAtOrientationChanges = false
    open var writeFilesToPhoneLibrary = true
    open var shouldFlipFrontCameraImage = true
    open var animateCameraDeviceChange = true
    open var performShutterAnimation = true
    open var shouldExportVideo = false
    
    // Property to set whether the Camera Manager should keep track of orientation changes.
    open var shouldRespondToOrientationChanges = true {
        didSet {
            if shouldRespondToOrientationChanges {
                startFollowingDeviceOrientation()
            } else {
                stopFollowingDeviceOrientation()
            }
        }
    }
    
    // Property to change camera position.
    open var cameraPosition: CameraPosition = .back {
        didSet {
            if cameraIsSetup && cameraPosition != oldValue {
                if animateCameraDeviceChange {
                    doFlipAnimation()
                }
                configureVideoInput(forCameraPosition: cameraPosition)
                handleOrientation()
                updateIlluminationState()
                setupMaxZoomScale()
                zoom(0)
            }
        }
    }
    
    // Property to change camera output.
    open var cameraOutputMode: CameraOutputMode = .stillImage {
        didSet {
            if cameraIsSetup {
                if cameraOutputMode != oldValue {
                    sessionQueue.async {
                        self.setupOutputMode(self.cameraOutputMode, oldCameraOutputMode: oldValue)
                        self.updateIlluminationState()
                    }
                }
                
            }
        }
    }
    // Property to change camera output quality.
    open var cameraOutputQuality: CameraOutputQuality = .high {
        didSet {
            if cameraIsSetup && cameraOutputQuality != oldValue {
                updateCameraQualityMode(newCameraOutputQuality: cameraOutputQuality)
            }
        }
    }
    
    // Property to determine if manager should enable tap to focus on camera preview. Default value is TRUE
    open var shouldEnableTapToFocus = true {
        didSet {
            focusGesture.isEnabled = shouldEnableTapToFocus
        }
    }
    
    // Property to determine if manager should enable pinch to zoom on camera preview.Default value is TRUE
    open var shouldEnablePinchToZoom = true {
        didSet {
            zoomGesture.isEnabled = shouldEnablePinchToZoom
        }
    }
    
    // Property to determine if manager should enable pan to change exposure/brightness. Default value is TRUE
    open var shouldEnableExposure = true {
        didSet {
            exposureGesture.isEnabled = shouldEnableExposure
        }
    }
    
    // Property to set focus mode when tap to focus is used (focusStart).
    open var focusMode : AVCaptureDevice.FocusMode = AVCaptureDevice.FocusMode.autoFocus
    // Property to set exposure mode when tap to focus is used (focusStart).
    open var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    // Property to set video stabilisation mode for a video record session.
    open var videoStabilisationMode : AVCaptureVideoStabilizationMode = .auto
    
    override private init() {
        super.init()
    
    }
    
    //MARK: Notification Handling
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionEncounteredRuntimeError), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
    }
    
    @objc private func sessionEncounteredRuntimeError(_ notification: Notification) {
        
    }
    
    @objc private func sessionWasInterrupted(_ notification: Notification) {
        if let userInfo = notification.userInfo, let reason = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int {
            if reason == AVCaptureSession.InterruptionReason.audioDeviceInUseByAnotherClient.rawValue || reason ==  AVCaptureSession.InterruptionReason.videoDeviceInUseByAnotherClient.rawValue || reason ==  AVCaptureSession.InterruptionReason.videoDeviceNotAvailableWithMultipleForegroundApps.rawValue {
                    self.stopSession()
            }
        }
    }
    
    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        if let isRunning = session?.isRunning, !isRunning {
            resumeSession(completion: nil)
        }
    }
    
    @objc public func willEnterBackground() {
        if cameraIsSetup {
            let application = UIApplication.shared
            application.beginBackgroundTask(expirationHandler: {
                switch self.cameraOutputMode {
                case .video:
                    if self.isRecording && !self.isPaused {
                        self.pauseRecording()
                    }
                    self.stopSession()
                default:
                    self.stopSession()
                }
            })
        }
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    
    @discardableResult open func addVideoPreviewToView(_ view: UIView, cameraMode: CameraOutputMode?,completion: (() -> Void)?) -> CameraState {
        let mode = cameraMode != nil ? cameraMode!: self.cameraOutputMode
        
        if let _ = embeddingView {
            if let validPreviewLayer = previewLayer {
                validPreviewLayer.removeFromSuperlayer()
            }
        }
        if cameraIsSetup {
            addPreviewLayerToView(view)
            cameraOutputMode = mode
            completion?()
        } else {
            setupSession {
                self.addPreviewLayerToView(view)
                self.cameraOutputMode = mode
                completion?()
            }
        }
        return PermissionsManager.checkIfCameraIsAvailable()
    }
    
    open func changeIlluminationMode() -> CameraFlashMode {
        switch cameraOutputMode {
        case .video:
            guard let newIlluminationMode = CameraFlashMode(rawValue: (torchState.rawValue+1)%3) else { return torchState }
            torchState = newIlluminationMode
            return torchState
        case .stillImage:
            guard let newIlluminationMode = CameraFlashMode(rawValue: (flashState.rawValue+1)%3) else { return flashState }
            flashState = newIlluminationMode
            return flashState
        }
    }
    
    open func changeCameraPosition() {
        guard canChangeCameraPosition == true && hasFrontCamera else { return }
        cameraPosition = cameraPosition == .back ? .front : .back
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension CameraSetup {
    
    private func setupSession(completion: @escaping () -> Void) {
        session = AVCaptureSession()
        
        sessionQueue.async(execute: {
            if let captureSession = self.session {
                self.retrieveSettingsFromUserDefaults()
                self.backgroundTaskID = UIBackgroundTaskInvalid
                self.setupObservers()
                captureSession.beginConfiguration()
                self.configureVideoInput()
                self.configureOutputs()
                self.setupOutputMode(self.cameraOutputMode, oldCameraOutputMode: nil)
                self.setupPreviewLayer()
                self.updateIlluminationState(state: self.illuminationState)
                self.updateCameraQualityMode(newCameraOutputQuality: self.cameraOutputQuality)
                captureSession.commitConfiguration()
                
                self.setupMaxZoomScale()
                self.startSession()
                self.startFollowingDeviceOrientation()
                self.cameraIsSetup = true
                self.handleOrientation()
                completion()
            }
        })
    }
    
    private func addPreviewLayerToView(_ view: UIView) {
        embeddingView = view
        attachZoom(view)
        attachFocus(view)
        attachExposure(view)
        
        DispatchQueue.main.async(execute: { () -> Void in
            guard let previewLayer = self.previewLayer else { return }
            previewLayer.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.addSublayer(previewLayer)
        })
    }
    
    private func setupPreviewLayer() {
        if let captureSession = session {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            previewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
        }
    }
    
    //Configure Video Device Input
    private func configureVideoInput(forCameraPosition position: CameraPosition? = nil) {
        let position = position ?? cameraPosition
        guard let session = session else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        currentDevice = position.cameraDevice
        for input in session.inputs as! [AVCaptureDeviceInput] {
            if input.device.hasMediaType(AVMediaType.video) {
                session.removeInput(input)
            }
        }
        guard let input = inputForDevice(currentDevice) else { return }
        if session.canAddInput(input), !session.inputs.contains(input) {
            session.addInput(input)
            captureDeviceInput = input
            print("Session Output: \(session.outputs.first?.connections)")
        }

        previewLayer?.connection?.isVideoMirrored = cameraPosition == .front ? shouldFlipFrontCameraImage : false
    }
    
    //Configure Audio Device Input
    private func configureAudioInput() {
        guard let session = session else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard let micDeviceInput = inputForDevice(micDevice) else { return }
        if session.canAddInput(micDeviceInput) {
            session.addInput(micDeviceInput)
        }
    }
    //Remove Mic Input from capture session
    private func removeMicInput() {
        guard let session = session else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        for input in session.inputs as! [AVCaptureDeviceInput] {
            if input.device.hasMediaType(AVMediaType.audio) && input.device == micDevice {
                session.removeInput(input)
            }
        }
    }
    
    //Configure Capture Device Input
    private func inputForDevice(_ device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let error {
            print(error)
            return nil
        }
    }
    
    //Configure Output Devices for session
    private func configureOutputs() {
        guard let session = session else { return }
        if imageOutput == nil {
            if let output = CameraOutputMode.stillImage.getOutput() as? AVCapturePhotoOutput {
                imageOutput = output
            }
        }
        if cameraMovieOutput == nil {
            if let output = CameraOutputMode.video.getOutput() as? AVCaptureMovieFileOutput {
                cameraMovieOutput = output
            }
        }
    }
    
    private func updateIlluminationState(state: CameraFlashMode? = nil) {
        if let state = state {
            switch cameraOutputMode {
            case .video:
                updateTorch(torchMode: state)
            case .stillImage:
                updateFlash(flashMode: state)
            }
        } else {
            switch cameraOutputMode {
            case .video:
                updateTorch(torchMode: torchState)
            case .stillImage:
                updateFlash(flashMode: flashState)
            }
        }
    }
    
    private func updateCameraQualityMode(newCameraOutputQuality: CameraOutputQuality) {
        if let captureSession = session {
            var sessionPreset = AVCaptureSession.Preset.low
            switch newCameraOutputQuality {
            case CameraOutputQuality.low:
                sessionPreset = AVCaptureSession.Preset.low
            case CameraOutputQuality.medium:
                sessionPreset = AVCaptureSession.Preset.medium
            case CameraOutputQuality.high:
                sessionPreset = AVCaptureSession.Preset.high
            }
            if captureSession.canSetSessionPreset(sessionPreset) {
                captureSession.beginConfiguration()
                captureSession.sessionPreset = sessionPreset
                captureSession.commitConfiguration()
            } else {
                print("Cannot Set This Preset.")
            }
        } else {
            print("Camera Not Setup.")
        }
    }
    
    //Sets Camera Output Mode
    private func setupOutputMode(_ newCameraOutputMode: CameraOutputMode, oldCameraOutputMode: CameraOutputMode?) {
        
        session?.beginConfiguration()
        if let cameraOutputToRemove = oldCameraOutputMode {
            
            // remove current setting
            switch cameraOutputToRemove {
            case .video:
                if let validMovieOutput = cameraMovieOutput {
                    session?.removeOutput(validMovieOutput)
                    cameraMovieOutput = nil
                    removeMicInput()
//                    resetRecordingSession()
                }
            case .stillImage:
                if let validStillImageOutput = imageOutput {
                    session?.removeOutput(validStillImageOutput)
                }
                imageOutput = nil
            }
        }
        
        switch newCameraOutputMode {
        case .stillImage:
            let stillImageOutput = getImageOutput()
            if let captureSession = session, captureSession.canAddOutput(stillImageOutput!) {
                captureSession.addOutput(stillImageOutput!)
            }
        case .video:
            let videoMovieOutput = getMovieOutput()
            if let captureSession = session,
                captureSession.canAddOutput(videoMovieOutput!) {
                captureSession.addOutput(videoMovieOutput!)
            }
            configureAudioInput()
        }
        session?.commitConfiguration()
        handleOrientation()
    }
    
    
    private func getCurrentOutput() -> AVCaptureOutput? {
        switch cameraOutputMode {
            
        case .stillImage :
            if let stillImageOutput = imageOutput, let connection = stillImageOutput.connection(with: AVMediaType.video),
                connection.isActive {
                return stillImageOutput
            }
            
        case .video:
            if let output = cameraMovieOutput, let connection = output.connection(with: AVMediaType.video), connection.isActive {
                return cameraMovieOutput
            }
            
            session?.beginConfiguration()
            defer { session?.commitConfiguration() }
            
            guard let videoOutput = cameraMovieOutput else { return nil }
            for connection in videoOutput.connections {
                for port in connection.inputPorts {
                    if port.mediaType == AVMediaType.video {
                        let videoConnection = connection as AVCaptureConnection
                        
                        if videoConnection.isVideoStabilizationSupported {
                            videoConnection.preferredVideoStabilizationMode = self.videoStabilisationMode
                        }
                    }
                }
            }
            return videoOutput
        }
        return nil
    }
    
    private func getMovieOutput() -> AVCaptureMovieFileOutput? {
        if let output = cameraOutputMode.getOutput() as? AVCaptureMovieFileOutput {
            if let captureSession = session, captureSession.canAddOutput(output) {
                captureSession.beginConfiguration()
                captureSession.addOutput(output)
                captureSession.commitConfiguration()
            }
            cameraMovieOutput = output
            return cameraMovieOutput!
        }
        return nil
    }
    
    private func getImageOutput() -> AVCapturePhotoOutput? {
        if let output = cameraOutputMode.getOutput() as? AVCapturePhotoOutput {
            //            imageOutput?.isHighResolutionCaptureEnabled = isHighResolutionPhotoEnabled
            
            if let captureSession = session,
                captureSession.canAddOutput(output) {
                captureSession.beginConfiguration()
                captureSession.addOutput(output)
                captureSession.commitConfiguration()
                imageOutput = output
            }
            return output
        }
        return nil
    }
    
    //Setting Torch Mode
    private func updateTorch(torchMode: CameraFlashMode) {
        guard let currentDevice = currentDevice else { return }
        
        session?.beginConfiguration()
        defer { session?.commitConfiguration() }
        guard let torchMode = AVCaptureDevice.TorchMode(rawValue: torchMode.rawValue) else { return }
        if currentDevice.hasTorch {
            if currentDevice.isTorchModeSupported(torchMode) {
                do {
                    try currentDevice.lockForConfiguration()
                    currentDevice.torchMode = torchMode
                    currentDevice.unlockForConfiguration()
                    
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    private func updateFlash(flashMode: CameraFlashMode) {
        //        guard let currentDevice = currentDevice else { return false }
        //
        //        session?.beginConfiguration()
        //        defer { session?.commitConfiguration() }
        //        guard let flashMode = AVCaptureDevice.FlashMode(rawValue: flashMode.rawValue) else { return }
        //        if currentDevice.hasFlash, currentDevice.isFlashAvailable {
        //            if currentDevice.isFlashModeSupported(flashMode) {
        //                do {
        //                    try currentDevice.lockForConfiguration()
        //                    currentDevice.flashMode = flashMode
        //                    currentDevice.unlockForConfiguration()
        //
        //                } catch { }
        //            }
        //        }
        //        return
    }
    
    
//    func addOutput<outputType: AVCaptureOutput>(output: AVCaptureOutput, delegate: outputType) {
//        session?.beginConfiguration()
//        defer { session?.commitConfiguration() }
//        guard  let session = session else {
//            return
//        }
//        if session.canAddOutput(output) {
//            session.addOutput(output)
//        }
//    }
}

extension ZoomExposureAndFocusHandling {
    
    //MARK: Handling of zoom, exposure and focus in the capture preview.
    
    private func attachZoom(_ view: UIView) {
        DispatchQueue.main.async {
            self.zoomGesture.addTarget(self, action: #selector(CameraManager.zoomStart(_:)))
            view.addGestureRecognizer(self.zoomGesture)
            self.zoomGesture.delegate = self
        }
    }
    
    @objc private func zoomStart(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = embeddingView,
            let previewLayer = previewLayer
            else { return }
        
        var allTouchesOnPreviewLayer = true
        let numTouch = recognizer.numberOfTouches
        
        for i in 0 ..< numTouch {
            let location = recognizer.location(ofTouch: i, in: view)
            let convertedTouch = previewLayer.convert(location, from: previewLayer.superlayer)
            if !previewLayer.contains(convertedTouch) {
                allTouchesOnPreviewLayer = false
                break
            }
        }
        if allTouchesOnPreviewLayer {
            zoom(recognizer.scale)
        }
    }
    
    private func setupMaxZoomScale() {
        beginZoomScale = CGFloat(1.0)
        
        if let maxZoom = currentDevice?.activeFormat.videoMaxZoomFactor {
            maxZoomScale = maxZoom / 4
        }
    }
    
    private func zoom(_ scale: CGFloat) {
        let device = currentDevice
        
        do {
            let captureDevice = device
            try captureDevice?.lockForConfiguration()
            
            zoomScale = max(1.0, min(beginZoomScale * scale, maxZoomScale))
            
            captureDevice?.videoZoomFactor = zoomScale
            captureDevice?.unlockForConfiguration()
        } catch {
            print("Error locking configuration")
        }
    }
    
    private func attachFocus(_ view: UIView) {
        DispatchQueue.main.async {
            self.focusGesture.addTarget(self, action: #selector(CameraManager.focusStart(_:)))
            view.addGestureRecognizer(self.focusGesture)
            self.focusGesture.delegate = self
        }
    }
    
    @objc private func focusStart(_ recognizer: UITapGestureRecognizer) {
        let device = currentDevice
        changeExposureMode(mode: .continuousAutoExposure)
        translationY = 0
        exposureValue = 0.5
        
        if let validDevice = device,
            let validPreviewLayer = previewLayer,
            let view = recognizer.view
        {
            let pointInPreviewLayer = view.layer.convert(recognizer.location(in: view), to: validPreviewLayer)
            let pointOfInterest = validPreviewLayer.captureDevicePointConverted(fromLayerPoint: pointInPreviewLayer)
            
            do {
                try validDevice.lockForConfiguration()
                
                showFocusRectangleAtPoint(pointInPreviewLayer, inLayer: validPreviewLayer)
                
                if validDevice.isFocusPointOfInterestSupported {
                    validDevice.focusPointOfInterest = pointOfInterest
                }
                
                if  validDevice.isExposurePointOfInterestSupported {
                    validDevice.exposurePointOfInterest = pointOfInterest
                }
                
                if validDevice.isFocusModeSupported(focusMode) {
                    validDevice.focusMode = focusMode
                }
                
                if validDevice.isExposureModeSupported(exposureMode) {
                    validDevice.exposureMode = exposureMode
                }
                
                validDevice.unlockForConfiguration()
            }
            catch let error {
                print(error)
            }
        }
    }
    
    private func attachExposure(_ view: UIView) {
        DispatchQueue.main.async {
            self.exposureGesture.addTarget(self, action: #selector(CameraManager.exposureStart(_:)))
            view.addGestureRecognizer(self.exposureGesture)
            self.exposureGesture.delegate = self
        }
    }
    
    @objc private func exposureStart(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        let view = gestureRecognizer.view!
        
        changeExposureMode(mode: .custom)
        
        let translation = gestureRecognizer.translation(in: view)
        let currentTranslation = translationY + Float(translation.y)
        if (gestureRecognizer.state == .ended) {
            translationY = currentTranslation
        }
        if (currentTranslation < 0) {
            // up - brighter
            exposureValue = 0.5 + min(abs(currentTranslation) / 400, 1) / 2
        } else if (currentTranslation >= 0) {
            // down - lower
            exposureValue = 0.5 - min(abs(currentTranslation) / 400, 1) / 2
        }
        changeExposureDuration(value: exposureValue)
        
        // UI Visualization
        if (gestureRecognizer.state == .began) {
            if let validPreviewLayer = previewLayer {
                startPanPointInPreviewLayer = view.layer.convert(gestureRecognizer.location(in: view), to: validPreviewLayer)
            }
        }
        
        if let validPreviewLayer = previewLayer, let lastFocusPoint = self.lastFocusPoint {
            showFocusRectangleAtPoint(lastFocusPoint, inLayer: validPreviewLayer, withBrightness: exposureValue)
        }
    }
    
    private func changeExposureDuration(value: Float) {
        if (cameraIsSetup) {
            let device = currentDevice
            
            do {
                try device?.lockForConfiguration()
            } catch {
                return
            }
            guard let videoDevice = device else {
                return
            }
            
            let p = Float64(pow(value, exposureDurationPower)) // Apply power function to expand slider's low-end range
            let minDurationSeconds = Float64(max(CMTimeGetSeconds(videoDevice.activeFormat.minExposureDuration), exposureMininumDuration))
            let maxDurationSeconds = Float64(CMTimeGetSeconds(videoDevice.activeFormat.maxExposureDuration))
            let newDurationSeconds = Float64(p * (maxDurationSeconds - minDurationSeconds)) + minDurationSeconds // Scale from 0-1 slider range to actual duration
            
            if (videoDevice.exposureMode == .custom) {
                let newExposureTime = CMTimeMakeWithSeconds(Float64(newDurationSeconds), 1000*1000*1000)
                videoDevice.setExposureModeCustom(duration: newExposureTime, iso: AVCaptureDevice.currentISO, completionHandler: nil)
            }
        }
    }
    
    private func changeExposureMode(mode: AVCaptureDevice.ExposureMode) {
        let device = currentDevice
        if (device?.exposureMode == mode) {
            return
        }
        do {
            try device?.lockForConfiguration()
        } catch {
            return
        }
        if device?.isExposureModeSupported(mode) == true {
            device?.exposureMode = mode
        }
        device?.unlockForConfiguration()
    }
    
    private func showFocusRectangleAtPoint(_ focusPoint: CGPoint, inLayer layer: CALayer, withBrightness brightness: Float? = nil) {
        
        if let lastFocusRectangle = lastFocusRectangle {
            
            lastFocusRectangle.removeFromSuperlayer()
            self.lastFocusRectangle = nil
        }
        
        let size = CGSize(width: 75, height: 75)
        let rect = CGRect(origin: CGPoint(x: focusPoint.x - size.width / 2.0, y: focusPoint.y - size.height / 2.0), size: size)
        
        let endPath = UIBezierPath(rect: rect)
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY + 5.0))
        endPath.move(to: CGPoint(x: rect.maxX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.maxX - 5.0, y: rect.minY + size.height / 2.0))
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY - 5.0))
        endPath.move(to: CGPoint(x: rect.minX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.minX + 5.0, y: rect.minY + size.height / 2.0))
        if (brightness != nil) {
            endPath.move(to: CGPoint(x: rect.minX + size.width + size.width / 4, y: rect.minY))
            endPath.addLine(to: CGPoint(x: rect.minX + size.width + size.width / 4, y: rect.minY + size.height))
            
            endPath.move(to: CGPoint(x: rect.minX + size.width + size.width / 4 - size.width / 16, y: rect.minY + size.height - CGFloat(brightness!) * size.height))
            endPath.addLine(to: CGPoint(x: rect.minX + size.width + size.width / 4 + size.width / 16, y: rect.minY + size.height - CGFloat(brightness!) * size.height))
        }
        
        let startPath = UIBezierPath(cgPath: endPath.cgPath)
        let scaleAroundCenterTransform = CGAffineTransform(translationX: -focusPoint.x, y: -focusPoint.y).concatenating(CGAffineTransform(scaleX: 2.0, y: 2.0).concatenating(CGAffineTransform(translationX: focusPoint.x, y: focusPoint.y)))
        startPath.apply(scaleAroundCenterTransform)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = endPath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor(red:1, green:0.83, blue:0, alpha:0.95).cgColor
        shapeLayer.lineWidth = 1.0
        
        layer.addSublayer(shapeLayer)
        lastFocusRectangle = shapeLayer
        lastFocusPoint = focusPoint
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut))
        
        CATransaction.setCompletionBlock {
            if shapeLayer.superlayer != nil {
                shapeLayer.removeFromSuperlayer()
                self.lastFocusRectangle = nil
            }
        }
        if (brightness == nil) {
            let appearPathAnimation = CABasicAnimation(keyPath: "path")
            appearPathAnimation.fromValue = startPath.cgPath
            appearPathAnimation.toValue = endPath.cgPath
            shapeLayer.add(appearPathAnimation, forKey: "path")
            
            let appearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
            appearOpacityAnimation.fromValue = 0.0
            appearOpacityAnimation.toValue = 1.0
            shapeLayer.add(appearOpacityAnimation, forKey: "opacity")
        }
        
        let disappearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        disappearOpacityAnimation.fromValue = 1.0
        disappearOpacityAnimation.toValue = 0.0
        disappearOpacityAnimation.beginTime = CACurrentMediaTime() + 0.8
        disappearOpacityAnimation.fillMode = kCAFillModeForwards
        disappearOpacityAnimation.isRemovedOnCompletion = false
        shapeLayer.add(disappearOpacityAnimation, forKey: "opacity")
        
        CATransaction.commit()
    }
}

extension OrientationHandling {
    //MARK: Handling Device Orientation
    
    @objc private func handleOrientation() {
        let currentConnection = getCurrentOutput()?.connection(with: AVMediaType.video)
        
        if let validPreviewLayer = previewLayer {
            if !shouldKeepViewAtOrientationChanges {
                if let validPreviewLayerConnection = validPreviewLayer.connection {
                    if validPreviewLayerConnection.isVideoOrientationSupported {
                        validPreviewLayerConnection.videoOrientation = currentPreviewVideoOrientation()
                    }
                }
            }
            
            if let validOutputLayerConnection = currentConnection, validOutputLayerConnection.isVideoOrientationSupported {
                
                switch cameraOutputMode {
                case .stillImage:
                    validOutputLayerConnection.videoOrientation = currentCaptureVideoOrientation()
                    
                case .video:
                    if isRecording || isRecordingSessionInProgress {
                        validOutputLayerConnection.videoOrientation = lockedRecordingOrientation
                    } else {
                        lockedRecordingOrientation = currentCaptureVideoOrientation()
                        validOutputLayerConnection.videoOrientation = lockedRecordingOrientation
                    }
                }
            }
            
            if !shouldKeepViewAtOrientationChanges && cameraIsObservingDeviceOrientation {
                DispatchQueue.main.async(execute: { () -> Void in
                    if let validEmbeddingView = self.embeddingView {
                        validPreviewLayer.frame = validEmbeddingView.bounds
                        validPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                    }
                })
            }
        }
    }
    
    private func startFollowingDeviceOrientation() {
        if shouldRespondToOrientationChanges && !cameraIsObservingDeviceOrientation {
            coreMotionManager = CMMotionManager()
            coreMotionManager.accelerometerUpdateInterval = 0.005
            
            if coreMotionManager.isAccelerometerAvailable {
                coreMotionManager.startAccelerometerUpdates(to: OperationQueue(), withHandler:
                    { (data, error) in
                        
                        guard let acceleration: CMAcceleration = data?.acceleration  else{
                            return
                        }
                        let scaling: CGFloat = CGFloat(1) / CGFloat(( abs(acceleration.x) + abs(acceleration.y)))
                        
                        let x: CGFloat = CGFloat(acceleration.x) * scaling
                        let y: CGFloat = CGFloat(acceleration.y) * scaling
                        
                        if acceleration.z < Double(-0.75) {
                            self.deviceOrientation = .faceUp
                        } else if acceleration.z > Double(0.75) {
                            self.deviceOrientation = .faceDown
                        } else if x < CGFloat(-0.5) {
                            self.deviceOrientation = .landscapeLeft
                        } else if x > CGFloat(0.5) {
                            self.deviceOrientation = .landscapeRight
                        } else if y > CGFloat(0.5) {
                            self.deviceOrientation = .portraitUpsideDown
                        }
                        
                        //                        self.handleOrientation()
                        self.sessionQueue.async {
                            self.handleOrientation()
                        }
                })
                cameraIsObservingDeviceOrientation = true
            } else {
                cameraIsObservingDeviceOrientation = false
            }
        }
    }
    
    private func stopFollowingDeviceOrientation() {
        if cameraIsObservingDeviceOrientation {
            coreMotionManager.stopAccelerometerUpdates()
            cameraIsObservingDeviceOrientation = false
        }
    }
    
    private func videoOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .faceUp:
            /*
             Attempt to keep the existing orientation.  If the device was landscape, then face up
             getting the orientation from the stats bar would fail every other time forcing it
             to default to portrait which would introduce flicker into the preview layer.  This
             would not happen if it was in portrait then face up
             */
            if let validPreviewLayer = previewLayer, let connection = validPreviewLayer.connection  {
                return connection.videoOrientation //Keep the existing orientation
            }
            //Could not get existing orientation, try to get it from stats bar
            return videoOrientationFromStatusBarOrientation()
        case .faceDown:
            /*
             Attempt to keep the existing orientation.  If the device was landscape, then face down
             getting the orientation from the stats bar would fail every other time forcing it
             to default to portrait which would introduce flicker into the preview layer.  This
             would not happen if it was in portrait then face down
             */
            if let validPreviewLayer = previewLayer, let connection = validPreviewLayer.connection  {
                return connection.videoOrientation //Keep the existing orientation
            }
            //Could not get existing orientation, try to get it from stats bar
            return videoOrientationFromStatusBarOrientation()
        default:
            return .portrait
        }
    }
    
    private func videoOrientationFromStatusBarOrientation() -> AVCaptureVideoOrientation {
        
        var orientation: UIInterfaceOrientation?
        
        DispatchQueue.main.async {
            orientation = UIApplication.shared.statusBarOrientation
        }
        
        /*
         Note - the following would fall into the guard every other call (it is called repeatedly) if the device was
         landscape then face up/down.  Did not seem to fail if in portrait first.
         */
        guard let statusBarOrientation = orientation else {
            return .portrait
        }
        switch statusBarOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
    
    private func currentCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        if deviceOrientation == .faceDown
            || deviceOrientation == .faceUp
            || deviceOrientation == .unknown {
            return currentPreviewVideoOrientation()
        }
        return videoOrientation(forDeviceOrientation: deviceOrientation)
    }
    
    private func currentPreviewDeviceOrientation() -> UIDeviceOrientation {
        if shouldKeepViewAtOrientationChanges {
            return .portrait
        }
        return UIDevice.current.orientation
    }
    
    private func currentPreviewVideoOrientation() -> AVCaptureVideoOrientation {
        return videoOrientation(forDeviceOrientation: currentPreviewDeviceOrientation())
    }
    
    private func imageOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation, isMirrored: Bool) -> UIImageOrientation {
        switch deviceOrientation {
        case .landscapeLeft:
            return cameraPosition == .back ? isMirrored ? .upMirrored : .up : isMirrored ? .downMirrored : .down
        case .landscapeRight:
            return cameraPosition == .back ? isMirrored ? .downMirrored : .down : isMirrored ? .upMirrored : .up
        default:
            break
        }
        return isMirrored ? .leftMirrored : .right
    }
}

extension VideoRecordingAndImageCapture {
    
    private func startSession() {
        sessionQueue.async {
            if let session = self.session, !session.isRunning {
                self.session?.startRunning()
            }
        }
    }
    
    private func stopSession() {
        sessionQueue.async {
            if let session = self.session, session.isRunning{
                self.session?.stopRunning()
            }
        }
        enableGestures(enable: false)
//        stopFollowingDeviceOrientation()
    }
    
    func resumeSession(completion: (() -> Void )?) {
        if let captureSession = session {
            if !captureSession.isRunning && cameraIsSetup {
                self.sessionQueue.async(execute: {
                    captureSession.startRunning()
                    self.startFollowingDeviceOrientation()
                    self.enableGestures(enable: true)
                    completion?()
                })
            }
        } else {
            if canLoadCamera() {
                if cameraIsSetup {
                    stopAndRemoveSession()
                }
                setupSession {
                    if let validEmbeddingView = self.embeddingView {
                        self.addPreviewLayerToView(validEmbeddingView)
                    }
                    self.startFollowingDeviceOrientation()
                    completion?()
                }
            }
        }
    }
    
    func stopAndRemoveSession() {
//        stopRecording()
        removeObservers()
        stopSession()
        stopFollowingDeviceOrientation()
        stopRecordTimer(reset: true)
//        isRecording = false
        resetRecordingSession()
        cameraIsSetup = false
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        session = nil
        cameraMovieOutput = nil
        audioOutput = nil
        imageOutput = nil
    }
    
    private func enableGestures(enable: Bool) {
        zoomGesture.isEnabled = enable
        focusGesture.isEnabled = enable
        exposureGesture.isEnabled = enable
    }
    
    //MARK: Video Record and Image Capture
    
    //Starts Video Recording
    open func startRecording() {
        if let session = session, isCameraReady && !session.isRunning {
            resumeSession(completion: nil)
            return
        }
        guard let videoOutput = getCurrentOutput() as? AVCaptureMovieFileOutput, let connection = videoOutput.connection(with: .video), cameraOutputMode == .video && connection.isActive else {
            print("Wrong Camera Mode set.")
            return
        }
        guard let url = fileManager.createFileinCacheDirectory(fileName: fileManager.intermediateVideosFolderName) else {
            print("Could Not Fetch URL To Start Recording")
            return
        }
        
        startBackgroundTask()
        videoOutput.startRecording(to: url.appendingPathComponent("Video\(pausedVideoUrls.count)").appendingPathExtension("mov"), recordingDelegate: self)
        shouldDiscardVideo = false
        isRecording = true
        isPaused = false
        startRecordTimer()
    }
    
    //To pause the video recording operation
    open func pauseRecording() {
        isPaused = true
        stopRecord()
    }
    
    //Stops video recording and calls delegate function with recorded video URL
    open func stopRecording(discardVideo: Bool = false) {
        shouldDiscardVideo = discardVideo
        stopRecord()
    }
    
    open func capturePhoto(withPreviewSize size: CGSize?) {
        
        if let session = session, isCameraReady && !session.isRunning {
            resumeSession(completion: nil)
            return
        }
        
        guard cameraOutputMode == .stillImage, let stillImageOutput = getCurrentOutput() as? AVCapturePhotoOutput else {
            print("Wrong camera mode set")
            return
        }
        updateFlash(flashMode: flashState)
        
        let settings = AVCapturePhotoSettings()
        if let size = size {
            let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
            let previewFormat: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
            settings.previewPhotoFormat = previewFormat
        }
        
        sessionQueue.async(execute: {
            if let flashMode = AVCaptureDevice.FlashMode(rawValue: self.flashState.rawValue) {
                if stillImageOutput.supportedFlashModes.contains(flashMode) {
                    settings.flashMode = flashMode
                }
            }
            
            if let connection = stillImageOutput.connection(with: AVMediaType.video),
                connection.isEnabled {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = self.currentCaptureVideoOrientation()
                }
                
                stillImageOutput.capturePhoto(with: settings, delegate: self)
                if self.performShutterAnimation {
                    self.performShutterAnimation(completion: nil)
                }
            }
        })
    }
    
    private func stopRecord() {
        stopRecordTimer(reset: false)
        if !isStopped {
            cameraMovieOutput?.stopRecording()
        } else {
            if shouldDiscardVideo {
                resetRecordingSession()
                recordingDelegate?.didStopRecording(withIndividualVideoUrls: nil)
            } else {
                guard session != nil && pausedVideoUrls.count > 0 else {
                    print("No videos recorded to export")
                    return
                }
                stopSession()
                if shouldExportVideo {
                    exportCompositeVideo(fromIndividualVideoUrls: pausedVideoUrls, quality: videoExportQuality)
                } else {
                    recordingDelegate?.didStopRecording(withIndividualVideoUrls: pausedVideoUrls)
                }
            }
            endBackgroundTask()
        }
        isRecording = false
    }
    
    func resetRecordingSession() {
        isRecording = false
        shouldDiscardVideo = false
        pausedVideoUrls = []
        stopRecordTimer(reset: true)
        videoResolutionSize = CGSize(width: 0, height: 0)
        clearIntermediateSavedVideoClips()
    }
    
    //Starts timer to show recorded time
    private func startRecordTimer() {
        recordTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateRecordDuration), userInfo: nil, repeats: true)
    }
    
    //Save intermediate clip URLs
    private func saveOutputFileUrl(url: URL) {
        pausedVideoUrls.append(url)
    }
    
    public func deleteVideoAtIndex(index: Int) {
        guard index < pausedVideoUrls.count else { return }
        let videoAssetTrack = AVAsset(url: pausedVideoUrls[index]).tracks(withMediaType: AVMediaType.video)[0]
        let trackDuration = videoAssetTrack.timeRange.duration.seconds
        recordDuration = max((recordDuration-Int(trackDuration)),0)
        pausedVideoUrls.remove(at: index)
    }
    
    public func moveVideo(atIndex: Int, to index: Int) {
        guard atIndex < pausedVideoUrls.count && index < pausedVideoUrls.count else { return }
        pausedVideoUrls.swapAt(atIndex, index)
    }
    
    @objc private func updateRecordDuration() {
        recordDuration += 1

        //String format 00:00
        let (timeMin,timeSec) = timeInMinutesandSeconds(seconds: recordDuration)
        let recordTime = String(format: "%02d:%02d" , arguments: [timeMin,timeSec])
        
        recordingDelegate?.didUpdateRecordingDuration(timeString: recordTime)
    }
    
    //Stops recording timer
    private func stopRecordTimer(reset: Bool) {
        recordTimer?.invalidate()
        recordTimer = nil
        if reset {
            recordDuration = 0
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        //Did Start
        isStopped = false
        updateTorch(torchMode: torchState)
        if let videoSize = getCaptureResolution() {
            if videoSize.width > videoResolutionSize.width && videoSize.height > videoResolutionSize.height {
                videoResolutionSize = videoSize
            }
        }
        recordingDelegate?.didStartRecording()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        isStopped = true
        
        guard let session = session, let recordingDelegate = recordingDelegate, cameraOutputMode == .video && session.outputs.contains(output) else {
            stopRecording(discardVideo: true)
            self.fileManager.deleteFile(atUrl: outputFileURL)
            return
        }
        guard error == nil else {
            print(error!.localizedDescription)
            saveOutputFileUrl(url: outputFileURL)
            let success = (error as? NSError)!.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as! Bool
            stopRecording(discardVideo: !success)
            if !success {
                self.fileManager.deleteFile(atUrl: outputFileURL)
            }
            return
        }
        saveOutputFileUrl(url: outputFileURL)
        
        //Check if pause or stop
        if isPaused {
            recordingDelegate.didPauseRecording(withIndividualVideoUrls: pausedVideoUrls)
        } else {
            stopRecording(discardVideo: shouldDiscardVideo)
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        captureImage(photoSampleBuffer: photoSampleBuffer, previewPhoto: previewPhotoSampleBuffer, resolvedSettings: resolvedSettings, bracketSettings: bracketSettings, error: error)
    }
}

extension CameraManager {
    
    public func exportCompositeVideo(fromIndividualVideoUrls videoUrls: [URL],quality: VideoExportQuality, completion: (()->())? = nil) {
        exporter = VideoExporter()
        exporter?.exportVideo(urls: videoUrls, exportQuality: quality, size: videoResolutionSize) { (outputUrl,error) in
            self.resetRecordingSession()
            
            if let videoUrl = outputUrl {
                if self.writeFilesToPhoneLibrary {
                    CameraManager.saveVideoToAlbum(outputPath: videoUrl, completion: { (success) in
                        self.recordingDelegate?.didExportVideo(with: outputUrl, error: nil)
                        completion?()
                    })
                } else {
                    self.recordingDelegate?.didExportVideo(with: outputUrl, error: error)
                    completion?()
                }
            } else {
                self.recordingDelegate?.didExportVideo(with: nil, error: error)
            }
        }
    }
    
    private func captureImage(photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if let sampleBuffer = photoSampleBuffer, let dataImage =  AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:  sampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer), let capturedImage = UIImage(data: dataImage) {
            var previewImage: UIImage?
            
            let originalImage = capturedImage.fixOrientation()
            let imageData = UIImageJPEGRepresentation(originalImage, 1.0)
            
            if let previewBuffer = previewPhotoSampleBuffer, let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(previewBuffer) {
                let ciimage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
                let image : UIImage = convert(ciimage: ciimage)
                previewImage = image.fixOrientation()
            }
            
            if writeFilesToPhoneLibrary {
                CameraManager.saveImageToAlbum(image: originalImage) { (success) in
                    self.imageCaptureDelegate?.didCaptureImage(image: originalImage, previewImage: previewImage, error: error)
                }
            } else {
                imageCaptureDelegate?.didCaptureImage(image: originalImage, previewImage: previewImage, error: error)
            }
        } else {
            print("Could Not Capture Image.")
            if let error = error {
                print(error.localizedDescription)
            }
            imageCaptureDelegate?.didCaptureImage(image: nil, previewImage: nil, error: error)
        }
    }
    
    //MARK: Helper Functions
    
    //Check if capture session is ready to be created. (If device has camera and permissions to use it have been granted.)
    
    private func startBackgroundTask() {
        if backgroundTaskID == UIBackgroundTaskInvalid {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        }
    }
    
    private func endBackgroundTask() {
        let backgroundTask = self.backgroundTaskID
        self.backgroundTaskID = UIBackgroundTaskInvalid
        if backgroundTask != UIBackgroundTaskInvalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
    }
    
    private func canLoadCamera() -> Bool {
        let currentCameraState = PermissionsManager.checkIfCameraIsAvailable()
        return currentCameraState == .ready
    }
    
    //Get device capture resolution
    private func getCaptureResolution() -> CGSize? {
        
        // Set if video portrait orientation
        let portraitOrientation = deviceOrientation == .portrait || deviceOrientation == .portraitUpsideDown
        
        // Get video dimensions
        if let formatDescription = currentDevice?.activeFormat.formatDescription {
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            let resolution = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
            if (portraitOrientation) {
                return CGSize(width: resolution.height, height: resolution.width)
            } else { return resolution }
        }
        return nil
    }
    
    private func convert(ciimage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(ciimage, from: ciimage.extent)!
        let image:UIImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation(forDeviceOrientation: deviceOrientation, isMirrored: false))
        return image
    }
    
    private func timeInMinutesandSeconds(seconds : Int) -> (Int, Int) {
        return ((seconds) / 60, (seconds % 60))
    }
    
    //Requests permission to access microphone and camera, required to record video
    public func requestVideoRecordingPermissions(completion: @escaping (Bool) -> Void) {
        PermissionsManager.requestVideoCaptureAccess(completion: { (accessGranted) in
            PermissionsManager.requestAudioRecordAccess(completion: { (accessGranted) in
                DispatchQueue.main.async {
                    completion(accessGranted)
                }
            })
        })
    }
    
    open func retrieveSettingsFromUserDefaults() {

        if let option = CameraOutputQuality(rawValue: UserDefaultsHandler.defaultCameraOutputQualityMode()) {
            cameraOutputQuality = option
        }
        if let option = VideoExportQuality(rawValue: UserDefaultsHandler.defaultVideoExportQuality()) {
            videoExportQuality = option
        }
        shouldExportVideo = UserDefaultsHandler.shouldAllowEdit() ? false : true
        writeFilesToPhoneLibrary = UserDefaultsHandler.shouldSaveMedia()
    }
    
    //Performs shutter animation(When image is clicked). Set performShutterAnimation to FALSE if not required.
    open func performShutterAnimation(completion: (() -> Void)?) {
        if let validPreviewLayer = previewLayer {
            DispatchQueue.main.async {
                let duration = 0.1
                
                CATransaction.begin()
                
                if let completion = completion {
                    CATransaction.setCompletionBlock(completion)
                }
                
                let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
                fadeOutAnimation.fromValue = 1.0
                fadeOutAnimation.toValue = 0.0
                validPreviewLayer.add(fadeOutAnimation, forKey: "opacity")
                
                let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
                fadeInAnimation.fromValue = 0.0
                fadeInAnimation.toValue = 1.0
                fadeInAnimation.beginTime = CACurrentMediaTime() + duration * 2.0
                validPreviewLayer.add(fadeInAnimation, forKey: "opacity")
                
                CATransaction.commit()
            }
        }
    }
    
    open func doFlipAnimation() {
        if transitionAnimating {
            return
        }
        
        if let validEmbeddingView = embeddingView,
            let validPreviewLayer = previewLayer {
            let blurEffect = UIBlurEffect(style: .light)
            let tempView = UIVisualEffectView(effect: blurEffect)
            tempView.frame = validEmbeddingView.bounds
            
            validEmbeddingView.insertSubview(tempView, at: Int(validPreviewLayer.zPosition + 1))
            
            cameraTransitionView = validEmbeddingView.snapshotView(afterScreenUpdates: true)
            
            if let cameraTransitionView = cameraTransitionView {
                validEmbeddingView.insertSubview(cameraTransitionView, at: Int(validPreviewLayer.zPosition + 1))
            }
            tempView.removeFromSuperview()
            
            transitionAnimating = true
            validPreviewLayer.opacity = 0.0
            DispatchQueue.main.async {
                self.flipCameraTransitionView()
            }
        }
    }
    
    open func flipCameraTransitionView() {
        if let cameraTransitionView = cameraTransitionView {
            UIView.transition(with: cameraTransitionView,
                              duration: 0.5,
                              options: UIViewAnimationOptions.transitionFlipFromLeft,
                              animations: nil,
                              completion: { (_) -> Void in
                                self.removeCameraTransistionView()
            })
        }
    }
    
    open func removeCameraTransistionView() {
        if let cameraTransitionView = cameraTransitionView {
            if let validPreviewLayer = previewLayer {
                validPreviewLayer.opacity = 1.0
            }
            UIView.animate(withDuration: 0.5,
                           animations: { () -> Void in
                            
                            cameraTransitionView.alpha = 0.0
                            
            }, completion: { (_) -> Void in
                self.transitionAnimating = false
                
                cameraTransitionView.removeFromSuperview()
                self.cameraTransitionView = nil
            })
        }
    }
    
    class func saveImageToAlbum(image: UIImage, completion: ((Bool) -> Void)?) {
//        let location = CLLocationManager().location
        let date = Date()
        let photoLibrary = PhotoLibraryManager()
        photoLibrary.save(image: image, albumName: CameraManager.imageAlbumName, date: date, location: nil) { (asset) in
            guard let _ = asset else {
                completion?(false)
                return
                
            }
            completion?(true)
        }
    }
    
    class func saveVideoToAlbum(outputPath: URL, completion: ((Bool) -> Void)?) {
//        let location = CLLocationManager().location
        let date = Date()
        let photoLibrary = PhotoLibraryManager()
        photoLibrary.save(videoAtURL: outputPath, albumName: CameraManager.videoAlbumName, date: date, location: nil, completion: { (asset) in
            guard let _ = asset else {
                completion?(false)
                return
                
            }
            completion?(true)
        })
    }
    
    private func clearIntermediateSavedVideoClips() {
        guard let interMediateVideosFolder = fileManager.createFileinCacheDirectory(fileName: fileManager.intermediateVideosFolderName) else { return }
        fileManager.deleteFile(atUrl: interMediateVideosFolder)
    }
    
}

extension CameraManager: UIGestureRecognizerDelegate {
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            beginZoomScale = zoomScale
        }
        return true
    }
}

extension UIImage {
    func fixOrientation() -> UIImage
    {
        if imageOrientation == .up {
            return self
        }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
            break
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
            break
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
            break
        case .up, .upMirrored:
            break
        }
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform.translatedBy(x: size.width, y: 0)
            transform.scaledBy(x: -1, y: 1)
            break
        case .leftMirrored, .rightMirrored:
            transform.translatedBy(x: size.height, y: 0)
            transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        }
        
        guard let cgImageRepresentation = cgImage  else{ return self }
        guard let colorSpace = cgImageRepresentation.colorSpace
            else{return self}
        guard let ctx: CGContext = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: cgImageRepresentation.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else{return self}
        
        ctx.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(cgImageRepresentation, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(cgImageRepresentation, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        guard let imageCG = ctx.makeImage() else{ return self }
        return UIImage(cgImage: imageCG)
    }
}
