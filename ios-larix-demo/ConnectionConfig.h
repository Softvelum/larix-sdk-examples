#import <Foundation/Foundation.h>
#import "StreamerEngineDelegate.h"

@interface ConnectionConfig : NSObject

@property NSURL* uri;
@property ConnectionMode mode;
@property ConnectionAuthMode auth;
@property NSString* username;
@property NSString* password;

@end
