//
//  Constants.m
//  videosnap
//
//  Created by Matthew Hutchinson
//

#import <Foundation/Foundation.h>
#import "Constants.h"

NSString *const VERSION = @"0.0.8";

int const DEFAULT_FRAMES_PER_SECOND = 30;
float const DEFAULT_RECORDING_DELAY = 0.5;
NSString *const DEFAULT_ENCODING_PRESET = @"Medium";

// encoding preset options:
// High - Highest recording quality (varies per device)
// Medium - Suitable for WiFi sharing (actual values may change)
// Low - Suitable for 3G sharing (actual values may change)
// 640x480 - 640x480 VGA (check its supported before setting it)
// 1280x720 - 1280x720 720p HD (check its supported before setting it)
// 1920x1080 - 1920x1080 Full HD (check its supported before setting it)
// 3840x2160 - 3840x2160 HD4k (check its supported before setting it)

NSString *const DEFAULT_ENCODING_PRESETS   = @"High, Medium, Low, 640x480, 1280x720, 1920x1080, 3840x2160";
int       const DEFAULT_BITRATE = 5000000; // 5 Mbps default bitrate
NSString *const DEFAULT_RESOLUTION = @"1280x720"; // Default resolution for custom preset
