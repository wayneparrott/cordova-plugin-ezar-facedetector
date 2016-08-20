/*
 * CDVezARSnapshot.m
 *
 * Copyright 2016, ezAR Technologies
 * http://ezartech.com
 *
 * By @wayne_parrott
 *
 * Licensed under a modified MIT license. 
 * Please see LICENSE or http://ezartech.com/ezarstartupkit-license for more information
 *
 */
 
#import "CDVezARFaceDetector.h"
#import "MainViewController.h"


@implementation CDVezARFaceDetector
{
   NSString *callbackId;
   AVCaptureVideoDataOutput *videoDataOutput;
   dispatch_queue_t videoDataOutputQueue;
   CIDetector *faceDetector;
   NSUInteger faceCount;
   
   double browserWidth, browserHt;
   CGFloat nativeScale;
}

// INIT PLUGIN - does nothing atm
- (void) pluginInitialize
{
    [super pluginInitialize];
    
    NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyHigh, CIDetectorAccuracy, nil];
    //NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
    faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
}

- (void) start:(CDVInvokedUrlCommand*)command
{
    UIImageView *camView = [self getCameraView];
    //CGRect bnds = [x bounds];
    //CGFloat cntScale = x.contentScaleFactor;
    //CGFloat nativeScale = x.window.screen.nativeScale;
    nativeScale = camView.window.screen.scale;
    
    callbackId = command.callbackId;
    browserWidth = [[command.arguments objectAtIndex: 0] doubleValue];
    browserHt = [[command.arguments objectAtIndex: 1] doubleValue];
   
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                           [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setVideoSettings:rgbOutputSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue: videoDataOutputQueue];
    if ( [[self getAVCaptureSession] canAddOutput:videoDataOutput] ){
        [[self getAVCaptureSession] addOutput:videoDataOutput];
    }
       
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
   
    //CDVPluginResult* result = nil;
    //result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    //[result setKeepCallbackAsBool: YES];
    //[self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void) stop:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* result = nil;
   
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool: NO];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void) update:(CDVInvokedUrlCommand*)command
{
    browserWidth = [[command.arguments objectAtIndex: 0] doubleValue];
    browserHt = [[command.arguments objectAtIndex: 1] doubleValue];
    
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool: NO];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer];
    
	// make sure your device orientation is not locked.
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
	NSDictionary *imageOptions = 
        [NSDictionary dictionaryWithObject:[self exifOrientation:curDeviceOrientation] 
                      forKey:CIDetectorImageOrientation];
    
    //detect faces    
	NSArray *features = [faceDetector featuresInImage:ciImage
                                      options:imageOptions];
    
    if ([features count] > 0 || faceCount > 0) {
        faceCount = [features count];
        
	    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	    CGRect cleanAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc, false);
	
	    dispatch_async(dispatch_get_main_queue(), ^(void) {
		    //[self drawFaces:features forVideoBox:cleanAperture];
            
            NSLog(@"faces: %lu", (unsigned long)faceCount);
            
            UIView* wv = self.webView;
            CGRect wvBnds = wv.bounds;
            //CGFloat widthScaleBy = browserWidth / wvBnds.size.height / nativeScale;
            //CGFloat heightScaleBy = browserHt / wvBnds.size.width / nativeScale;
            CGFloat widthScaleBy = 1.0 / nativeScale;
            CGFloat heightScaleBy = 1.0 / nativeScale;
            
            NSMutableArray *faces = [NSMutableArray arrayWithCapacity:faceCount];
            for (int i=0; i < faceCount; i++) {
                // find the correct position for the square layer within the previewLayer
                // the feature box originates in the bottom left of the video frame.
                // (Bottom right if mirroring is turned on)
                CGRect faceRect = [[features objectAtIndex: i] bounds];
                
                // flip preview width and height
                
                 CGFloat temp = faceRect.size.width;
                faceRect.size.width = faceRect.size.height;
                faceRect.size.height = temp;
                temp = faceRect.origin.x;
                faceRect.origin.x = faceRect.origin.y;
                faceRect.origin.y = temp;
                
                
                // scale coordinates so they fit in the webview browser coords
                faceRect.size.width *= widthScaleBy;
                faceRect.size.height *= heightScaleBy;
                faceRect.origin.x *= widthScaleBy;
                faceRect.origin.y *= heightScaleBy;
        
                /*
                if ( isMirrored )
                    faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
                else
                    faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
                */    
            
                //build faceinfo array 
                NSDictionary *faceinfo =
                    [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInteger: faceRect.origin.x], @"left",
                        [NSNumber numberWithInteger: faceRect.origin.y], @"top",
                        [NSNumber numberWithInteger: faceRect.origin.x + faceRect.size.width], @"right",
                        [NSNumber numberWithInteger: faceRect.origin.y + faceRect.size.height], @"bottom",
                        nil];
                                                         
                [faces addObject:faceinfo];
            }
            
            //return to cordova
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:faces];
            [result setKeepCallbackAsBool: YES];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    
	    });
    }
}

