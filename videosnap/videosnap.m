//
//  VideoSnap.m
//  VideoSnap
//
//  Created by Matthew Hutchinson
//

#import "VideoSnap.h"

@implementation VideoSnap

/**
 * Prints help text to stdout
 */
+ (void)printHelp {

	console("VideoSnap (%s)\n\n", [VERSION UTF8String]);
	console("Record video and audio from a capture device\n\n");

	console("You can specify which device to capture from, the duration, encoding and delay\n");
	console("period (before capturing starts). You can also disable audio capture. By default\n");
	console("videosnap will capture video and audio from the first found device at %ifps with\n", DEFAULT_FRAMES_PER_SECOND);
	console("a Medium quality preset and a short (%.1fs) warm-up delay.\n", DEFAULT_RECORDING_DELAY);

	console("\nIf no duration is specified, videosnap will record until you cancel [Ctrl+c]\n");
	console("You can also use videosnap to list attached capture devices by name.\n");

	console("\nusage: videosnap [options] [file ...]");
	console("\n   eg: videosnap -t 5.75 -d 'FaceTime HD Camera (Built-in)' -p 'High' movie.mov\n\n");

	console("  -l          List attached capture devices\n");
	console("  -w x.xx     Set delay before capturing starts (in seconds, default %.1fs) \n", DEFAULT_RECORDING_DELAY);
	console("  -t x.xx     Set duration of video (in seconds)\n");
	console("  -d device   Set the capture device (by name, use -l to list attached devices)\n");
	console("  --no-audio  Don't capture audio\n");
	console("  -v          Turn ON verbose mode (OFF by default)\n");
	console("  -h          Show help\n");
	console("  -p          Set the encoding preset (Medium by default)\n");
	console("  -r WxH      Set custom resolution (e.g. 1920x1080, overrides preset)\n");
	console("  -f          Fit full image without cropping (default is to fill and crop)\n");
	console("  -b bitrate  Set custom bitrate in bps (e.g. 5000000 for 5Mbps)\n");
	console("  -s          Take a screenshot instead of recording video\n");

	NSArray *encodingPresets = [DEFAULT_ENCODING_PRESETS componentsSeparatedByString:@", "];
	for (id encodingPreset in encodingPresets) {
		console("                %s%s\n", [encodingPreset UTF8String], [[encodingPreset isEqualToString:DEFAULT_ENCODING_PRESET] ? @" (default)" : @"" UTF8String]);
	}
	console("\n");
}

/**
 * Initializer, setting verbosity
 */
- (id)initWithVerbosity:(BOOL)verbosity {
    isVerbose = verbosity;
    return [super init];
}

/**
 * Process command line args and return program ret code
 * TODO: refactor/create a seperate class for this, and build a NSDictionary for VideoSnap
 *       consider using NSUserDefaults somehow
 *       http://perspx.com/archives/parsing-command-line-arguments-nsuserdefaults/
 */
