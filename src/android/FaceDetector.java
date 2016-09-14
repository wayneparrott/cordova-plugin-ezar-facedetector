package com.ezartech.ezar.facedetector;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Bitmap.CompressFormat;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Point;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.RectF;
import android.hardware.Camera;
import android.hardware.SensorManager;
import android.media.MediaActionSound;
import android.provider.MediaStore;
import android.util.Base64;
import android.util.Log;
import android.view.Display;
import android.view.OrientationEventListener;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.webkit.WebView;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

/**
 * Created by Zirk on 2/5/2016.
 */
public class FaceDetector extends CordovaPlugin implements Camera.FaceDetectionListener {
	private static final String TAG = "FaceDetector";
    static final int UNDEFINED  = -1;

    private CallbackContext callbackContext;

    private View webViewView;
	private int voCameraId;           //updated by VO start/stop events
    private Camera voCamera;          //updated by VO start/stop events
    private int voCameraDir;          //updated by VO start/stop events
    private int browserWidth, browserHt;

    //code adapted from http://bytefish.de/blog/face_detection_with_android/

	@Override
	public void initialize(final CordovaInterface cordova, final CordovaWebView cvWebView) {
		super.initialize(cordova, cvWebView);
        webViewView = cvWebView.getView();
        webViewView = cvWebView.getView();
	}


    @Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		Log.v(TAG, action + " " + args.length());

		if (action.equals("start")) {
            browserWidth = args.getInt(0);
            browserHt = args.getInt(1);
			this.startFaceDetection(callbackContext);
		} else if (action.equals("stop")) {
            this.stopFaceDetection(callbackContext);
        } else if (action.equals("update")) {
            browserWidth = args.getInt(0);
            browserHt = args.getInt(1);
            callbackContext.success();
        } else {
		    return false;
        }
        
        PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT, "");
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);
        return true;
	}
    
    private void startFaceDetection(CallbackContext callbackContext) {
		Log.d(TAG, "startFaceDetection");

        this.callbackContext = callbackContext;
        if (callbackContext == null) return;
        
		if (getActiveVOCamera() == null) {
			//no camera running, return error; this should be handled already as precondition in javascript api
            //callbackContext.error("Required VideoOverlay plugin not present");
            return;
		}

        voCameraDir = getActiveCameraDirection();
        voCameraId = getActiveVOCameraId();
		voCamera = getActiveVOCamera();
        int maxDetectedFaces =  voCamera.getParameters().getMaxNumDetectedFaces();
        Log.d(TAG,"MAX DETECTED FACES" + maxDetectedFaces);
        if (maxDetectedFaces < 1) {
            callbackContext.error("Face detection is not supported on this device");
            return;
        }

        voCamera.setFaceDetectionListener(this);
        voCamera.startFaceDetection();
	}
    
    private void stopFaceDetection(CallbackContext callbackContext) {
		Log.d(TAG, "stopFaceDetection");

        if (voCamera != null) {
           try {
               voCamera.stopFaceDetection();
               voCamera.setFaceDetectionListener(null);
           } catch(Exception ex) {
               //do nothing
           }
        }

        if (voCamera != null) {
            voCamera = null;
            voCameraId = -1;
            voCameraDir = UNDEFINED;
        }

        if (callbackContext != null) {
            this.callbackContext = null;
            callbackContext.success();
        }
	}

    @Override
    public void onFaceDetection(Camera.Face[] faces, Camera camera) {

        if (callbackContext == null) {
            Log.d(TAG, "No callback context");
            return;
        }

        Log.d(TAG, "Faces Detected = " + faces.length);

        Matrix matrix = new Matrix();

        // Need mirror for front camera.
        boolean mirror = (voCameraDir == Camera.CameraInfo.CAMERA_FACING_FRONT);
        matrix.setScale(mirror ? -1 : 1, 1);
        // This is the value for android.hardware.Camera.setDisplayOrientation.
        matrix.postRotate(getDisplayOrientation());
        // Camera driver coordinates range from (-1000, -1000) to (1000, 1000).
        // UI coordinates range from (0, 0) to (width, height).
        matrix.postScale(browserWidth / 2000f, browserHt / 2000f);
        matrix.postTranslate(browserWidth / 2f, browserHt / 2f);
        // matrix.postScale(webViewView.getWidth() / 2000f, webViewView.getHeight() / 2000f);
        // matrix.postTranslate(webViewView.getWidth() / 2f, webViewView.getHeight() / 2f);

        JSONArray faceRects = new JSONArray();
        RectF rectF = new RectF();
        try {
            for (Camera.Face face : faces) {

                rectF.set(face.rect);
                matrix.mapRect(rectF);

                JSONObject jsonFace = new JSONObject();
                jsonFace.put("left", (int) rectF.left);
                jsonFace.put("top", (int) rectF.top);
                jsonFace.put("right", (int) rectF.right);
                jsonFace.put("bottom", (int) rectF.bottom);
                Log.d(TAG, "face rect: " + jsonFace);

               /*
                float[] pts = new float[] {face.leftEye.x, face.leftEye.y,
                                           face.rightEye.x, face.rightEye.y,
                                           face.mouth.x, face.mouth.y};
                matrix.mapPoints(pts);
                jsonFace.put("leftEyeX",  (int) pts[0]);
                jsonFace.put("leftEyeY",  (int) pts[1]);
                jsonFace.put("rightEyeX", (int) pts[2]);
                jsonFace.put("rightEyeY", (int) pts[3]);
                jsonFace.put("mouthX",    (int) pts[4]);
                jsonFace.put("mouthY",    (int) pts[5]);
                Log.d(TAG, "left-eye: "  + pts[0] + "," + pts[1] +
                           " right-eye: "+ pts[2] + "," + pts[3] +
                           " mouth: "    + pts[4] + "," + pts[5]);
                */
                
                faceRects.put(jsonFace);
            }
        } catch(JSONException ex) {
            Log.e(TAG, "Error returning FaceInfo: ", ex);
        }

        PluginResult result = new PluginResult(PluginResult.Status.OK, faceRects);
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);        
    }
    
    // Sends an error back to JS
    private void fail(String msg) {
        PluginResult err = new PluginResult(PluginResult.Status.ERROR, msg);
        err.setKeepCallback(true);
        callbackContext.sendPluginResult(err);
    }

    //----------------------------------------------------------------------------
	private boolean isVOPluginInstalled() {
		return getVOPlugin() != null;
	}

	private CordovaPlugin getVOPlugin() {
		String pluginName = "videoOverlay";
		CordovaPlugin voPlugin = webView.getPluginManager().getPlugin(pluginName);
		return voPlugin;
	}

    private int getActiveVOCameraId() {
        //reflectively access VideoOverlay plugin to get camera in same direction as lightLoc

        int camId = -1;

        CordovaPlugin voPlugin = getVOPlugin();
        if (voPlugin == null) {
            return camId;
        }

        Method method = null;

        try {
            method = voPlugin.getClass().getMethod("getActiveCameraId");
        } catch (SecurityException e) {
            //e.printStackTrace();
        } catch (NoSuchMethodException e) {
            //e.printStackTrace();
        }

        try {
            if (method == null) return camId;

            camId = (Integer)method.invoke(voPlugin);

        } catch (IllegalArgumentException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        } catch (IllegalAccessException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        } catch (InvocationTargetException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        }

        return camId;
    }

	private Camera getActiveVOCamera() {
		//reflectively access VideoOverlay plugin to get camera in same direction as lightLoc

		Camera camera = null;

		CordovaPlugin voPlugin = getVOPlugin();
		if (voPlugin == null) {
			return camera;
		}

		Method method = null;

		try {
			method = voPlugin.getClass().getMethod("getActiveCamera");
		} catch (SecurityException e) {
			//e.printStackTrace();
		} catch (NoSuchMethodException e) {
			//e.printStackTrace();
		}

		try {
			if (method == null) return camera;

			camera = (Camera)method.invoke(voPlugin);

		} catch (IllegalArgumentException e) { // exception handling omitted for brevity
			//e.printStackTrace();
		} catch (IllegalAccessException e) { // exception handling omitted for brevity
			//e.printStackTrace();
		} catch (InvocationTargetException e) { // exception handling omitted for brevity
			//e.printStackTrace();
		}

		return camera;
	}

    private int getActiveCameraDirection() {
        //reflectively access VideoOverlay plugin to get display orientation angle

        int result = -1;

        CordovaPlugin voPlugin = getVOPlugin();
        if (voPlugin == null) {
            return result;
        }

        Method method = null;

        try {
            method = voPlugin.getClass().getMethod("getActiveCameraDirection");
        } catch (SecurityException e) {
            //e.printStackTrace();
        } catch (NoSuchMethodException e) {
            //e.printStackTrace();
        }

        try {
            if (method == null) return result;

            result = (Integer)method.invoke(voPlugin);

        } catch (IllegalArgumentException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        } catch (IllegalAccessException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        } catch (InvocationTargetException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        }

        return result;
    }

    private int getDisplayOrientation() {
        //reflectively access VideoOverlay plugin to get display orientation angle

        int result = -1;

        CordovaPlugin voPlugin = getVOPlugin();
        if (voPlugin == null) {
            return result;
        }

        Method method = null;

        try {
            method = voPlugin.getClass().getMethod("getDisplayOrientation");
        } catch (SecurityException e) {
            //e.printStackTrace();
        } catch (NoSuchMethodException e) {
            //e.printStackTrace();
        }

        try {
            if (method == null) return result;

            result = (Integer)method.invoke(voPlugin);

        } catch (IllegalArgumentException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        } catch (IllegalAccessException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        } catch (InvocationTargetException e) { // exception handling omitted for brevity
            //e.printStackTrace();
        }

        return result;
    }

    public void videoOverlayStarted(int voCameraDir, int voCameraId, Camera voCamera) {
       startFaceDetection(callbackContext);
    }

    public void videoOverlayStopped(int voCameraDir, int voCameraId, Camera voCamera) {
        stopFaceDetection(null);
    }

}
