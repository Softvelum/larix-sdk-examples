#import <Foundation/Foundation.h>
#import "StreamerEngineDelegate.h"

typedef NS_ENUM(int, SrtConnectMode) {
    kSrtConnectModeCaller = 0,
    kSrtConnectModeListen = 1,
    kSrtConnectModeRendezvous = 2
};

@interface SrtConfig : NSObject

@property NSString* host;
@property int port;
@property ConnectionMode mode;
@property SrtConnectMode connectMode;
@property NSString* passphrase;
@property int pbkeylen;
@property int latency;
@property int32_t maxbw;
@property ConnectionRetransmitAlgo retransmitAlgo;
@property NSString* streamid;

@end
