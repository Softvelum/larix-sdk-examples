#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

#import "StreamerEngineDelegate.h"
#import "AudioEncoderConfig.h"
#import "VideoEncoderConfig.h"
#import "ConnectionConfig.h"
#import "SrtConfig.h"
#import "RistConfig.h"

@interface StreamerEngineProxy : NSObject

@property (readonly) AudioEncoderConfig *audioConfig;
@property (readonly) VideoEncoderConfig *videoConfig;
@property (weak, readonly) id<StreamerEngineDelegate> delegate;

// buffer size is video frames per second + audio frames per second
// average video framerate is approximately 30 fps
// audio also is frame based (for AAC, it's 1024 samples frames),
// so for 44.1 kHz, you can have audio duration only with a 23 ms granularity
//
// 1 second buffer will need 30 video frames + 42 audio frames
//
// default buffer size is 200 items (approx. 3 sec), at least 1 sec buffer is mandatory
- (id)initWithMaxItems:(int)capacity;

- (void)setDelegate:(id<StreamerEngineDelegate>)newDelegate;
- (void)setAudioConfig:(AudioEncoderConfig *)newConfig;
- (void)setVideoConfig:(VideoEncoderConfig *)newConfig;

// set custom flashVer for rtmp protocol: "FMLE/3.0 (compatible; customUserAgent)"
- (void)setUserAgent:(NSString *)customUserAgent;

-(void)setInterleaving:(Boolean)enabled;

- (bool)startVideoEncoding;
- (void)stopVideoEncoding;

- (void)updateBitrate:(int)newBitrate;
- (void)updateLimit:(int)newLimit;

- (void)stopAudioEncoding;

- (double)getFps;

// Number of bytes sent
- (uint64_t)getBytesSent:(int)connectionID;
// Number of bytes delivered to the receiver
- (uint64_t)getBytesDelivered:(int)connectionID;
- (uint64_t)getBytesRecv:(int)connectionID;

- (uint64_t)getAudioPacketsSent:(int)connectionID __attribute__((deprecated("use getBytesSent instead.")));
- (uint64_t)getVideoPacketsSent:(int)connectionID __attribute__((deprecated("use getBytesSent instead.")));;

- (uint64_t)getAudioPacketsLost:(int)connectionID __attribute__((deprecated("use getBytesSent and getBytesDelivered instead.")));
- (uint64_t)getVideoPacketsLost:(int)connectionID __attribute__((deprecated("use getBytesSent and getBytesDelivered instead.")));

// Number of packets lost on SRT connection
- (uint64_t)getUdpPacketsLost:(int)connectionID;

// if you don't do postprocessing with CoreImage, simply pass CMSampleBuffer to h264 encoder
- (void)didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
// if you do postprocessing with CoreImage, your output will be of CVPixelBuffer type
// pass timestamp from camera as is for better audio/video sync
- (void)didOutputVideoPixelBuffer:(CVPixelBufferRef)pixelBufferRef withPresentationTime:(CMTime)time;
// if you render static image, let libmbl2 take care of timestamp (CACurrentMediaTime() will be used)
- (void)didOutputVideoPixelBuffer:(CVPixelBufferRef)pixelBufferRef;

- (void)didOutputAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (int)createConnection:(ConnectionConfig *)config;
- (int)createSrtConnection:(SrtConfig *)config;
- (int)createRistConnection:(RistConfig *)config;

- (void)releaseConnection:(int)connectionId;

// Start stream recording to file
-(bool)startFileWriter: (NSURL*) fileUrl mode: (ConnectionMode) mode;
// Switch recording to another file. Switch will be delayed till next keyframe
-(bool)switchFileWriter: (NSURL*) fileUrl;
// Stop stream recording
-(void)stopFileWriter;

// To mute audio client should not stop sending audio frames. This will highly likely break playback, because majority of video players depend on audio timestamps continuity.
// Instead libmbl2 produces silence in audio stream and keeps continious audio timestamp sequence.
- (void)setSilence:(Boolean)silence;

// https://helpx.adobe.com/adobe-media-server/dev/adding-metadata-live-stream.html
// Each metadata item is a property with a name and a value set in the metadata dictionary
// NSString and NSNumber values are supported. To add boolean value, use [NSNumber numberWithBool:YES]

// send "@setDataFrame", "onMetaData", metadata
- (bool)pushMetaData:(int)connectionID metadata:(NSDictionary *)params;
// send "handler", metadata
- (bool)sendDirect:(int)connectionID handler:(NSString *)handler metadata:(NSDictionary *)params;


@end