- (int)processArgs:(NSArray *)arguments {

    // argument defaults
    AVCaptureDevice *device;
    NSString        *encodingPreset    = DEFAULT_ENCODING_PRESET;
    NSNumber        *delaySeconds      = [NSNumber numberWithFloat:DEFAULT_RECORDING_DELAY];
    NSNumber        *recordingDuration = nil;
    BOOL            noAudio            = NO;
    BOOL            isScreenshotMode   = NO;
    int             customBitrate      = DEFAULT_BITRATE;
    NSString        *customResolution  = nil;
    BOOL            fitWithoutCropping = NO;

    int argc = (int)[arguments count];

    // only discover devices if we need to
    if([arguments indexOfObject:@"-h"] != NSNotFound) {
        [VideoSnap printHelp];
        return 0;
    } else {
        [self discoverDevices];
    }

    for (int i = 1; i < argc; i++) {
        NSString *argValue;
        NSString *arg = [arguments objectAtIndex: i];

        // set argument value if present
        if (i+1 < argc) {
            argValue = [arguments objectAtIndex: i+1];
        }

        // check for switches
        if ([arg characterAtIndex:0] == '-') {

            if([arg isEqualToString: @"--no-audio"]) {
                noAudio = YES;
            }

            if ([arg isEqualToString:@"-s"]) {
                isScreenshotMode = YES;
            }

            switch ([arg characterAtIndex:1]) {
                // list devices
                case 'l':
                    [self listConnectedDevices];
                    return 0;
                    break;

                // device
                case 'd':
                    if (i+1 < argc) {
                        device = [self deviceNamed:argValue];
                        if (device == nil) {
                            error("Device \"%s\" not found - aborting\n", [argValue UTF8String]);
                            return 128;
                        }
                        ++i;
                    }
                    break;

                // encodingPreset
                case 'p':
                    if (i+1 < argc) {
                        encodingPreset = argValue;
                        ++i;
                    }
                    break;
                    
                // custom resolution
                case 'r':
                    if (i+1 < argc) {
                        customResolution = argValue;
                        ++i;
                    }
                    break;
                    
                // fit without cropping
                case 'f':
                    fitWithoutCropping = YES;
                    break;
                    
                // custom bitrate
                case 'b':
                    if (i+1 < argc) {
                        customBitrate = [argValue intValue];
                        ++i;
                    }
                    break;

                // delaySeconds
                case 'w':
                    if (i+1 < argc) {
                        delaySeconds = [NSNumber numberWithFloat:[argValue floatValue]];
                        ++i;
                    }
                    break;

                // recordingDuration
                case 't':
                    if (i+1 < argc) {
                        recordingDuration = [NSNumber numberWithFloat:[argValue floatValue]];
                        ++i;
                    }
                    break;
            }
        } else  {
            filePath = arg;
        }
    }

    // check we have a file
    if (filePath == nil) {
        filePath = [self defaultGeneratedFilename];
        verbose("(no filename specified, using default: %s)\n", [filePath UTF8String]);
    }

    // check we have a device
    if (device == nil) {
        device = [self defaultDevice];
        if (device == nil) {
            error("No video devices found! - aborting\n");
            return 1;
        } else {
            verbose("(no device specified, using default)\n");
        }
    }

    // check we have a positive non zero duration
    if ([recordingDuration floatValue] <= 0.0f) {
        recordingDuration = nil;
    }

    // check we have a valid encodingPreset if no custom resolution is specified
    if (customResolution == nil) {
        NSArray *encodingPresets = [DEFAULT_ENCODING_PRESETS componentsSeparatedByString:@", "];
        NSArray *validChosenSize = [encodingPresets filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *option, NSDictionary *bindings) {
            return [encodingPreset isEqualToString:option];
        }]];

        if (!validChosenSize.count) {
            error("Invalid video preset! (must be one of %s) - aborting\n", [DEFAULT_ENCODING_PRESETS UTF8String]);
            return 128;
        }
    }

    // validate custom resolution format if specified
    if (customResolution != nil) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\d+x\\d+$" options:0 error:nil];
        NSUInteger matches = [regex numberOfMatchesInString:customResolution options:0 range:NSMakeRange(0, [customResolution length])];
        
        if (matches == 0) {
            error("Invalid resolution format! Must be WIDTHxHEIGHT (e.g. 1920x1080) - aborting\n");
            return 128;
        }
    }

    if (isScreenshotMode) {
        if ([self takeScreenshot:device filePath:filePath delaySeconds:delaySeconds]) {
            console("Screenshot saved to '%s'\n", [filePath UTF8String]);
            return 0;
        } else {
            error("Failed to take screenshot\n");
            return 1;
        }
    }

    // start capturing video, start a run loop
    if ([self startSession:device
              recordingDuration:recordingDuration
                    encodingPreset:encodingPreset
                        delaySeconds:delaySeconds
                                 noAudio:noAudio
                           customBitrate:customBitrate
                        customResolution:customResolution
                       fitWithoutCropping:fitWithoutCropping]) {

        if(recordingDuration != nil) {
            console("Started capture...\n");
        } else {
            console("Started capture (ctrl+c to stop, ctrl+z to pause) ...\n");
        }
        [[NSRunLoop currentRunLoop] run];
    } else {
        error("Could not initiate a VideoSnap capture\n");
    }
    return 0;
}

