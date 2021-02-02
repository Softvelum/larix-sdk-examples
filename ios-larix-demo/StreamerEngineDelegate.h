typedef NS_ENUM(int, ConnectionAuthMode) {
    kConnectionAuthModeDefault = 0,
    kConnectionAuthModeLlnw = 1,
    kConnectionAuthModePeriscope = 2,
    kConnectionAuthModeRtmp = 3,
    kConnectionAuthModeAkamai = 4
};

typedef NS_ENUM(int, ConnectionMode) {
    kConnectionModeVideoAudio = 0,
    kConnectionModeVideoOnly = 1,
    kConnectionModeAudioOnly = 2
};

typedef NS_ENUM(int, ConnectionRetransmitAlgo) {
    kConnectionRetransmitAlgoDefault = 0,
    kConnectionRetransmitAlgoReduced = 1
};

typedef NS_ENUM(int, ConnectionState) {
    kConnectionStateInitialized,
    kConnectionStateConnected,
    kConnectionStateSetup,
    kConnectionStateRecord,
    kConnectionStateDisconnected
};

typedef NS_ENUM(int, ConnectionStatus) {
    kConnectionStatusSuccess,
    kConnectionStatusConnectionFail,
    kConnectionStatusAuthFail,
    kConnectionStatusUnknownFail
};

typedef NS_ENUM(int, RecordState) {
    kRecordStateInitialized,
    kRecordStateStarted,
    kRecordStateStopped,
    kRecordStateFailed
};


@protocol StreamerEngineDelegate<NSObject>
- (void)connectionStateDidChangeId:(int)connectionID State:(ConnectionState)state Status:(ConnectionStatus)status Info:(nonnull NSDictionary*)info;
@optional
- (void)recordStateDidChange: (RecordState) state url: (nullable NSURL*) url;

@end