- (NSNumber *) exifOrientation: (UIDeviceOrientation) orientation
{
	int exifOrientation;
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants. 
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
	enum {
		PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
		PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.  
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.  
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.  
		PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.  
		PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.  
		PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.  
		PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.  
	};
	
	switch (orientation) {
		case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
			break;
		case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
			if ([self isFrontCameraRunning])
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			if ([self isFrontCameraRunning])
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
    return [NSNumber numberWithInt:exifOrientation];
}

//----------------------------------------------------------------
-(CDVPlugin*)getVideoOverlayPlugin
{
    MainViewController *ctrl = (MainViewController *)self.viewController;
    CDVPlugin* videoOverlayPlugin = [ctrl.pluginObjects objectForKey:@"CDVezARVideoOverlay"];
    return videoOverlayPlugin;
}

-(BOOL) hasVideoOverlayPlugin
{
    return !![self getVideoOverlayPlugin];
}


-(BOOL) isCameraRunning
{
    CDVPlugin* videoOverlayPlugin = [self getVideoOverlayPlugin];
    BOOL result = NO;
    
    if (!videoOverlayPlugin) {
        return result;
    }
    
    // Find AVCaptureSession
    NSString* methodName = @"isCameraRunning";
    SEL selector = NSSelectorFromString(methodName);
    result = (BOOL)[videoOverlayPlugin performSelector:selector];
    
    return result;
}

-(BOOL) isFrontCameraRunning
{
    CDVPlugin* videoOverlayPlugin = [self getVideoOverlayPlugin];
    BOOL result = NO;
    
    if (!videoOverlayPlugin) {
        return result;
    }
    
    // Find AVCaptureSession
    NSString* methodName = @"isFrontCameraRunning";
    SEL selector = NSSelectorFromString(methodName);
    result = (BOOL)[videoOverlayPlugin performSelector:selector];
    
    return result;
}

-(BOOL) isBackCameraRunning
{
    CDVPlugin* videoOverlayPlugin = [self getVideoOverlayPlugin];
    BOOL result = NO;
    
    if (!videoOverlayPlugin) {
        return result;
    }
    
    // Find AVCaptureSession
    NSString* methodName = @"isBackCameraRunning";
    SEL selector = NSSelectorFromString(methodName);
    result = (BOOL)[videoOverlayPlugin performSelector:selector];
    
    return result;
}

- (AVCaptureSession *) getAVCaptureSession
{
    CDVPlugin* videoOverlayPlugin = [self getVideoOverlayPlugin];
    
    if (!videoOverlayPlugin) {
        return nil;
    }
    
    NSString* methodName = @"getAVCaptureSession";
    SEL selector = NSSelectorFromString(methodName);
    AVCaptureSession *session =
        (AVCaptureSession *)[videoOverlayPlugin performSelector:selector];
    
    return session;
}

- (UIImageView *) getCameraView
{
    CDVPlugin* videoOverlayPlugin = [self getVideoOverlayPlugin];
    
    if (!videoOverlayPlugin) {
        return nil;
    }
    
    NSString* methodName = @"getCameraView";
    SEL selector = NSSelectorFromString(methodName);
    UIImageView *cameraView =
        (UIImageView *)[videoOverlayPlugin performSelector:selector];
    
    return cameraView;
}

//------------------------------------------------------------------------------------------------------


typedef NS_ENUM(NSUInteger, EZAR_ERROR_CODE) {
    EZAR_ERROR_CODE_ERROR=1,
    EZAR_ERROR_CODE_INVALID_ARGUMENT,
    EZAR_ERROR_CODE_INVALID_STATE,
    EZAR_ERROR_CODE_ACTIVATION
};

//
//
//
- (NSDictionary*)makeErrorResult: (EZAR_ERROR_CODE) errorCode withData: (NSString*) description
{
    NSMutableDictionary* errorData = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [errorData setObject: @(errorCode)  forKey:@"code"];
    [errorData setObject: @{ @"description": description}  forKey:@"data"];
    
    return errorData;
}

//
//
//
- (NSDictionary*)makeErrorResult: (EZAR_ERROR_CODE) errorCode withError: (NSError*) error
{
    NSMutableDictionary* errorData = [NSMutableDictionary dictionaryWithCapacity:2];
    [errorData setObject: @(errorCode)  forKey:@"code"];
    
    NSMutableDictionary* data = [NSMutableDictionary dictionaryWithCapacity:2];
    [data setObject: [error.userInfo objectForKey: NSLocalizedFailureReasonErrorKey] forKey:@"description"];
    [data setObject: @(error.code) forKey:@"iosErrorCode"];
    
    [errorData setObject: data  forKey:@"data"];
    
    return errorData;
}

@end