/*
 * Discover all video/muxed capture devices
 */
- (void)discoverDevices {
    verbose("(discovering devices)\n");
    connectedDevices = [NSMutableArray array];
    [self enableScreenCaptureWithDAL];

    if (@available(macOS 10.15, *)) {
        AVCaptureDeviceDiscoverySession *discoverySession = [
                AVCaptureDeviceDiscoverySession
                discoverySessionWithDeviceTypes:
                    @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeExternalUnknown]
                mediaType:NULL
                position:AVCaptureDevicePositionUnspecified
            ];
        for (AVCaptureDevice *device in discoverySession.devices) {
          if([device hasMediaType:AVMediaTypeMuxed] || [device hasMediaType:AVMediaTypeVideo]) {
            [connectedDevices addObject: device];
          }
        }
    } else {
        [connectedDevices addObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]];
        [connectedDevices addObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeMuxed]];
    }
}

/**
 * Enable connected devices for ScreenCapture through CoreMedia DAL (Device Abstraction Layer)
 */
- (void)enableScreenCaptureWithDAL {
    verbose("(opting in for connected DAL devices, may delay or fail when connecting to DAL assistant port)\n");

    Boolean isSettable = false;
    UInt32 isAllowed;
    CMIOObjectPropertyAddress prop = {
        kCMIOHardwarePropertyAllowScreenCaptureDevices,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMaster
    };

    CMIOObjectIsPropertySettable(kCMIOObjectSystemObject, &prop, &isSettable);

    if(isSettable) {
        CMIOObjectGetPropertyData(kCMIOObjectSystemObject, &prop, 0, NULL, sizeof(UInt32), &isAllowed, &isAllowed);
        if(isAllowed != 1) {
            verbose("(opting in for screen capture devices)\n");
            UInt32 allow = 1;
            CMIOObjectSetPropertyData(kCMIOObjectSystemObject, &prop, 0, NULL, sizeof(UInt32), &allow);
            verbose("(waiting 2 secs for devices to connect to DAL assistant)\n");
            [[NSRunLoop currentRunLoop] runUntilDate:[[[NSDate alloc] init] dateByAddingTimeInterval: 2]];
        }
    } else {
        verbose("(Can't opt-in for screen capture devices)\n");
    }
}

/**
 * List all connected devices by name to stdout
 */
- (void)listConnectedDevices {
    unsigned long deviceCount = [connectedDevices count];
	if (deviceCount > 0) {
		console("Found %li connected video devices:\n", deviceCount);
		for (AVCaptureDevice *device in connectedDevices) {
			console("* %s\n", [[device localizedName] UTF8String]);
		}
	} else {
		console("No video devices found.\n");
	}
}

- (NSString *)defaultGeneratedFilename {
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HHmmss"];

    return [@[@"movie-", [dateFormatter stringFromDate:[NSDate date]], @".mov"] componentsJoinedByString:@""];
 }

/**
 * Returns the default device (first found) or nil if none found
 */
- (AVCaptureDevice *)defaultDevice {
  return [connectedDevices firstObject];
}

/**
 * Returns a device matching on localizedName or nil if not found
 */
- (AVCaptureDevice *)deviceNamed:(NSString *)name {
  AVCaptureDevice *device = nil;
  for (AVCaptureDevice *thisDevice in connectedDevices) {
    if ([name isEqualToString:[thisDevice localizedName]]) {
      device = thisDevice;
    }
  }

  return device;
}

/**
 * Checks if the specified dimensions are supported by the device
 */
