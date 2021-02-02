import Foundation
import AVFoundation

protocol AudioSessionStateObserver {
    func mediaServicesWereLost()
    func mediaServicesWereReset()
}

class AudioSession {
    
    let session: AVAudioSession
    var isActive: Bool
    weak static var sharedInstance: AudioSession?
    var observer: AudioSessionStateObserver?
    
    init() {
        session = AVAudioSession.sharedInstance()
        isActive = false
        if Self.sharedInstance == nil {
            Self.sharedInstance = self
        }
    }
    
    func start() {
        observeAudioSessionNotifications(true)
        activateAudioSession()
    }
    
    func activateAudioSession() {
        // Each app running in iOS has a single audio session, which in turn has a single category. You can change your audio session’s category while your app is running.
        // You can refine the configuration provided by the AVAudioSessionCategoryPlayback, AVAudioSessionCategoryRecord, and AVAudioSessionCategoryPlayAndRecord categories by using an audio session mode, as described in Audio Session Modes.
        // https://developer.apple.com/reference/avfoundation/avaudiosession
        
        // While AVAudioSessionCategoryRecord works for the builtin mics and other bluetooth devices it did not work with AirPods. Instead, setting the category to AVAudioSessionCategoryPlayAndRecord allows recording to work with the AirPods.

        // AVAudioSession is completely managed by application, libmbl2 doesn't modify AVAudioSession settings.
        do {
            try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetooth])
            try session.setActive(true)
            isActive = true
        } catch {
            isActive = false
            NSLog("activateAudioSession: \(error.localizedDescription)")
        }
    }
    
    func stopAudio() {
        deactivateAudioSession()
        observeAudioSessionNotifications(false)
    }
    
    func deactivateAudioSession() {
        do {
            try session.setActive(false)
            isActive = false
        } catch {
            NSLog("deactivateAudioSession: \(error.localizedDescription)")
        }
    }
    
    func observeAudioSessionNotifications(_ observe:Bool) {
        let audioSession = AVAudioSession.sharedInstance()
        let center = NotificationCenter.default
        if observe {
            center.addObserver(self, selector: #selector(handleAudioSessionInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: audioSession)
            center.addObserver(self, selector: #selector(handleAudioSessionMediaServicesWereLost(notification:)), name: AVAudioSession.mediaServicesWereLostNotification, object: audioSession)
            center.addObserver(self, selector: #selector(handleAudioSessionMediaServicesWereReset(notification:)), name: AVAudioSession.mediaServicesWereResetNotification, object: audioSession)
        } else {
            center.removeObserver(self, name: AVAudioSession.interruptionNotification, object: audioSession)
            center.removeObserver(self, name: AVAudioSession.mediaServicesWereLostNotification, object: audioSession)
            center.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: audioSession)
        }
    }
    
    @objc func handleAudioSessionInterruption(notification: Notification) {
        if let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber, let interruptionType = AVAudioSession.InterruptionType(rawValue: UInt(value.intValue)) {
            switch interruptionType {
            case AVAudioSessionInterruptionType.began:
                deactivateAudioSession()
            case AVAudioSessionInterruptionType.ended:
                activateAudioSession()
            default:
                break
            }
        }
    }
    
    // MARK: Respond to the media server crashing and restarting
    // https://developer.apple.com/library/archive/qa/qa1749/_index.html
    
    @objc func handleAudioSessionMediaServicesWereLost(notification: Notification) {
        observer?.mediaServicesWereLost()
    }
    
    @objc func handleAudioSessionMediaServicesWereReset(notification: Notification) {
        deactivateAudioSession()
        activateAudioSession()
        observer?.mediaServicesWereReset()
    }
}
