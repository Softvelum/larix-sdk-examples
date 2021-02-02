#import <Foundation/Foundation.h>
#import <CoreMedia/CMFormatDescription.h>

@interface VideoEncoderConfig : NSObject

// https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/StreamingMediaGuide/FrequentlyAskedQuestions/FrequentlyAskedQuestions.html

// Although the protocol specification does not limit the video and audio formats, the current Apple implementation supports the following video formats:
// H.264 Baseline Level 3.0, Baseline Level 3.1, Main Level 3.1, and High Profile Level 4.1.

// kVTProfileLevel_H264_Baseline_AutoLevel
// kVTProfileLevel_H264_Main_AutoLevel
// kVTProfileLevel_H264_High_AutoLevel

// One kilobit per second (abbreviated Kbps in the U.S.; kbps elsewhere) is equal to 1,000 bps.
// One megabit per second (Mbps) is equal to 1,000,000 bps or 1,000 Kbps.

// You control bit rate with two parameters: average bit rate (.bitrate) and data rate limit (.limit).
// Average bit rate is mandatory and data rate limit is optional.
// Both .bitrate and .limit should be in bps, for example 1080p video bit rate should be about 3,000,000 bps.
// Average bit rate is not a hard limit; the bit rate may peak above this.
// You are setting the .bitrate to 600 kbps and you are setting the .limit to 800 kbps. This means that bit rate should hover at around 600 kbps and not go above 800 kbps.

// No iPhone with a headphone jack will be able to record HEVC videos. The chips that support HEVC encoding are the A10 and new A11. The iPhone 7 was the first to have an A10 chip in it.

@property CMVideoCodecType type;
@property NSString *profileLevel;

@property int width;               // kCVPixelBufferWidthKey
@property int height;              // kCVPixelBufferHeightKey
@property int fps;                 // kVTCompressionPropertyKey_ExpectedFrameRate

// A key frame interval of 60 indicates that every 60 frame must be a keyframe. So for 30 fps frame rate 60 means 2 sec. interval, 30 means 1 sec. interval, and so on.
@property int maxKeyFrameInterval; // kVTCompressionPropertyKey_MaxKeyFrameInterval

@property int bitrate;             // kVTCompressionPropertyKey_AverageBitRate
@property int limit;               // optional kVTCompressionPropertyKey_DataRateLimits
@property UInt32 pixelFormat;      // kCVPixelBufferPixelFormatTypeKey (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)

@end
