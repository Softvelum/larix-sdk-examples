import UIKit
import AVFoundation


class ViewController: UIViewController, AudioSessionStateObserver, StreamerAppDelegate {
    var streamer: Streamer?                             // Class to control camera and broadcasting
    var previewLayer: AVCaptureVideoPreviewLayer?       // Camera preview
    var permissionChecker: PermissionChecker            // Class to check camera/mic permission
    var canStartCapture = true                          // Used to prevent start capture when it already running
    var mediaResetPending = false                       // Used to reintialize capture after reset
    var isBroadcasting = false                          // Set to true when streaming is active
    var connectionId: Int32 = -1                        // ID of active connection
    var connectionState:ConnectionState = .disconnected //State of connection

    @IBOutlet weak var streamUrl: UITextField!
    @IBOutlet weak var broadcastButton: UIButton!
    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        permissionChecker = PermissionChecker()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        permissionChecker = PermissionChecker()
        super.init(coder: coder)
        permissionChecker.onGranted = startCapture
        permissionChecker.view = self
        permissionChecker.showStatusMessage = self.showStatusMessage
    }
    
    @IBAction func broadcastClick(_ sender: Any) {
        if isBroadcasting {
            stopBroadcast()
        } else {
            startBroadcast()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        AudioSession.sharedInstance?.observer = self //To receive mediaServicesWereLost and mediaServicesWereReset
        
        let nc = NotificationCenter.default
        nc.addObserver(self,
            selector: #selector(applicationDidBecomeActive),
            name: UIScene.didActivateNotification,
            object: nil)

        nc.addObserver(self,
            selector: #selector(applicationWillResignActive),
            name: UIScene.willDeactivateNotification,
            object: nil)
    }

    
    // MARK: Application state transition
    @objc func applicationDidBecomeActive() {
        if viewIfLoaded?.window != nil {
            permissionChecker.check()
        }
   }
    
    @objc func applicationWillResignActive() {
        if viewIfLoaded?.window != nil {
            stopBroadcast()
            removePreview()
            stopCapture()
        }
    }
    
    // MARK: Respond to the media server crashing and restarting
    // https://developer.apple.com/library/archive/qa/qa1749/_index.html
    
    func mediaServicesWereLost() {
        if viewIfLoaded?.window != nil && permissionChecker.deviceAuthorized {
            mediaResetPending = streamer?.session != nil
            stopBroadcast()
            removePreview()
            stopCapture()
            
            showStatusMessage(message: NSLocalizedString("Waiting for media services initialize.", comment: ""))
        }
    }
    
    func mediaServicesWereReset() {
        if viewIfLoaded?.window != nil && permissionChecker.deviceAuthorized == true {
            NSLog("mediaServicesWereReset, pending:\(mediaResetPending)")
            if mediaResetPending {
                startCapture()
                mediaResetPending = false
            }
        }
    }

    //MARK: Create camera capture session
    //Note: method is called on a background thread after permission request. Move your UI update codes inside the main queue.
    func startCapture() {
        guard canStartCapture else {
            return
        }
        do {
            DispatchQueue.main.async {
                self.statusLabel.isHidden = true
            }
            canStartCapture = false
            removePreview()

            if streamer == nil {
                streamer = Streamer()
            }
            streamer?.delegate = self
            try streamer?.startCapture()

            let nc = NotificationCenter.default
            nc.addObserver(
                self,
                selector: #selector(orientationDidChange(notification:)),
                name: UIDevice.orientationDidChangeNotification,
                object: nil)
        } catch {
            NSLog("can't start capture: %@", error.localizedDescription)
            canStartCapture = true
        }
    }
    
    func stopCapture() {
        NSLog("stopCapture")
        canStartCapture = true

        streamer?.stopCapture()
        streamer = nil
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: UIDevice.orientationDidChangeNotification,
                          object: nil)
    }
    
    //MARK: Start streaming
    func startBroadcast() {
        guard let str = streamUrl.text, let _ = URL(string: str) else {
            showStatusMessage(message: NSLocalizedString("Please enter valid stream URL", comment: ""))
            return
        }
        broadcastWillStart()
        createConnection(urlTo: str)
    }
    
    func stopBroadcast() {
        broadcastWillStop()
        releaseConnection(id: connectionId)
    }
    
    // MARK: Update UI on broadcast start
    func broadcastWillStart() {
        if !isBroadcasting {
            NSLog("start broadcasting")
            isBroadcasting = true
            showStatusMessage(message: NSLocalizedString("Connecting...", comment: ""))
            broadcastButton.setTitle(NSLocalizedString("Disconnect", comment: ""), for: .normal)
            streamUrl.endEditing(false)
        }
    }
    
    func broadcastWillStop() {
        if isBroadcasting {
            NSLog("stop broadcasting")
            isBroadcasting = false
            statusLabel.isHidden = true
            broadcastButton.setTitle(NSLocalizedString("Connect", comment: ""), for: .normal)
            streamUrl.endEditing(false)
        }
    }
    
    
    // MARK: StreamerAppDelegate methods
    // Method may be called on a background thread. Move UI update code inside the main queue.
    func captureStateDidChange(state: CaptureState, status: Error) {
        DispatchQueue.main.async {
            self.onCaptureStateChange(state: state, status: status)
        }
    }
    
    func onCaptureStateChange(state: CaptureState, status: Error) {
        switch (state) {
        case .CaptureStateStarted:
            if let session = streamer?.session {
                previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer?.frame = view.frame
                previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
                if let preview = previewLayer {
                    cameraPreview.layer.addSublayer(preview)
                }
            }
            
        case .CaptureStateFailed:
            if streamer == nil {
                //Capture failed, but we're not running anyway
                return
            }
            stopBroadcast()
            removePreview()
            stopCapture()
            
            showStatusMessage(message: status.localizedDescription)
            
        case .CaptureStateCanRestart:
            showStatusMessage(message: String.localizedStringWithFormat(NSLocalizedString("You can try to restart capture now.", comment: ""), status.localizedDescription))
            
        case .CaptureStateSetup:
            showStatusMessage(message: status.localizedDescription)
            
        default: break
        }
    }
    
    // MARK: Connection utitlites
    func createConnection(urlTo: String) {
        
        var id: Int32 = -1
        let url = URL.init(string: urlTo)
        
        if let scheme = url?.scheme?.lowercased(), let host = url?.host {

            if scheme.hasPrefix("rtmp") || scheme.hasPrefix("rtsp") {
                let config = ConnectionConfig()
                config.uri = url
                id = streamer?.createConnection(config: config) ?? -1
                
            } else if scheme == "srt", let port = url?.port {
                let config = SrtConfig()
                config.host = host
                config.port = Int32(port)
                id = streamer?.createConnection(config: config) ?? -1
            } else if scheme == "rist" {
                let config = RistConfig()
                config.uri = url

                id = streamer?.createConnection(config: config) ?? -1
            }
        }
        
        if id != -1 {
            connectionId = id
        } else {
            let message = String.localizedStringWithFormat(NSLocalizedString("Could not create connection to %@.", comment: ""),
                                                           urlTo)
            showStatusMessage(message: message)
        }
        NSLog("SwiftApp::create connection: \(id), \(urlTo)" )
    }
    
    func releaseConnection(id: Int32) {
        if id != -1 {
            connectionId = -1
            connectionState = .disconnected
            streamer?.releaseConnection(id: id)
        }
    }
    
    func removePreview() {
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }
    
    //MARK: StreamerAppDelegate callbacks
    // Method is called on a background thread. Move UI update code inside the main queue.
    func connectionStateDidChange(id: Int32, state: ConnectionState, status: ConnectionStatus, info: [AnyHashable:Any]!) {
        DispatchQueue.main.async {
            self.onConnectionStateChange(id: id, state: state, status: status, info: info)
        }
    }
    
    func onConnectionStateChange(id: Int32, state: ConnectionState, status: ConnectionStatus, info: [AnyHashable:Any]!) {
        
        // ignore disconnect confirmation after releaseConnection call
        if id != connectionId { return }
        var message: String?
            
        connectionState = state
        
        if state == .connected {
            showStatusMessage(message: NSLocalizedString("Connected", comment: ""))
        }
        
        if state != .disconnected {
            return
        }
        
        releaseConnection(id: id)
            
        switch (status) {
        case .connectionFail:
            message = NSLocalizedString("Could not connect to server. Please check stream URL and network connection.", comment: "")
           
        case .unknownFail:
            var status: String?
            if let info = info, info.count > 0 {
                if let jsonData = try? JSONSerialization.data(withJSONObject: info) {
                    status = String(data: jsonData, encoding: .utf8)
                }
            }
            
            if let status = status {
                message = NSLocalizedString("Error: \(status)", comment: "")
            } else {
                message = NSLocalizedString("Unknown connection error", comment: "")
            }
        case .authFail:
             message = NSLocalizedString("Authentication error. Please check stream credentials.", comment: "")

        case .success:
            message = "Disconnected"
            break
            
        @unknown default:
            break
        }
        if message != nil {
            showStatusMessage(message: message!)

        }
        stopBroadcast()
    }
    
    // MARK: Device orientation
    @objc func orientationDidChange(notification: Notification) {
        let frame = cameraPreview.frame
        previewLayer?.frame = frame

        let deviceOrientation = UIApplication.shared.statusBarOrientation
        let newOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) ?? AVCaptureVideoOrientation.portrait
        previewLayer?.connection?.videoOrientation = newOrientation
    }
    
    func showStatusMessage(message: String) {
        statusLabel.isHidden = false
        statusLabel.text = message
    }
   
}

