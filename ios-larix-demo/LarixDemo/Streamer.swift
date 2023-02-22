import AVFoundation

enum StreamerError: LocalizedError {
    case DeviceNotAuthorized
    case NoDelegate
    case SetupFailed
    
    public var errorDescription: String? {
        switch self {
        case .DeviceNotAuthorized:
            return NSLocalizedString("Allow the app to access camera and microphone in your device's settings", comment: "")
        case .SetupFailed:
            return NSLocalizedString("Can't initialize capture", comment: "")
        default:
            return NSLocalizedString("Can't initialize streamer", comment: "")
        }
    }
}

class StreamerSingleton {
#if MBL
    static let sharedEngine = StreamerEngineProxy()
#endif
    static let sharedQueue = DispatchQueue(label: "StreamingQueue")
    private init() {} // This prevents others from using the default '()' initializer for this class.
}

class Streamer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate,
 StreamerEngineDelegate {

    weak var delegate: StreamerAppDelegate?
    var session: AVCaptureSession?
    private var cameraDevice: AVCaptureDevice?

    private var position: AVCaptureDevice.Position = .back //Use back camera
    // Video resolution
    private var streamWidth: Int32 = 1280
    private var streamHeight: Int32 = 720
    private var streamFps: Int32 = 30

    private var workQueue = StreamerSingleton.sharedQueue
#if MBL
    private var engine = StreamerSingleton.sharedEngine
#endif
#if WEBRTC
    var webRtcEngine: RtcStreamEngine
#endif

    private let PixelFormat_YUV = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

    override init() {
#if WEBRTC
        webRtcEngine = RtcStreamEngine()
#endif
        super.init()
#if MBL
        engine.setDelegate(self)
        engine.setInterleaving(true)
#endif
#if WEBRTC
        webRtcEngine.delegate = self
#endif
    }
    
#if MBL
    // MARK: RTMP/RTSP connection
    func createConnection(config: ConnectionConfig) -> Int32 {
        return engine.createConnection(config)
    }
    
    // MARK: SRT connection
    func createConnection(config: SrtConfig) -> Int32 {
        return engine.createSrtConnection(config)
    }
    
    // MARK: RIST connection
    func createConnection(config: RistConfig) -> Int32 {
        return engine.createRistConnection(config)
    }
#endif

#if WEBRTC
    func createConnection(config: WebRtcConfig) -> Int32 {
        return webRtcEngine.createWebRtcConnection(config)
    }
#endif

    func releaseConnection(id: Int32) {
#if MBL
        engine.releaseConnection(id)
#endif
#if WEBRTC
        webRtcEngine.releaseConnectionId(id)
#endif
    }
    
    // MARK: Connection: notifications
    public func connectionStateDidChangeId(_ connectionID: Int32, state: ConnectionState, status: ConnectionStatus, info: [AnyHashable:Any]) {
        delegate?.connectionStateDidChange(id: connectionID, state: state, status: status, info: info)
    }
    
    // MARK: Capture setup
    func startCapture() throws {
        guard delegate != nil else {
            throw StreamerError.NoDelegate
        }
        guard AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus.authorized else {
            throw StreamerError.DeviceNotAuthorized
        }
        guard AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized else {
            throw StreamerError.DeviceNotAuthorized
        }

        workQueue.async {
            do {
                guard self.session == nil else {
                    NSLog("session is running (guard)")
                    return
                }
                
                // IMPORTANT NOTE:
                // The way applications handle audio is through the use of audio sessions. When your app is launched, behind the scenes it is provided with a singleton instance of an AVAudioSession. Your app use the shared instance of AVAudioSession to configure the behavior of audio in the application.
                // https://developer.apple.com/documentation/avfoundation/avaudiosession
                // Before configuring AVCaptureSession app MUST configure and activate audio session. Refer to AppDelegate.swift for details.

                // AVCaptureSession is completely managed by application, libmbl2 will not change neither CaptureSession's settings nor camera settings.
                self.session = AVCaptureSession()

                // Raw audio and video will be delivered to app in form of CMSampleBuffer. Refer to func captureOutput for details.
                
                try self.setupAudio()
                try self.setupVideoIn()
                try self.setupVideoOut()

#if MBL
                self.engine.setAudioConfig(self.createAudioEncoderConfig())
                self.engine.setVideoConfig(self.createVideoEncoderConfig())
                
                // Start VTCompressionSession to encode raw video to h264, and then feed libmbl2 with CMSampleBuffer produced by AVCaptureSession.
                let videoStarted = self.engine.startVideoEncoding()
                if !videoStarted {
                    self.delegate?.captureStateDidChange(state: CaptureState.CaptureStateFailed, status: CaptureStatus.CaptureStatusErrorVideoEncode)
                    return
                }
#endif
#if WEBRTC
                self.webRtcEngine.setVideoConfig(self.createVideoEncoderConfig())
#endif
                
                // Only setup observers and start the session running if setup succeeded.
                self.registerForNotifications()
                self.session!.startRunning()
                // Wait for AVCaptureSessionDidStartRunning notification.
                
            } catch {
                NSLog("can't start capture: \(error)")
                self.delegate?.captureStateDidChange(state: CaptureState.CaptureStateFailed, status: error)
            }
        }
    }
    
    private func createAudioEncoderConfig() -> AudioEncoderConfig {
        let config = AudioEncoderConfig()
        
        config.channelCount = 1
        config.sampleRate = 48000
        config.bitrate = 160000
        config.manufacturer = kAppleSoftwareAudioCodecManufacturer
        
        return config
    }
    
    private func createVideoEncoderConfig() -> VideoEncoderConfig {
        let config = VideoEncoderConfig()
        
        config.pixelFormat = PixelFormat_YUV
        
        config.width = streamWidth
        config.height = streamHeight
        config.type = kCMVideoCodecType_H264
        
        config.fps = streamFps
        // Convert key frame interval from seconds to number of frames. A key frame interval of 1 indicates that every frame must be a keyframe, 2 indicates that at least every other frame must be a keyframe, and so on.
        config.maxKeyFrameInterval = streamFps * 2
        
        config.bitrate = 2000000
        
        return config
    }
    
    private func setupVideoIn() throws {
        guard let session = self.session else { throw StreamerError.SetupFailed }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            NSLog("streamer fail: can't open camera device")
            throw StreamerError.SetupFailed
        }
        cameraDevice = camera
        
        let videoIn: AVCaptureDeviceInput
        do {
            videoIn = try AVCaptureDeviceInput(device: camera)
        } catch {
            NSLog("streamer fail: can't allocate video input: \(error)")
            throw StreamerError.SetupFailed
        }

       if session.canAddInput(videoIn) {
           session.addInput(videoIn)
       } else {
           NSLog("streamer fail: can't add video input")
           throw StreamerError.SetupFailed
       }
       // video input configuration completed
    }

    private func setupVideoOut() throws {
        guard let camera = cameraDevice, let session = self.session else { throw StreamerError.SetupFailed }

        if !setCameraParams(camera) {
            throw StreamerError.SetupFailed
        }

        let videoOut = AVCaptureVideoDataOutput()
        videoOut.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String) : NSNumber(value: PixelFormat_YUV)]
        videoOut.alwaysDiscardsLateVideoFrames = true
        videoOut.setSampleBufferDelegate(self, queue: workQueue)
        
        if session.canAddOutput(videoOut) {
            session.addOutput(videoOut)
        } else {
            NSLog("streamer fail: can't add video output")
            throw StreamerError.SetupFailed
        }
        
        guard let videoConnection = videoOut.connection(with: AVMediaType.video) else {
            NSLog("streamer fail: can't allocate video connection")
            throw StreamerError.SetupFailed
        }
        videoConnection.videoOrientation = .landscapeRight
    }
    
    private func setCameraParams(_ camera: AVCaptureDevice) -> Bool {
        //Find camera format with needed resolution
        let activeFormat = camera.formats.first(where: { (format) -> Bool in
            if CMFormatDescriptionGetMediaType(format.formatDescription) != kCMMediaType_Video {
                return false
            }
            let resolution = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return resolution.width == streamWidth && resolution.height == streamHeight
        })

        guard let format = activeFormat else {
            NSLog("streamer fail: can't find video output format")
            return false
        }
        do {
            try camera.lockForConfiguration()
        } catch {
            NSLog("streamer fail: can't lock video device for configuration: \(error)")
           return false
        }

        camera.activeFormat = format
        camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: streamFps)
        camera.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: streamFps)

        camera.unlockForConfiguration()
        
        return true
    }
    
    private func setupAudio() throws {
        // start audio input configuration
        guard let mic = AVCaptureDevice.default(for: AVMediaType.audio) else {
            NSLog("streamer fail: can't open audio device")
            throw StreamerError.SetupFailed
        }
        
        let audioIn: AVCaptureDeviceInput
        do {
            audioIn = try AVCaptureDeviceInput(device: mic)
        } catch {
            NSLog("streamer fail: can't allocate audio input: \(error)")
            throw StreamerError.SetupFailed
        }
        
        if session!.canAddInput(audioIn) {
            session!.addInput(audioIn)
        } else {
            NSLog("streamer fail: can't add audio input")
            throw StreamerError.SetupFailed
        }
        // audio input configuration completed
        
        // start audio output configuration
        let audioOut = AVCaptureAudioDataOutput()
        audioOut.setSampleBufferDelegate(self, queue: workQueue)
        
        if session!.canAddOutput(audioOut) {
            session!.addOutput(audioOut)
        } else {
            NSLog("streamer fail: can't add audio output")
            throw StreamerError.SetupFailed
        }
        
        guard let _ = audioOut.connection(with: AVMediaType.audio) else {
            NSLog("streamer fail: can't allocate audio connection")
            throw StreamerError.SetupFailed
        }
        // audio output configuration completed
    }
    
    func stopCapture() {
        workQueue.async {
            self.releaseCapture()
        }
    }
    
    private func releaseCapture() {
        for out in session!.outputs {
            if let audioOut = out as? AVCaptureAudioDataOutput {
                audioOut.setSampleBufferDelegate(nil, queue: nil)
            } else if let videoOut = out as? AVCaptureVideoDataOutput {
                videoOut.setSampleBufferDelegate(nil, queue: nil)
            }
        }
        #if MBL
        engine.stopVideoEncoding()
        engine.stopAudioEncoding()
        #endif
        #if WEBRTC
        webRtcEngine.stop()
        #endif
        if session?.isRunning == true {
            session?.stopRunning()
        }
        
        NotificationCenter.default.removeObserver(self)
        
        session = nil
        
        delegate?.captureStateDidChange(state: CaptureState.CaptureStateStopped, status: CaptureStatus.CaptureStatusSuccess)
        
        NSLog("All capture released")
    }
    
    // MARK: Notifications from capture session
    private func registerForNotifications() {
    let nc = NotificationCenter.default
    
    nc.addObserver(
        self,
        selector: #selector(sessionDidStartRunning(notification:)),
        name: NSNotification.Name.AVCaptureSessionDidStartRunning,
        object: session)
    
    nc.addObserver(
        self,
        selector: #selector(sessionRuntimeError(notification:)),
        name: NSNotification.Name.AVCaptureSessionRuntimeError,
        object: session)
    
    nc.addObserver(
        self,
        selector: #selector(sessionWasInterrupted(notification:)),
        name: NSNotification.Name.AVCaptureSessionWasInterrupted,
        object: session)
    
    nc.addObserver(
        self,
        selector: #selector(sessionInterruptionEnded(notification:)),
        name: NSNotification.Name.AVCaptureSessionInterruptionEnded,
        object: session)
    }
    
    @objc private func sessionDidStartRunning(notification: Notification) {
        NSLog("AVCaptureSessionDidStartRunning")
        delegate?.captureStateDidChange(state: CaptureState.CaptureStateStarted, status: CaptureStatus.CaptureStatusSuccess)
    }
    
    @objc private func sessionRuntimeError(notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        NSLog("AVCaptureSessionRuntimeError: \(error)")
        delegate?.captureStateDidChange(state: CaptureState.CaptureStateFailed, status: CaptureStatus.CaptureStatusErrorCaptureSession)
    }
    
    @objc private func sessionWasInterrupted(notification: Notification) {
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?, let reasonIntegerValue = userInfoValue.integerValue, let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            NSLog("AVCaptureSessionWasInterrupted \(reason)")
            
            if reason == .videoDeviceNotAvailableInBackground {
                return // Session will be stopped by Larix app when it goes to background, ignore notification
            }
            
            var status = CaptureStatus.CaptureStatusErrorSessionWasInterrupted // Unknown error
            if reason == .audioDeviceInUseByAnotherClient {
                status = CaptureStatus.CaptureStatusErrorMicInUse
            } else if reason == .videoDeviceInUseByAnotherClient {
                status = CaptureStatus.CaptureStatusErrorCameraInUse
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                status = CaptureStatus.CaptureStatusErrorCameraUnavailable
            }
            delegate?.captureStateDidChange(state: CaptureState.CaptureStateFailed, status: status)
        }
    }
    
    @objc private func sessionInterruptionEnded(notification: Notification) {
        NSLog("AVCaptureSessionInterruptionEnded")
        delegate?.captureStateDidChange(state: CaptureState.CaptureStateCanRestart, status: CaptureStatus.CaptureStatusSuccess)
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }
        
#if MBL
        if output is AVCaptureVideoDataOutput {
            engine.didOutputVideoSampleBuffer(sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            engine.didOutputAudioSampleBuffer(sampleBuffer)
        }
#endif
#if WEBRTC
        if output is AVCaptureVideoDataOutput {
            webRtcEngine.didOutputVideoSampleBuffer(sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            webRtcEngine.didOutputAudioSampleBuffer(sampleBuffer)
        }
#endif
    }
}
