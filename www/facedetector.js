/**
 * ezar.js
 * Copyright 2015, ezAR Technologies
 * Licensed under a modified MIT license, see LICENSE or http://ezartech.com/ezarstartupkit-license
 * 
 * @file Implements the ezar api for controlling device cameras, 
 *  zoom level and lighting. 
 * @author @wayne_parrott, @vridosh, @kwparrott
 * @version 0.1.0 
 */

var exec = require('cordova/exec'),
    argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    FaceInfo = require('./FaceInfo');

module.exports = (function() {

    var running = false;

	 //--------------------------------------
    var _facedetector = {};

    _facedetector.isRunning = function() { return running; };

    /**
     * Start face detection with callback
     *
     *
     */
    
    _facedetector.watchFaces = function(successCallback,errorCallback) {
       //test for videoOverlay plugin installed
       if (!window.ezar || !window.ezar.initializeVideoOverlay) {
           //error the videoOverlay plugin is not installed
           if (errorCallback && typeof(errorCallback) === 'function') {
               errorCallback('Required VideoOverlay plugin not present');
           }
           return;
       }

        var onSuccess = function(faces) {
            running = true;
            if (successCallback) {
                  successCallback(faces);
            }
        };
                  
        exec(onSuccess,
             errorCallback,
             "facedetector",
             "start",
             [window.innerWidth, window.innerHeight]);
    }
               
    
     _facedetector.clearFacesWatch = function(successCallback,errorCallback) {

        var onSuccess = function() {
            running = false;
            if (successCallback) {
                  successCallback();
            }
        };

        exec(onSuccess,
             errorCallback,
             "facedetector",
             "stop",
             []);

    }
    
    //hack - orientation changed, send new window dims to native code
    //       todo: replace with native orientation detection 
    function update() {
        setTimeout(
            function() {
                exec(null,
                    null,
                    "facedetector",
                    "update",
                    [window.innerWidth, window.innerHeight]);
            },1500);
    }
    
    window.addEventListener('orientationchange',update);

    
    return _facedetector;
    
}());
