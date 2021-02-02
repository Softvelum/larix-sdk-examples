#import <Foundation/Foundation.h>

@interface AudioEncoderConfig : NSObject

// If you do not explicitly set a sample rate then the encoder will use the same value which is available in the un-compressed audio, just to avoid unnecessary re-sampling.
@property double sampleRate;

// If you do not explicitly set a bit rate then the encoder will pick the correct value for you depending on sample rate.
@property int bitrate;

@property int channelCount;

// On iPhoneOS, a codec's manufacturer can be used to distinguish between hardware and software codecs (kAppleSoftwareAudioCodecManufacturer vs kAppleHardwareAudioCodecManufacturer).
@property UInt32 manufacturer;

@end
