/**
 * CDVezARFaceDetector.h
 *
 * Copyright 2016, ezAR Technologies
 * http://ezartech.com
 *
 * By @wayne_parrott
 *
 * Licensed under a modified MIT license. 
 * Please see LICENSE or http://ezartech.com/ezarstartupkit-license for more information
 */

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "Cordova/CDV.h"

/**
 * Implements the ezAR Cordova api. 
 */
@interface CDVezARFaceDetector : CDVPlugin <AVCaptureVideoDataOutputSampleBufferDelegate>

- (void) start:(CDVInvokedUrlCommand*)command;
- (void) stop:(CDVInvokedUrlCommand*)command;
- (void) update:(CDVInvokedUrlCommand*)command;

@end



