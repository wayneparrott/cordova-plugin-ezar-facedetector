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
   
}

// INIT PLUGIN - does nothing atm
- (void) pluginInitialize
{
    [super pluginInitialize];
}

- (void) start:(CDVInvokedUrlCommand*)command
{
   CDVPluginResult* result = nil;
   
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool: YES];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
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
    CDVPluginResult* result = nil;
   
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool: NO];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

michel
2.4533400 x101


//----------------------------------------------------------------
- (UIImageView *) getCameraView
{
    UIImageView* cameraView = (UIImageView *)[self.viewController.view viewWithTag: EZAR_CAMERA_VIEW_TAG];
    return cameraView;
}

- (BOOL) isVideoOverlayAvailable
{
    return [self getCameraView] == nil;
}

-(BOOL) isCameraRunning
{
    MainViewController *ctrl = (MainViewController *)self.viewController;
    CDVPlugin* videoOverlayPlugin = [ctrl.pluginObjects objectForKey:@"CDVezARVideoOverlay"];
    
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
