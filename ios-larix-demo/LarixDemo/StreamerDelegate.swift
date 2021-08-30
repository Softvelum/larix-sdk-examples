enum CaptureState {
    case CaptureStateSetup
    case CaptureStateStarted
    case CaptureStateStopped
    case CaptureStateFailed
    case CaptureStateCanRestart
}

enum CaptureStatus: Error {
    case CaptureStatusSuccess
    case CaptureStatusErrorAudioEncode
    case CaptureStatusErrorVideoEncode
    case CaptureStatusErrorCaptureSession
    case CaptureStatusErrorMicInUse
    case CaptureStatusErrorCameraInUse
    case CaptureStatusErrorCameraUnavailable
    case CaptureStatusErrorSessionWasInterrupted
    case CaptureStatusErrorMediaServicesWereReset
    case CaptureStatusErrorAudioSessionWasInterrupted
}

extension CaptureStatus: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .CaptureStatusSuccess:
            return NSLocalizedString("No error", comment: "")
        case .CaptureStatusErrorAudioEncode:
            return NSLocalizedString("Can't start audio encoding", comment: "")
        case .CaptureStatusErrorVideoEncode:
            return NSLocalizedString("Can't start video encoding", comment: "")
        case .CaptureStatusErrorCaptureSession:
            return NSLocalizedString("Capture runtime error. Try to restart", comment: "")
        case .CaptureStatusErrorCameraInUse:
            return NSLocalizedString("Camera in use by another application. Try to restart", comment: "")
        case .CaptureStatusErrorMicInUse:
            return NSLocalizedString("Microphone in use by another application. Try to restart", comment: "")
        case .CaptureStatusErrorCameraUnavailable:
            return NSLocalizedString("Camera unavailable", comment: "")
        case .CaptureStatusErrorSessionWasInterrupted:
            return NSLocalizedString("Capture session was interrupted. Try to restart", comment: "")
        case .CaptureStatusErrorMediaServicesWereReset:
            return NSLocalizedString("Media services were reset. Try to restart", comment: "")
        case .CaptureStatusErrorAudioSessionWasInterrupted:
            return NSLocalizedString("Audio session was interrupted. Try to restart", comment: "")
        }
    }
}

protocol StreamerAppDelegate: AnyObject {
    func connectionStateDidChange(id: Int32, state: ConnectionState, status: ConnectionStatus, info: [AnyHashable:Any]!)
    func captureStateDidChange(state: CaptureState, status: Error)
}