- (BOOL)isResolutionSupported:(AVCaptureDevice *)device width:(int)width height:(int)height {
    BOOL supported = NO;
    
    // Check if the device supports the requested resolution
    for (AVCaptureDeviceFormat *format in [device formats]) {
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        
        if (dimensions.width >= width && dimensions.height >= height) {
            verbose("(device supports resolution %dx%d - found format with %dx%d)\n", 
                    width, height, dimensions.width, dimensions.height);
            supported = YES;
            break;
        }
    }
    
    return supported;
}

/**
 * Start a capture session on a device, saving to filePath for recordSeconds
 */
- (BOOL)startSession:(AVCaptureDevice *)videoDevice
   recordingDuration:(NSNumber *)recordingDuration
			encodingPreset:(NSString *)encodingPreset
				delaySeconds:(NSNumber *)delaySeconds
             noAudio:(BOOL)noAudio
           customBitrate:(int)customBitrate
        customResolution:(NSString *)customResolution
       fitWithoutCropping:(BOOL)fitWithoutCropping {

  BOOL success = NO;
  NSError *nserror;

	// show options
	verbose("(options before recording)\n");
	verbose("  delay:    %.2fs\n",    [delaySeconds floatValue]);
	verbose("  duration: %.2fs\n",    [recordingDuration floatValue]);
	verbose("  file:     %s\n",       [filePath UTF8String]);
	
	if (customResolution != nil) {
		verbose("  video:    Custom (%s)\n", [customResolution UTF8String]);
		verbose("  bitrate:  %d bps\n",     customBitrate);
	} else {
		verbose("  video:    %s\n",       [encodingPreset UTF8String]);
	}
	
	verbose("  audio:    %s\n",       [noAudio ? @"(none)": @"HQ AAC" UTF8String]);
	verbose("  device:   %s\n",       [[videoDevice localizedName] UTF8String]);
	verbose("            %s - %s\n",  [[videoDevice modelID] UTF8String], [[videoDevice manufacturer] UTF8String]);

	// Check if custom resolution is supported
	if (customResolution != nil) {
		NSArray *dimensions = [customResolution componentsSeparatedByString:@"x"];
		int width = [[dimensions objectAtIndex:0] intValue];
		int height = [[dimensions objectAtIndex:1] intValue];
		
		// Log available formats for debugging
		verbose("(available device formats:)\n");
		for (AVCaptureDeviceFormat *format in [videoDevice formats]) {
			CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
			verbose("  %dx%d\n", dims.width, dims.height);
		}
		
		if (![self isResolutionSupported:videoDevice width:width height:height]) {
			verbose("(warning: requested resolution %dx%d may not be fully supported by this device)\n", 
					width, height);
		}
	}

	verbose("(initializing capture session)\n");
    session = [[AVCaptureSession alloc] init];

	// add video input
	verbose("(adding video device)\n");
	AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&nserror];

	if (videoInput) {
		if ([session canAddInput:videoInput]) {
			[session addInput:videoInput];
		} else {
			error("Could not add the video device to the session\n");
			return success;
		}

		// add audio input (unless noAudio)
		if (!noAudio) {
		  [self addAudioDevice:videoDevice];
		}

		verbose("(adding movie file output)\n");
		movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];

		// set capture frame rate (fps)
		int32_t fps = DEFAULT_FRAMES_PER_SECOND;
		verbose("(set capture framerate to %i fps)\n", fps);
		conn = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
		if([conn isVideoMinFrameDurationSupported]) {
			conn.videoMinFrameDuration = CMTimeMake(1, fps);
		}
		if([conn isVideoMaxFrameDurationSupported]) {
			conn.videoMaxFrameDuration = CMTimeMake(1, fps);
		}

		// set max duration and min free space in bytes before recording can start
		if(recordingDuration != nil) {
		  CMTime maxDuration = CMTimeMakeWithSeconds([recordingDuration floatValue], fps);
		  movieFileOutput.maxRecordedDuration = maxDuration;
	  }
		movieFileOutput.minFreeDiskSpaceLimit = 1024 * 1024;

		if ([session canAddOutput:movieFileOutput]) {
			[session addOutput:movieFileOutput];
		} else {
			error("Could not add file '%s' as output to the capture session\n", [filePath UTF8String]);
			return success;
		}
		
		// If noAudio is true and the device is muxed, try to disable the audio connection
		if (noAudio && ([videoDevice hasMediaType:AVMediaTypeMuxed] || [videoDevice hasMediaType:AVMediaTypeAudio])) {
			verbose("(attempting to disable audio for muxed device)\n");
			
			// Configure the session to handle audio settings
			[session beginConfiguration];
			
			// Find the audio connection and disable it if possible
			AVCaptureConnection *audioConnection = [movieFileOutput connectionWithMediaType:AVMediaTypeAudio];
			if (audioConnection && [audioConnection isEnabled]) {
				[audioConnection setEnabled:NO];
				verbose("(disabled audio connection)\n");
			} else {
				verbose("(couldn't find audio connection to disable)\n");
			}
			
			// Try to set audio recording settings to minimize the audio
			// Using minimum valid sample rate (8 kHz) and minimum bitrate
			NSDictionary *audioSettings = @{
				AVFormatIDKey: @(kAudioFormatMPEG4AAC),
				AVNumberOfChannelsKey: @(1),        // Mono
				AVSampleRateKey: @(8000.0),         // Minimum valid sample rate (8 kHz)
				AVEncoderBitRateKey: @(8000)        // Minimum bitrate (8 kbps)
			};
			
			// Apply audio settings to the movie file output
			if (audioConnection) {
				[movieFileOutput setOutputSettings:audioSettings forConnection:audioConnection];
				verbose("(applied minimal audio settings to effectively mute audio)\n");
			}
			
			[session commitConfiguration];
		}

		// Set session preset based on whether custom resolution is specified
		if (customResolution == nil) {
			verbose("(setting encoding preset)\n");
			NSString *capturePreset = [NSString stringWithFormat:@"AVCaptureSessionPreset%@", encodingPreset];
			if ([session canSetSessionPreset:capturePreset]) {
				[session setSessionPreset:capturePreset];
			} else {
				verbose("(could not set encoding preset '%s' for this device, defaulting to Medium)\n", [encodingPreset UTF8String]);
				[session setSessionPreset:AVCaptureSessionPresetMedium];
			}
		} else {
			verbose("(setting custom resolution and bitrate)\n");
			
			// Parse width and height from custom resolution
			NSArray *dimensions = [customResolution componentsSeparatedByString:@"x"];
			int width = [[dimensions objectAtIndex:0] intValue];
			int height = [[dimensions objectAtIndex:1] intValue];
			
			// For custom resolution, we need to be more specific about the format
			verbose("(set custom resolution to %dx%d and bitrate to %d bps)\n", width, height, customBitrate);
			
			// First start with the high preset to get the best quality base format
			[session setSessionPreset:AVCaptureSessionPresetHigh];
			
			// Configure the actual compression settings for output
			[session beginConfiguration];
			
			// Choose scaling mode based on user preference
			NSString *scalingMode = fitWithoutCropping ? 
				AVVideoScalingModeResizeAspect : AVVideoScalingModeResizeAspectFill;
			verbose("(using scaling mode: %s)\n", fitWithoutCropping ? "fit without cropping" : "fill and crop");
			
			// Create a dictionary of compression settings for the video
			NSMutableDictionary *compressionProperties = [@{
				AVVideoAverageBitRateKey: @(customBitrate),
				AVVideoMaxKeyFrameIntervalKey: @(60),  // Keyframe every 60 frames for better compression
				AVVideoAllowFrameReorderingKey: @YES  // Enable frame reordering for better compression
			} mutableCopy];
			
			// Set the format description dictionary
			NSDictionary *videoSettings = @{
				AVVideoCodecKey: AVVideoCodecTypeHEVC,  // Use HEVC codec
				AVVideoWidthKey: @(width),
				AVVideoHeightKey: @(height),
				AVVideoCompressionPropertiesKey: compressionProperties,
				AVVideoScalingModeKey: scalingMode
			};
			
			// We need to get the connection after adding the output to the session
			AVCaptureConnection *videoConnection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
			
			// Apply the settings to the movie file output
			if (videoConnection) {
				// Set video orientation if needed
				if ([videoConnection isVideoOrientationSupported]) {
					[videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
				}
				
				// Apply settings directly to the connection's output
				[movieFileOutput setOutputSettings:videoSettings forConnection:videoConnection];
				
				// Verify that our settings will be applied
				NSDictionary *actualSettings = [movieFileOutput outputSettingsForConnection:videoConnection];
				if (actualSettings) {
					verbose("(confirmed output settings: %s)\n", [actualSettings description].UTF8String);
				} else {
					verbose("(warning: could not confirm output settings)\n");
				}
			}
			
			[session commitConfiguration];
		}

		// delete the target file if it exists
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if([fileManager fileExistsAtPath:filePath]) {
			verbose("(file at '%s' exists, deleting it)\n", [filePath UTF8String]);
			NSError *fileError = nil;

			if (![fileManager removeItemAtPath:filePath error:&fileError]) {
				error("File '%s' exists, and could not be deleted\n", [filePath UTF8String]);
				verbose_error("%s\n", [[fileError localizedDescription] UTF8String]);
				return success;
			}
		}

		// start capture session running
		verbose("(starting capture session)\n");
		[session startRunning];
		if (![session isRunning]) {
			error("Could not start the capture session\n");
			return success;
		}

		// start delay if present
		if ([delaySeconds floatValue] <= 0.0f) {
			verbose("(no delay)\n");
		} else {
			verbose("(delaying for %.2lf seconds)\n", [delaySeconds doubleValue]);
			[[NSRunLoop currentRunLoop] runUntilDate:[[[NSDate alloc] init] dateByAddingTimeInterval: [delaySeconds doubleValue]]];
			verbose("(delay period ended)\n");
		}

		verbose("(starting capture to file at '%s')\n", [filePath UTF8String]);
		[movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:filePath] recordingDelegate:self];
		success = YES;

	} else {
		error("Video device is not connected or available\n");
		verbose_error("%s\n", [[nserror localizedDescription] UTF8String]);
  }

  return success;
}

