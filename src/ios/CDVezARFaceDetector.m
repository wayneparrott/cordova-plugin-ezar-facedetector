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
   BOOL isInitialized;
   NSString *callbackId;
   AVCaptureVideoDataOutput *videoDataOutput;
   dispatch_queue_t videoDataOutputQueue;
   CIDetector *faceDetector;
   int faceCount;
   
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

    //CGFloat cntScale = x.contentScaleFactor;
    //CGFloat nativeScale = x.window.screen.nativeScale;
    nativeScale = camView.window.screen.scale;
    
    callbackId = command.callbackId;
    browserWidth = [[command.arguments objectAtIndex: 0] doubleValue];
    browserHt = [[command.arguments objectAtIndex: 1] doubleValue];
   
    if (videoDataOutput == nil) {
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
    }
    
    if (!videoDataOutput) {
        [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    } else {
        //todo: return setup error occured
    }
    
    //CDVPluginResult* result = nil;
    //result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    //[result setKeepCallbackAsBool: YES];
    //[self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void) stop:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* result = nil;
    
    if (videoDataOutput) {
        [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
    }
    
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool: NO];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

//todo reimplement to detect device rotation events rather than a call from the plugin js interface
//update: is a hack mechanism for updating state on device rotation
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
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    if (attachments) {
        CFRelease(attachments);
    }
    
    //int height = CVPixelBufferGetHeight(pixelBuffer);
    //CGAffineTransform transform = CGAffineTransformMakeScale(1.0/nativeScale, -1.0/nativeScale);
    //transform = CGAffineTransformTranslate(transform, 0, -1 * height);
    
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
	    CGRect clearAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc, false);
	
	    dispatch_async(dispatch_get_main_queue(), ^(void) {

            //NSLog(@"faces: %lu", (unsigned long)faceCount);
            
            //UIView* wv = self.webView;
            //CGRect wvBnds = wv.bounds;
            //CGFloat widthScaleBy = browserWidth / wvBnds.size.height / nativeScale;
            //CGFloat heightScaleBy = browserHt / wvBnds.size.width / nativeScale;
            //CGFloat widthScaleBy = 1.0 / nativeScale;
            //CGFloat heightScaleBy = 1.0 / nativeScale;
            
            //https://github.com/jeroentrappers/FaceDetectionPOC/blob/master/FaceDetectionPOC/ViewController.m
            CGSize parentFrameSize = [[self getCameraView] frame].size;
            NSString *gravity = AVLayerVideoGravityResizeAspectFill;
            BOOL isMirrored = [self isFrontCameraRunning];
            CGRect previewBox = [self videoPreviewBoxForGravity:gravity
                                                      frameSize:parentFrameSize
                                                   apertureSize:clearAperture.size];
            
            NSMutableArray *faces = [NSMutableArray arrayWithCapacity:faceCount];
            for (int i=0; i < faceCount; i++) {
                // find the correct position for the square layer within the previewLayer
                // the feature box originates in the bottom left of the video frame.
                // (Bottom right if mirroring is turned on)
                CGRect faceRect = [[features objectAtIndex: i] bounds];
                
                //faceRect = CGRectApplyAffineTransform(faceRect, transform);
                
                //NSLog(@"face1 x/y: %lu %lu %lu %lu", (unsigned long)faceRect.origin.x,(unsigned long)faceRect.origin.y,
                //      (unsigned long)faceRect.size.width, (unsigned long)faceRect.size.height);
                
                // flip preview width and height
                CGFloat temp = faceRect.size.width;
                faceRect.size.width = faceRect.size.height;
                faceRect.size.height = temp;
                temp = faceRect.origin.x;
                faceRect.origin.x = faceRect.origin.y;
                faceRect.origin.y = temp;
                
                // scale coordinates so they fit in the preview box, which may be scaled
                CGFloat widthScaleBy = previewBox.size.width / clearAperture.size.height;
                CGFloat heightScaleBy = previewBox.size.height / clearAperture.size.width;
                faceRect.size.width *= widthScaleBy;
                faceRect.size.height *= heightScaleBy;
                faceRect.origin.x *= widthScaleBy;
                faceRect.origin.y *= heightScaleBy ;
                
                if ( isMirrored )
                    faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
                else
                    faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
                
                //NSLog(@"face2 x/y: %lu %lu %lu %lu", (unsigned long)faceRect.origin.x,(unsigned long)faceRect.origin.y,
                //      (unsigned long)faceRect.size.width, (unsigned long)faceRect.size.height);
                
            
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

// find where the video box is positioned within the preview layer based on the video size and gravity
- (CGRect)videoPreviewBoxForGravity:(NSString *)gravity
                          frameSize:(CGSize)frameSize
                       apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
    
    CGRect videoBox;
    videoBox.size = size;
    if (size.width < frameSize.width)
        videoBox.origin.x = (frameSize.width - size.width) / 2;
    else
        videoBox.origin.x = (size.width - frameSize.width) / 2;
    
    if ( size.height < frameSize.height )
        videoBox.origin.y = (frameSize.height - size.height) / 2;
    else
        videoBox.origin.y = (size.height - frameSize.height) / 2;
    
    return videoBox;
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
