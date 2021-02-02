#import <Foundation/Foundation.h>
#import "StreamerEngineDelegate.h"


typedef NS_ENUM(int, RistProfile) {
    kRistProfileSimple = 0,
    kRistProfileMain = 1,
    kRistProfileAdvanced = 2
};

@interface RistConfig : NSObject

@property NSURL* uri;
@property ConnectionMode mode;
@property RistProfile profile;

@end