/**
  * Toggle pause/resume recording to the file
  */
- (void)togglePauseRecording:(int)sigNum {
    verbose("\n(caught signal: [%d])\n", sigNum);
    
    if([movieFileOutput isRecordingPaused]) {
        fprintf(stderr, "\nResuming capture ...\n");
        [movieFileOutput resumeRecording];
    } else {
        fprintf(stderr, "\nPausing capture ... (ctrl+z to resume, ctrl+c to stop)\n");
        [movieFileOutput pauseRecording];
    }
}

/**
 * Adds an audio device to the capture session, from video device or first available
 */
- (BOOL)addAudioDevice:(AVCaptureDevice *)videoDevice {
  BOOL success = NO;
  NSError *nserror;

  verbose("(adding audio device)\n");

  // if the video device doesn't supply audio, add a default audio device (if possible)
  // Note: Muxed devices (like iOS devices) already include audio, so we don't need to add an audio device
  if (![videoDevice hasMediaType:AVMediaTypeAudio] && ![videoDevice hasMediaType:AVMediaTypeMuxed]) {
		AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&nserror];

		if (audioInput) {
			if ([session canAddInput:audioInput]) {
				[session addInput:audioInput];
				success = YES;
			} else {
				error("Could not add the audio device to the session\n");
			}
		} else {
			error("Audio device is not connected or available\n");
			verbose_error("%s\n", [[nserror localizedDescription] UTF8String]);
		}
  } else {
    // For devices that provide audio themselves (muxed or with AVMediaTypeAudio), consider it a success
    verbose("(device already provides audio, no separate audio device needed)\n");
    success = YES;
  }

	return success;
}

