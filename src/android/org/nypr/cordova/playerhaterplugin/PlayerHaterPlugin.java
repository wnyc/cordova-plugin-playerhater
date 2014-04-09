package org.nypr.cordova.playerhaterplugin;

import java.io.File;
import java.io.IOException;

import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.nypr.cordova.playerhaterplugin.BasicAudioPlayer.STATE;

import android.content.Context;
import android.net.ConnectivityManager;
import android.os.Environment;
import android.os.RemoteException;
import android.util.Log;


public class PlayerHaterPlugin extends CordovaPlugin implements OnAudioInterruptListener, OnAudioStateUpdatedListener{

	protected static final String LOG_TAG = "PlayerHaterPlugin";
		
	protected PhoneHandler mPhoneHandler=null;
	protected BasicAudioPlayer mAudioPlayer=null;
	
	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);
		
		if(mPhoneHandler==null){
			mPhoneHandler=new PhoneHandler(this);
			mPhoneHandler.startListening(cordova.getActivity().getApplicationContext());
		}
				
		if(mAudioPlayer==null){
			mAudioPlayer=new BasicAudioPlayer(cordova.getActivity().getApplicationContext(), this);
		}

		Log.d(LOG_TAG, "PlayerHater Plugin initialized");
	}
	
	@Override
	public void onDestroy() {
		Log.d(LOG_TAG, "PlayerHater Plugin ending session");
		super.onDestroy();
	}

	@Override
	public void onReset() {
		Log.d(LOG_TAG, "PlayerHater Plugin onReset--WebView has navigated to new page or refreshed.");
		super.onReset();
	}
	
	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		boolean ret=true;
		try {
			if(action.equalsIgnoreCase("init")){
				
				_checkForExistingAudio();
				callbackContext.success();
        	
			}else if (action.equals("playstream")) {
        		
        		JSONObject stationUrls = args.getJSONObject(0);
        		JSONObject info = args.getJSONObject(1);
        		JSONObject audioJson=null;
        		if ( args.length() > 2 ) { audioJson = args.getJSONObject(2); }
        		ret = _playStream(stationUrls, info, audioJson);
        		callbackContext.success();
        	
			}else if (action.equals("playremotefile")) {
        		
        		String file=args.getString(0);
        		JSONObject info = args.getJSONObject(1);
        		JSONObject audioJson=null;
        		int position = 0;
        		if ( args.length() > 2 ) { position = args.getInt(2); }
        		if ( args.length() > 3 ) { audioJson = args.getJSONObject(3); }
				ret = _playRemoteFile(file, info, position, audioJson);
				callbackContext.success();
        	
        	}else if (action.equals("playfile")) {
        		
        		String file=new File(args.getString(0)).getName();
        		JSONObject info = args.getJSONObject(1);       		 
        		JSONObject audioJson=null;
        		int position = 0;
        		if ( args.length() > 2 ) { position = args.getInt(2); }
        		if ( args.length() > 3 ) { audioJson = args.getJSONObject(3); }
        		String directory=_getDirectory(cordova.getActivity().getApplicationContext());
        		File f = new File(directory + "/" + file);
    			if(f.exists()){
    				ret = _playAudioLocal(directory + "/" + file, info, position, audioJson);
    			} else {
    				ret = _playRemoteFile(args.getString(0), info, position, audioJson);
    			}
    			callbackContext.success();
			
        	}else if (action.equals("pause")) {
        		
				_pauseAudio();
				callbackContext.success();
				
        	}else if (action.equals("seek")) {
        		
        		int interval=args.getInt(0);
        		_seekAudio(interval);
        		callbackContext.success();
        		
        	}else if (action.equals("seekto")) {
        		
        		int pos=args.getInt(0);
        		_seekToAudio(pos);
        		callbackContext.success();
        		
			}else if (action.equals("stop")) {
				
				_pauseAudio();
				callbackContext.success();
			
        	}else if (action.equals("setaudioinfo")) {
        		
        		JSONObject info = args.getJSONObject(0);
				_setAudioInfo(info);
				callbackContext.success();
			
			}else if (action.equals("getaudiostate")) {
				
				mAudioPlayer.fireAudioStateUpdated();
				callbackContext.success();
				
			}else{
				callbackContext.error(LOG_TAG + " error: invalid action (" + action + ")");
				ret=false;
			}
		} catch (JSONException e) {
			callbackContext.error(LOG_TAG + " error: invalid json");
			ret = false;
		} catch (Exception e) {
			callbackContext.error(LOG_TAG + " error: " + e.getMessage());
			ret = false;
		}
		return ret;
	}

	protected void _checkForExistingAudio() throws JSONException{
		String audioJson = mAudioPlayer.checkForExistingAudio();
		if (audioJson!=null){
			this.webView.sendJavascript("NYPRNativeFeatures.prototype.CurrentAudio(" + audioJson + ");");	
		}
	}
	
    protected boolean _playStream(JSONObject stationUrls, JSONObject info, JSONObject audioJson)throws RemoteException, IOException, JSONException{
		
    	String url = stationUrls.getString("android");
    	
		String title = null;
		String artist = null;
		String imageUrl = null;
		boolean ret = false;
		
		if (this._isConnected()) {
			
			if(info.has("name")){ title = info.getString("name");}
			if(info.has("description")){ artist = info.getString("description");}
			if(info.has("imageThumbnail")){ 
				JSONObject thumbnailImage = info.getJSONObject("imageThumbnail");
				if(thumbnailImage.has("url")){
					imageUrl = thumbnailImage.getString("url");
				}
			}
	    	
	    	_playAudio(url, title, artist, imageUrl, -1, audioJson, true);
	    	ret=true;
		} else {
			Log.d(LOG_TAG, "play stream failed: no connection");
		}
		
		return ret;
    }
        
    protected boolean _playAudioLocal(String file, JSONObject info, int position, JSONObject audioJson)throws RemoteException, IOException, JSONException{    	
    	
    	File f= new File(file);
    	if (f.exists()) {
    		// Set to Readable and MODE_WORLD_READABLE
    		f.setReadable(true, false);
    		Log.d(LOG_TAG, "is file readabel? " + f.canRead());
    	}
    	
		String title = null;
		String artist = null;
		String imageUrl = null;
		
		if(info.has("title")){ title = info.getString("title");}
		if(info.has("artist")){ artist = info.getString("artist");}
		if(info.has("imageThumbnail")){ 
			JSONObject thumbnailImage = info.getJSONObject("imageThumbnail");
			if(thumbnailImage.has("url")){
				imageUrl = thumbnailImage.getString("url");
			}
		}
    	
		file = "file://" + file;
		_playAudio(file, title, artist, imageUrl, position, audioJson, false);
		
		return true;
    }
    
    protected boolean _playRemoteFile(String file, JSONObject info, int position, JSONObject audioJson)throws RemoteException, IOException, JSONException{    	
		String title = null;
		String artist = null;
		String imageUrl = null;
		boolean ret = false;
		
		if (this._isConnected()) {
		
			if(info.has("title")){ title = info.getString("title");}
			if(info.has("artist")){ artist = info.getString("artist");}
			if(info.has("imageThumbnail")){ 
				JSONObject thumbnailImage = info.getJSONObject("imageThumbnail");
				if(thumbnailImage.has("url")){
					imageUrl = thumbnailImage.getString("url");
				}
			}
					
	    	_playAudio(file, title, artist, imageUrl, position, audioJson, false);
	    	ret=true;
		} else {
			Log.d(LOG_TAG, "play remote file failed: no connection");
		}
		
		return ret;
    }
    
    public void _playAudio(String file, String title, String artist, String url, int position, JSONObject audioJson, boolean isStream) throws RemoteException, IOException, JSONException{
    	Log.d(LOG_TAG, "Playing audio -- " + file);
    	    	
    	mAudioPlayer.startPlaying(file, title, artist, url, position, audioJson, isStream);
    	//this.setAudioInfo(info);
    	
    }
    
    protected void _pauseAudio() throws RemoteException{
    	mAudioPlayer.pausePlaying();
    }
    
    protected void _seekAudio(int interval) throws RemoteException {
    	mAudioPlayer.seekAudio(interval);
    }
    
    protected void _seekToAudio(int pos) throws RemoteException {
    	mAudioPlayer.seekToAudio(pos);
    }
    /*
    protected void _stopAudioInternal() throws RemoteException{
		_stopAudio();
    }
    */
    protected void _stopAudio()throws RemoteException{
    	Log.d(LOG_TAG, "Stopping audio");
    	mAudioPlayer.stopPlaying();
    }
    
    protected void _setAudioInfo(JSONObject info)throws JSONException{
		String title = null;
		String artist = null;
		String url = null;
		
		if(info.has("title")){ title = info.getString("title");}
		if(info.has("artist")){ artist = info.getString("artist");}
		if(info.has("imageThumbnail")){ 
			JSONObject thumbnailImage = info.getJSONObject("imageThumbnail");
			if(thumbnailImage.has("url")){
				url = thumbnailImage.getString("url");
			}
		}
		
		mAudioPlayer.setAudioInfo(title, artist, url);
    }
	
	@Override
	public void onAudioInterruptDetected(INTERRUPT_TYPE type, boolean trackInterrupt) {
		Log.d(LOG_TAG,"Audio Interrupt Detected - Stop audio if necessary.");
		mAudioPlayer.interruptAudio(type,trackInterrupt);
	}

	@Override
	public void onAudioInterruptCompleted(INTERRUPT_TYPE type, boolean restart) {
		Log.d(LOG_TAG,"Audio Interrupt Completed - Restart audio if necessary.");
		
		try {
			mAudioPlayer.clearAudioInterrupt(type,restart);
		} catch (IOException e) {  // TODO - how to handle?	
			Log.d(LOG_TAG, "onAudioInterruptCompleted error: " + e.getMessage() );
		}
	}

	@Override
	public void onAudioStateUpdated(STATE state) {		
		Log.d(LOG_TAG,"onAudioStateUpdated " + state.ordinal() + "; " + state.toString() );
		
		if(this.webView!=null){
			this.webView.sendJavascript("NYPRNativeFeatures.prototype.AudioStatusChanged("+ state.ordinal() + ",'" + state.toString() + "')");
		}else{
			Log.d(LOG_TAG,"Web View not loaded -- cannot send Audio Status Update.");
		}
		
		if(state==STATE.MEDIA_STOPPED){
			onAudioProgressUpdated(0, 0);
		}
	}
	
	@Override
	public void onAudioProgressUpdated(int progress, int duration) {
		this.webView.sendJavascript("NYPRNativeFeatures.prototype.AudioProgress("+ progress + "," + duration + ", -1 )");
	}
	
	@Override
	public void onAudioStreamingError(int reason) {
		this.webView.sendJavascript("NYPRNativeFeatures.prototype.AudioStreamingError(" +  reason + ")");
	}
	
	public static String _getDirectory(Context context){
		// one-stop for directory, so it only needs to be changed here once
		// check if we can write to the SDCard
		
		boolean externalStorageAvailable = false;
		boolean externalStorageWriteable = false;
		String state = Environment.getExternalStorageState();

		if (Environment.MEDIA_MOUNTED.equals(state)) {
		    // We can read and write the media
		    externalStorageAvailable = externalStorageWriteable = true;			    
		    //Log.d(LOG_TAG, "External Storage Available (Readable and Writeable)");
		} else if (Environment.MEDIA_MOUNTED_READ_ONLY.equals(state)) {
		    // We can only read the media
			externalStorageAvailable = true;
			externalStorageWriteable = false;				
			Log.d(LOG_TAG, "External Storage Read Only");
		} else {
		    // Something else is wrong. It may be one of many other states, but all we need
		    //  to know is we can neither read nor write
		    externalStorageAvailable = externalStorageWriteable = false;				    
			Log.d(LOG_TAG, "External Storage Not Available");
		}
						
		// if we can write to the SDCARD
		if (externalStorageAvailable && externalStorageWriteable) { 
			return context.getExternalFilesDir(Environment.DIRECTORY_MUSIC).getAbsolutePath() + "/";
		}else{
			return null;
		}
	}
	
	protected boolean _isConnected() {
		ConnectivityManager connectivity = (ConnectivityManager) webView.getContext().getSystemService(Context.CONNECTIVITY_SERVICE);
		
		if (connectivity.getActiveNetworkInfo()==null){
			return false;
		} else if (connectivity.getActiveNetworkInfo().isConnected()) {
			return true;
		} else {
			return false;
		}
	}

}