/**
 * Are we are recording or not?
 */
- (BOOL)isRecording {
	return [movieFileOutput isRecording];
}

/**
 * Stop recording to the file
 */
- (void)stopRecording:(int)sigNum {
	verbose("\n(caught signal: [%d])\n", sigNum);
	if([movieFileOutput isRecording]) {
		verbose("(stopping recording)\n");
		[movieFileOutput stopRecording];
	}
}

/**
 * Called when output file has been written to
 */
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
			fromConnections:(NSArray *)connections
								error:(NSError *)error {

	verbose("(finished writing to movie file)\n");
	BOOL captureSuccessful = YES;

	// check if a problem occurred, to see if recording was successful
	if ([error code] != noErr) {
		id value = [[error userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey];
		if (value) {
			captureSuccessful = [value boolValue];
		}
	}

	// call a to stop the session
	verbose("(stopping capture session)\n");
	[session stopRunning];

	if(captureSuccessful) {
		NSNumber *outputDuration = [NSNumber numberWithFloat: CMTimeGetSeconds([movieFileOutput recordedDuration])];
		console("\nCaptured %.2f seconds of video to '%s'\n", [outputDuration floatValue], [[outputFileURL lastPathComponent] UTF8String]);
		exit(0);
	} else {
		error("\nFailed to capture any video\n");
		verbose_error("(reason: %s)\n", [[error localizedDescription] UTF8String]);
		exit(1);
	}
}

- (BOOL)takeScreenshot:(AVCaptureDevice *)device filePath:(NSString *)filePath delaySeconds:(NSNumber *)delaySeconds {
    NSError *nserror;
    
    verbose("(initializing capture session for screenshot)\n");
    session = [[AVCaptureSession alloc] init];
    
    // Add video input
    verbose("(adding video device)\n");
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&nserror];
    
    if (videoInput) {
        if ([session canAddInput:videoInput]) {
            [session addInput:videoInput];
            
            // Configure photo output
            photoOutput = [[AVCapturePhotoOutput alloc] init];
            if ([session canAddOutput:photoOutput]) {
                [session addOutput:photoOutput];
                
                // Start capture session
                verbose("(starting capture session)\n");
                [session startRunning];
                
                if ([session isRunning]) {
                    // Apply delay if specified
                    if ([delaySeconds floatValue] > 0.0f) {
                        verbose("(delaying for %.2lf seconds)\n", [delaySeconds doubleValue]);
                        [[NSRunLoop currentRunLoop] runUntilDate:[[[NSDate alloc] init] dateByAddingTimeInterval:[delaySeconds doubleValue]]];
                        verbose("(delay period ended)\n");
                    }
                    
                    // Take the photo
                    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
                    [photoOutput capturePhotoWithSettings:settings delegate:self];
                    
                    // Run the run loop until the delegate calls exit()
                    [[NSRunLoop currentRunLoop] run];
                } else {
                    error("Could not start the capture session\n");
                }
            } else {
                error("Could not add photo output to the session\n");
            }
        } else {
            error("Could not add the video device to the session\n");
        }
    } else {
        error("Video device is not connected or available\n");
        verbose_error("%s\n", [[nserror localizedDescription] UTF8String]);
    }
    
    return NO; // Will not reach here, but required by signature
}

// AVCapturePhotoCaptureDelegate method
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (error) {
        error("Error capturing photo: %s\n", [[error localizedDescription] UTF8String]);
        return;
    }
    
    NSData *imageData = [photo fileDataRepresentation];
    if ([imageData writeToFile:filePath atomically:YES]) {
        [session stopRunning];
        exit(0);  // Exit successfully
    } else {
        error("Failed to save screenshot to file\n");
        [session stopRunning];
        exit(1);  // Exit with error
    }
}

@end
